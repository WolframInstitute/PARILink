#!/usr/bin/env python3
"""Prepare a differential corpus from a local, matching PARI source release."""

import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


HERE = Path(__file__).resolve().parent


def commands(text):
    """Join GP physical lines, preserving strings and removing comments."""
    buf = []
    depth = 0
    string = block = escape = False
    start = 1
    for number, line in enumerate(text.splitlines(), 1):
        if not buf:
            start = number
        i = 0
        while i < len(line):
            char, pair = line[i], line[i:i + 2]
            if block:
                if pair == "*/":
                    block = False
                    i += 2
                else:
                    i += 1
                continue
            if string:
                buf.append(char)
                if escape:
                    escape = False
                elif char == "\\":
                    escape = True
                elif char == '"':
                    string = False
                i += 1
                continue
            if pair == "\\\\":
                break
            if pair == "/*":
                block = True
                i += 2
                continue
            if char == '"':
                string = True
            elif char == "{":
                depth += 1
            elif char == "}":
                depth = max(0, depth - 1)
            buf.append(char)
            i += 1
        code = "".join(buf).strip()
        continued = code.endswith("\\") and not code.startswith("\\")
        if continued:
            buf.pop()
        if code and not (depth or block or continued or code.endswith("=")):
            yield start, code
            buf = []
            string = escape = False
        elif buf:
            buf.append(" ")
    if "".join(buf).strip():
        yield start, "".join(buf).strip()


def classify(name, line, code):
    if name in {"debugger", "history"}:
        return code, "GP terminal state"
    if name == "io" and line in {21, 22}:
        return code, "whole-session binary snapshot includes bridge internals"
    if code.startswith("\\"):
        match = re.fullmatch(r"\\(p|pb|ps)\s*(\d+)", code)
        if match:
            setting = {"p": "realprecision", "pb": "realbitprecision", "ps": "seriesprecision"}[match[1]]
            return f"default({setting},{match[2]})", None
        return code, "GP terminal directive"
    if code.startswith("?"):
        return code, "interactive help"
    if re.search(r"\binput\s*\(|\bread\s*\(\s*\)", code):
        return code, "interactive input"
    if re.search(r'\bdefault\s*\(\s*"?(breakloop|echo|log|logfile|recover)"?\s*,', code):
        return code, "interactive interpreter setting"
    if re.search(r'\ballocatemem\s*\(|\bdefault\s*\(\s*"?parisize"?\s*,', code):
        return code, "stack setup (tested separately by integration tests)"
    return code, None


def fingerprint(value, stream):
    if isinstance(value, list):
        if value and value[0] == "o":
            _, kind, offset, size = value
            stream.seek(offset)
            data = stream.read(size)
            if len(data) != size:
                raise ValueError("Truncated native object snapshot")
            return ["o", kind, hashlib.sha256(data).hexdigest()]
        return [fingerprint(item, stream) for item in value]
    return value


def native(name, cases, args):
    directory = args.output / "native" / name
    directory.mkdir(parents=True, exist_ok=True)
    objects = directory / "audit-objects.txt"
    objects.write_bytes(b"")
    script = (HERE / "snapshot.gp").read_text() + "\n"
    for case in cases:
        line = case["line"]
        argument = "strchr(" + json.dumps(list(case["code"].encode())) + ")"
        script += (
            f'print("AUDITBEGIN:{line}");'
            f'auditfile=fileopen("audit-request.gp","w");'
            f'filewrite(auditfile,{argument});fileclose(auditfile);'
            f'iferr(auditvalue=read("audit-request.gp");'
            f'print1("AUDITEND:{line}:[\\\"ok\\\",");auditsnapshot(auditvalue);print("]"),'
            f'auditerror,print("\\nAUDITEND:{line}:[\\\"error\\\",\\\"",errname(auditerror),"\\\"]"));\n'
        )
    (directory / "input.gp").write_text(script)
    command = [str(args.gp), "-f", "-q", "--default", "colors=no", "--default", "breakloop=0",
               "--default", "parisize=268435456", "--default", "parisizemax=268435456",
               "--default", "threadsizemax=268435456"]
    if name in {"parallel", "parallel-alarm"}:
        command += ["--default", "nbthreads=2"]
    if args.data:
        command += ["--default", "datadir=" + str(args.data)]
    timed_out = False
    try:
        result = subprocess.run(command, input=script.encode(), cwd=directory,
                                capture_output=True, timeout=args.suite_timeout,
                                env={**os.environ, "GP_SVG_VIEWER": args.viewer,
                                     "GP_POSTSCRIPT_VIEWER": args.viewer, "GPTMPDIR": str(directory)})
        output, error = result.stdout, result.stderr
    except subprocess.TimeoutExpired as error_result:
        output, error = error_result.stdout or b"", error_result.stderr or b""
        timed_out = True
    (directory / "stdout.txt").write_bytes(output)
    (directory / "stderr.txt").write_bytes(error)
    output = output.decode("utf-8", errors="replace")
    expected = {}
    with objects.open("rb") as stream:
        for match in re.finditer(r"AUDITEND:(\d+):([^\n]*)", output):
            # Vecsmall prints compact bytes without allocating a boxed GP vector.
            payload = re.sub(r"Vecsmall\((\[[0-9, ]*\])\)", r"\1", match[2])
            try:
                expected[int(match[1])] = fingerprint(json.loads(payload), stream)
            except json.JSONDecodeError:
                continue  # A nonlocal GP error can interrupt a snapshot.
    stdout = {int(m[1]): m[2] for m in re.finditer(r"AUDITBEGIN:(\d+)\n(.*?)AUDITEND:\1:", output, re.S)}
    for line, value in expected.items():
        if value[0] == "error" and stdout.get(line, "").endswith("\n"):
            stdout[line] = stdout[line][:-1]  # The error frame's separator.
    result = {
        "file": name,
        "source": "parallel" if name == "parallel-alarm" else name,
        "cases": [{**c, "expected": expected[c["line"]], "stdout": stdout.get(c["line"], "")}
                  for c in cases if c["line"] in expected],
        "missing": [c for c in cases if c["line"] not in expected],
        "timeout": timed_out,
    }
    target = args.output / "cases" / (name + ".json")
    target.write_text(json.dumps(result))
    print(f'{name}: {len(result["cases"])} references, {len(result["missing"])} missing', flush=True)
    return {"file": name, "path": str(target)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("gp", help="Executable built from this source version")
    parser.add_argument("--data", type=Path, help="Optional PARI datasets directory")
    parser.add_argument("--output", type=Path, default=Path("build/upstream"))
    parser.add_argument("--files", help="Comma-separated suite names for a focused run")
    parser.add_argument("--timeout", type=int, default=120, help="Seconds per linked request")
    parser.add_argument("--suite-timeout", type=int, default=600, help="Seconds per complete native suite")
    args = parser.parse_args()
    if args.timeout <= 0 or args.suite_timeout <= 0:
        parser.error("Timeouts must be positive")
    args.source = args.source.resolve(strict=True)
    args.gp = Path(shutil.which(args.gp) or args.gp).resolve(strict=True)
    args.output = args.output.resolve()
    args.viewer = shutil.which("true")
    if not args.viewer:
        parser.error("The upstream sweep requires a Unix-like system with true on PATH")
    if args.data:
        args.data = args.data.resolve(strict=True)
    (args.output / "cases").mkdir(parents=True, exist_ok=True)
    functions = {}
    for path in sorted((args.source / "src/functions").rglob("*")):
        if not path.is_file():
            continue
        text = path.read_text(errors="replace")
        match = re.search(r"^Function: ([A-Za-z][A-Za-z0-9_]*)$", text, re.M)
        if match and "Class: gp2c" not in text:
            functions[match[1]] = {"section": path.parent.name, "source": str(path.relative_to(args.source))}
    if not functions:
        parser.error("Source must contain src/functions and src/test/in")
    tasks, skipped = [], []
    paths = sorted((args.source / "src/test/in").iterdir()) + [HERE / "extra.gp"]
    selected = None if args.files is None else {name.strip() for name in args.files.split(",")}
    suite_names = {"parilink-extra" if path == HERE / "extra.gp" else path.name for path in paths}
    if selected is not None and selected - suite_names:
        parser.error("Unknown suites: " + ", ".join(repr(name) for name in sorted(selected - suite_names)))
    for path in paths:
        name = "parilink-extra" if path == HERE / "extra.gp" else path.name
        if selected is not None and name not in selected:
            continue
        cases = []
        for line, raw in commands(path.read_text(errors="replace")):
            code, reason = classify(name, line, raw)
            references = sorted(set(re.findall(r"\b[A-Za-z][A-Za-z0-9_]*\b", code)) & functions.keys())
            case = {"line": line, "code": code, "functions": references}
            if reason:
                skipped.append({"file": name, **case, "reason": reason})
            elif name == "parallel" and "until(type(A)==\"t_ERROR\",A=alarm(" in code:
                # GP 2.19 can hang here after the preceding parallel operations.
                # Exercise the unchanged, self-contained stress test in a fresh GP.
                tasks.append(("parallel-alarm", [case]))
            else:
                cases.append(case)
        tasks.append((name, cases))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        files = list(pool.map(lambda task: native(*task, args), tasks))
    manifest = {"source": args.source.name, "gp": str(args.gp), "data": str(args.data) if args.data else None,
                "output": str(args.output), "timeout": args.timeout, "suiteTimeout": args.suite_timeout,
                "viewer": args.viewer, "functions": functions,
                "files": files, "skipped": skipped}
    (args.output / "manifest.json").write_text(json.dumps(manifest))


if __name__ == "__main__":
    main()
