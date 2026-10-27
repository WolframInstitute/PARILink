#!/usr/bin/env python3
"""Prepare, verify and stage GP runtimes; PacletPage still builds the paclet."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import subprocess
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / "scripts/runtime.json").read_text())
SOURCES = ROOT / "build/runtime-sources"
RUNTIMES = ROOT / "build/runtimes"
DESTINATION = ROOT / "PARILink/Resources/Runtime"


def sha256(path):
    with Path(path).open("rb") as stream:
        digest = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch_one(url, checksum):
    SOURCES.mkdir(parents=True, exist_ok=True)
    destination = SOURCES / url.rsplit("/", 1)[-1]
    if not destination.exists():
        temporary = destination.with_suffix(destination.suffix + ".part")
        subprocess.run(["curl", "--fail", "--silent", "--show-error", "--location",
                        "--retry", "3", url, "-o", str(temporary)], check=True)
        if sha256(temporary) != checksum:
            temporary.unlink()
            raise ValueError(f"Checksum mismatch: {url}")
        temporary.replace(destination)
    if sha256(destination) != checksum:
        raise ValueError(f"Checksum mismatch: {destination}")
    return destination


def fetch(data=False):
    entries = [(CONFIG[key]["url"], CONFIG[key]["sha256"]) for key in ("pari", "gmp")]
    if data:
        entries += [(f"https://pari.math.u-bordeaux.fr/pub/pari/packages/{name}.tgz", digest)
                    for name, digest in CONFIG["data"].items()]
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda pair: fetch_one(*pair), entries))


def member_path(name):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name or ":" in name:
        raise ValueError(f"Unsafe archive member: {name}")
    return path


def extract_tar(archive, destination):
    with tarfile.open(archive) as bundle:
        for entry in bundle:
            path = destination / member_path(entry.name)
            if entry.isdir():
                path.mkdir(parents=True, exist_ok=True)
            elif entry.isfile():
                path.parent.mkdir(parents=True, exist_ok=True)
                with bundle.extractfile(entry) as source, path.open("wb") as target:
                    shutil.copyfileobj(source, target)
                path.chmod(entry.mode & 0o777)
            else:
                raise ValueError(f"Unexpected archive link or special file: {entry.name}")


def host_system():
    system, machine = platform.system(), platform.machine().lower()
    arch = "ARM64" if machine in ("arm64", "aarch64") else "x86-64"
    if machine not in ("arm64", "aarch64", "x86_64", "amd64"):
        raise ValueError(f"Unsupported processor: {machine}")
    name = {"Darwin": "MacOSX", "Linux": "Linux", "Windows": "Windows"}.get(system)
    if system.startswith(("MINGW", "MSYS")):
        name = "Windows"
    result = f"{name}-{arch}"
    if result not in CONFIG["systems"]:
        raise ValueError(f"Unsupported system: {result}")
    return result


def executable(directory, system):
    return directory / ("gp.exe" if system.startswith("Windows") else "gp")


def check_dependencies(program, system):
    """Only operating-system libraries may be needed outside the paclet."""
    if system.startswith("MacOSX"):
        output = subprocess.check_output(["otool", "-L", str(program)], text=True)
        dependencies = [line.strip().split(" (")[0] for line in output.splitlines()[1:]]
        allowed = lambda value: value.startswith(("/usr/lib/", "/System/Library/"))
    elif system.startswith("Linux"):
        output = subprocess.check_output(["readelf", "-d", str(program)], text=True)
        dependencies = re.findall(r"\(NEEDED\).*\[(.*?)\]", output)
        allowed = lambda value: value in {
            "libc.so.6", "libm.so.6", "libpthread.so.0", "libdl.so.2", "librt.so.1",
            "ld-linux-aarch64.so.1", "ld-linux-x86-64.so.2"
        }
        if re.search(r"\((?:RUNPATH|RPATH)\)", output):
            raise ValueError("GP contains a runtime search path")
    else:
        output = subprocess.check_output(["objdump", "-p", str(program)], text=True)
        dependencies = re.findall(r"DLL Name:\s*(\S+)", output)
        allowed = lambda value: value.lower() in {
            "kernel32.dll", "msvcrt.dll", "ucrtbase.dll", "advapi32.dll", "shell32.dll",
            "user32.dll", "gdi32.dll", "comdlg32.dll", "ws2_32.dll", "ole32.dll"
        } or value.lower().startswith("api-ms-win-")
    unexpected = [value for value in dependencies if not allowed(value)]
    if unexpected:
        raise ValueError(f"GP needs libraries outside the operating system: {unexpected}")


def smoke(program, data=None, startup=None):
    """Run with an empty PATH, a fresh home, and no GP startup configuration."""
    environment = {key: value for key, value in os.environ.items()
                   if key in ("SystemRoot", "WINDIR", "TEMP", "TMP", "COMSPEC")}
    with tempfile.TemporaryDirectory(prefix="PARILink runtime test ") as directory:
        environment.update(PATH="", HOME=directory, USERPROFILE=directory)
        arguments = [str(program.resolve()), "-f", "-q", "--default", "colors=no",
                     "--default", "breakloop=0", "--default", "parisizemax=268435456"]
        if data is not None:
            arguments += ["--default", "datadir=" + data.resolve().as_posix()]
        if startup is not None:
            arguments.append(str(startup.resolve()))
        expressions = [
            'print(version()==[2,19,0])',
            'print(factorback(factor(2^127-1))==2^127-1)',
            'print(bnfinit(x^2+23).no==3)',
            'print(polgalois(x^5-x-1)[1]==120)',
            'print(parsum(i=1,10,i)==55)',
        ]
        if data is not None:
            expressions += [
                'print(ellsearch("11a1")[1]=="11a1")',
                'print(galoisgetpol(8)>0)',
                'print(polgalois(x^8-2)[1]==16)',
                'print(#ellmodulareqn(11)>0)',
                'print(#nflist("A5")>0)',
            ]
        count = len(expressions)
        if startup is not None:
            request = Path(directory) / "request with spaces.gp"
            request.write_text('["λ",1/7,2^127]\n', encoding="utf-8")
            expressions.append('parilinkresult(read(' + json.dumps(request.as_posix())
                               + '),"Copy","PARILINK:BUNDLE:")')
        result = subprocess.run(arguments, input="\n".join(expressions) + "\nquit\n",
                                capture_output=True, text=True, timeout=120,
                                cwd=directory, env=environment)
        lines = [line for line in result.stdout.splitlines() if line.strip()]
        expected = ["ok", ["v", [["s", list("λ".encode())], ["q", "1", "7"], ["i", str(2**127)]]]]
        bridge_ok = (lines[count:] == [] if startup is None else
                     len(lines) == count + 1 and lines[-1].startswith("PARILINK:BUNDLE:")
                     and json.loads(lines[-1].removeprefix("PARILINK:BUNDLE:")) == expected)
        if (result.returncode != 0 or result.stderr.strip()
                or lines[:count] != ["1"] * count or not bridge_ok):
            raise ValueError(f"Bundled GP failed: {result.stdout}\n{result.stderr}")


def write_manifest(directory, system):
    manifest = {"system": system, "pari": CONFIG["pari"], "gmp": CONFIG["gmp"],
                "files": {path.relative_to(directory).as_posix(): sha256(path)
                          for path in sorted(directory.rglob("*"))
                          if path.is_file() and path.name != "runtime.json"}}
    (directory / "runtime.json").write_text(json.dumps(manifest, indent=2) + "\n")


def verify_manifest(directory, system):
    manifest = json.loads((directory / "runtime.json").read_text())
    if (manifest["system"] != system or manifest["pari"] != CONFIG["pari"]
            or manifest["gmp"] != CONFIG["gmp"]):
        raise ValueError(f"Wrong runtime version or platform: {directory}")
    for name, digest in manifest["files"].items():
        if sha256(directory / member_path(name)) != digest:
            raise ValueError(f"Runtime file changed: {name}")
    for name in (executable(directory, system).name, "licenses/pari/COPYING",
                 "licenses/gmp/COPYING", "licenses/gmp/COPYING.LESSERv3"):
        if name not in manifest["files"]:
            raise ValueError(f"Missing runtime file: {name}")


def pack(system):
    if system != host_system() and not (platform.system() == "Darwin" and system == "MacOSX-x86-64"):
        raise ValueError("Build and test the runtime on its own platform")
    directory = RUNTIMES / system / system
    program = executable(directory, system)
    check_dependencies(program, system)
    smoke(program)
    write_manifest(directory, system)
    verify_manifest(directory, system)
    archive = directory.parent / f"PARILink-runtime-{system}.tar.gz"
    def archive_metadata(entry):
        entry.uid = entry.gid = 0
        entry.uname = entry.gname = ""
        return entry
    with tarfile.open(archive, "w:gz") as bundle:
        bundle.add(directory, arcname=system, filter=archive_metadata)
    archive.with_suffix(archive.suffix + ".sha256").write_text(f"{sha256(archive)}  {archive.name}\n")
    print(f"PASS: {system}, GP {CONFIG['pari']['version']}, system libraries only")


def stage_data():
    fetch(data=True)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="pari-data-") as work:
        directory = Path(work)
        for name in CONFIG["data"]:
            extract_tar(SOURCES / f"{name}.tgz", directory)
        # GP otherwise shells out to gzip, which is not part of standard Windows.
        for compressed in directory.rglob("*.gz"):
            with gzip.open(compressed, "rb") as source, compressed.with_suffix("").open("wb") as target:
                shutil.copyfileobj(source, target)
            compressed.unlink()
        target = DESTINATION / "data"
        if target.exists():
            shutil.rmtree(target)
        shutil.move(str(directory / "data"), target)
    (DESTINATION / "data-sources.json").write_text(json.dumps(CONFIG["data"], indent=2) + "\n")
    # Corresponding source accompanies cloud downloads as well as GitHub releases.
    sources = DESTINATION / "Sources"
    sources.mkdir(exist_ok=True)
    for key in ("pari", "gmp"):
        name = CONFIG[key]["url"].rsplit("/", 1)[-1]
        shutil.copy2(SOURCES / name, sources / name)
    for name in ("build-runtime.sh", "runtime.py", "runtime.json"):
        shutil.copy2(ROOT / "scripts" / name, sources / name)
    shutil.copy2(ROOT / "THIRD_PARTY_NOTICES.md", DESTINATION / "THIRD_PARTY_NOTICES.md")


def stage(all_systems=False):
    systems = CONFIG["systems"] if all_systems else [host_system()]
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for system in systems:
        matches = list(RUNTIMES.rglob(f"PARILink-runtime-{system}.tar.gz"))
        if len(matches) != 1:
            raise ValueError(f"Expected one runtime archive for {system}; run make runtime")
        archive = matches[0]
        if sha256(archive) != archive.with_suffix(archive.suffix + ".sha256").read_text().split()[0]:
            raise ValueError(f"Runtime archive checksum mismatch: {archive}")
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as work:
            extract_tar(archive, Path(work))
            directory = Path(work) / system
            verify_manifest(directory, system)
            target = DESTINATION / system
            if target.exists():
                shutil.rmtree(target)
            shutil.move(str(directory), target)
    stage_data()
    check(DESTINATION, all_systems)


def check(directory, all_systems=False):
    systems = CONFIG["systems"] if all_systems else [host_system()]
    for system in systems:
        verify_manifest(directory / system, system)
    for name in CONFIG["data"]:
        if not (directory / "data" / name).is_dir():
            raise ValueError(f"Missing PARI data: {name}")
    for key in ("pari", "gmp"):
        source = directory / "Sources" / CONFIG[key]["url"].rsplit("/", 1)[-1]
        if sha256(source) != CONFIG[key]["sha256"]:
            raise ValueError(f"Missing or changed corresponding source: {source}")
    system = host_system()
    program = executable(directory / system, system)
    program.chmod(0o755)
    check_dependencies(program, system)
    smoke(program, directory / "data", directory.parent / "GP/startup.gp")
    print(f"PASS: bundled GP and all five data packages on {system}; PATH is empty")


def check_archive(archive, all_systems=False):
    with tempfile.TemporaryDirectory(prefix="PARILink installed archive ") as work:
        directory = Path(work)
        with zipfile.ZipFile(archive) as bundle:
            for entry in bundle.infolist():
                member_path(entry.filename)
            bundle.extractall(directory)
        matches = list(directory.glob("*/Resources/Runtime"))
        if len(matches) != 1:
            raise ValueError("The paclet must contain one PARILink runtime directory")
        check(matches[0], all_systems)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("fetch", "version", "pack", "stage", "check", "check-archive"))
    parser.add_argument("path", nargs="?")
    parser.add_argument("--all", action="store_true", dest="all_systems")
    parser.add_argument("--data", action="store_true")
    args = parser.parse_args()
    if args.command == "fetch":
        fetch(args.data)
    elif args.command == "version":
        print(CONFIG[args.path]["version"])
    elif args.command == "pack":
        pack(args.path)
    elif args.command == "stage":
        stage(args.all_systems)
    elif args.command == "check":
        check(Path(args.path) if args.path else DESTINATION, args.all_systems)
    elif args.command == "check-archive":
        check_archive(Path(args.path), args.all_systems)


if __name__ == "__main__":
    main()
