#!/usr/bin/env wolframscript

(* One entry point for local checks and PacletPage's build/publish workflow. *)
root = ParentDirectory[DirectoryName[$InputFileName]];
pacletDirectory = FileNameJoin[{root, "PARILink"}];
docsDirectory = FileNameJoin[{root, "docs", "en"}];
command = If[Length[$ScriptCommandLine] > 1, $ScriptCommandLine[[2]], "all"];

require[value_, message_String] := If[! TrueQ[value], Print["FAIL: ", message]; Throw[1, "exit"]];

loadSource[] := (
	PacletDirectoryLoad[pacletDirectory];
	Needs["WolframInstitute`PARILink`"];
)

check[] := Module[{sources, paclet},
	sources = Join[FileNames["*.wl", pacletDirectory, Infinity], FileNames["*.wlt", pacletDirectory, Infinity]];
	Scan[require[SyntaxQ[Import[#, "Text"]], "Invalid Wolfram Language syntax: " <> #] &, sources];
	paclet = PacletObject[File[pacletDirectory]];
	require[paclet["Name"] === "WolframInstitute/PARILink", "Unexpected paclet name"];
	loadSource[];
	require[Length[Names["WolframInstitute`PARILink`*"]] === 5, "Unexpected public API"];
	Print["PASS: metadata, syntax, and source load"];
]

runTests[integration_] := Module[{files, report, failures},
	loadSource[];
	files = FileNames["*.wlt", If[TrueQ[integration], FileNameJoin[{pacletDirectory, "Tests", "Integration"}], FileNameJoin[{pacletDirectory, "Tests"}]]];
	If[! TrueQ[integration], files = Join[files, FileNames["*.wlt", FileNameJoin[{root, "tests"}]]]];
	require[files =!= {}, "No tests found"];
	report = TestReport[files, ProgressReporting -> False];
	failures = Select[Values[report["TestResults"]], #["Outcome"] =!= "Success" &];
	Scan[Print[#["TestID"], ": ", InputForm[#["ActualOutput"]], "; expected ", InputForm[#["ExpectedOutput"]],
		"; messages ", InputForm[#["ActualMessages"]]] &, failures];
	Print[report["TestsSucceededCount"], "/", Length[report["TestResults"]], " tests passed"];
	require[failures === {} && Length[report["TestResults"]] > 0, "Tests failed"];
]

loadPublishing[] := Module[{page, parser, converter},
	page = FileNameJoin[{root, ".deps", "PacletPage"}];
	parser = FileNameJoin[{root, ".deps", "WolframParser", "Parser"}];
	converter = FileNameJoin[{root, ".deps", "MarkdownToNotebook", "MarkdownToNotebook.wl"}];
	require[And @@ (FileExistsQ /@ {FileNameJoin[{page, "PacletInfo.wl"}], FileNameJoin[{parser, "PacletInfo.wl"}], converter}),
		"Run make deps to fetch the pinned documentation tools"];
	PacletDirectoryLoad[page];
	PacletDirectoryLoad[parser];
	Needs["Wolfram`Parser`"];
	Needs["WolframInstitute`PacletPage`"];
	{
		"Source" -> docsDirectory, "Definition" -> FileNameJoin[{root, "docs", "ResourceDefinition.md"}],
		"Converter" -> converter, "Dependencies" -> {parser}, "Parallel" -> False, "TimeConstraint" -> 180
	}
]

(* As in Ruliology, child kernels use the launcher that understands CI entitlements.
   These overrides last only for the PacletPage call and never change GP processes. *)
SetAttributes[withEntitledKernels, HoldFirst];
withEntitledKernels[body_] := Internal`InheritedBlock[{RunProcess, StartProcess},
	Unprotect[RunProcess, StartProcess];
	DownValues[RunProcess] = Prepend[DownValues[RunProcess],
		HoldPattern[RunProcess[{kernel_String, "-noprompt", "-script", file_String}, arguments___] /;
			FileBaseName[kernel] === "WolframKernel"] :>
			RunProcess[{"wolframscript", "-file", file}, arguments,
				ProcessEnvironment -> Append[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH" -> kernel]]];
	DownValues[StartProcess] = Prepend[DownValues[StartProcess],
		HoldPattern[StartProcess[{kernel_String, "-noprompt", "-script", file_String}, options___] /;
			FileBaseName[kernel] === "WolframKernel"] :>
			StartProcess[{"wolframscript", "-file", file}, options,
				ProcessEnvironment -> Append[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH" -> kernel]]];
	Protect[RunProcess, StartProcess];
	body
];

pageCall[name_String, arguments___] := If[
	StringQ[Environment["WOLFRAMSCRIPT_ENTITLEMENTID"]] && Environment["WOLFRAMSCRIPT_ENTITLEMENTID"] =!= "",
	withEntitledKernels[Symbol["WolframInstitute`PacletPage`" <> name][arguments]],
	Symbol["WolframInstitute`PacletPage`" <> name][arguments]
];

checkArchive[result_] := (
	require[AssociationQ[result], "PacletPage build failed"];
	require[TrueQ[result["Resource"]["Load"]["OK"]], "The archive failed its fresh-kernel load check"];
	require[result["Resource"]["Documentation"]["Missing"] === {} &&
		result["Resource"]["Documentation"]["Flagged"] === <||>, "The archive is missing documentation pages"];
	Print["PASS: ", result["Resource"]["Pages"], " documentation pages; archive loads cleanly"];
	Print[result["Resource"]["Archive"]];
)

build[] := Module[{options = loadPublishing[], result},
	result = Block[{$CloudConnected = False},
		pageCall["PublishPacletPage", pacletDirectory, "PARILink", "DryRun" -> True,
			"BuildOptions" -> options, "ResourceOptions" -> {"Parallel" -> False}, "Monitor" -> True]
	];
	require[AssociationQ[result], "PacletPage build failed"];
	require[Lookup[result["Build"], "Failed", None] === {} && Lookup[result["Build"], "Unevaluated", None] === <||>,
		"Documentation pages failed to build or evaluate"];
	checkArchive[result];
]

releaseTag[environment_Association, version_String] := Module[{tag = Lookup[environment, "GITHUB_REF_NAME", ""]},
	require[Lookup[environment, {"GITHUB_ACTIONS", "GITHUB_EVENT_NAME", "GITHUB_REF_TYPE"}] === {"true", "push", "tag"},
		"Publishing requires a release-tag push in GitHub Actions"];
	require[StringMatchQ[tag, RegularExpression["v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)"]] &&
		tag === "v" <> version && Lookup[environment, "GITHUB_REF"] === "refs/tags/" <> tag,
		"The release tag must be vX.Y.Z matching PacletInfo.wl"];
	tag
]

git[arguments__String] := RunProcess[{"git", "-C", root, arguments}];
gitText[arguments__String] := Module[{result = git[arguments]},
	require[AssociationQ[result] && result["ExitCode"] === 0, "Git could not verify the release checkout"];
	StringTrim[result["StandardOutput"]]
]

checkRelease[environment_Association : Association[GetEnvironment[]]] := Module[{tag, commit},
	tag = releaseTag[environment, PacletObject[File[pacletDirectory]]["Version"]];
	commit = gitText["rev-parse", "HEAD"];
	require[gitText["rev-parse", "refs/tags/" <> tag <> "^{commit}"] === commit, "The tag does not point to HEAD"];
	require[StringQ[Lookup[environment, "GITHUB_SHA"]], "The workflow commit is missing"];
	require[gitText["rev-parse", environment["GITHUB_SHA"] <> "^{commit}"] === commit, "The checkout differs from the workflow commit"];
	require[git["merge-base", "--is-ancestor", "HEAD", "origin/main"]["ExitCode"] === 0, "The release commit is not on main"];
	require[gitText["status", "--porcelain"] === "", "The release checkout has uncommitted changes"];
	Print["PASS: release tag ", tag];
]

publish[] := Module[{account, password, prepared, result},
	checkRelease[];
	account = Environment["WOLFRAM_CLOUD_USER"];
	password = Environment["WOLFRAM_CLOUD_PASSWORD"];
	require[AllTrue[{account, password}, StringQ[#] && StringTrim[#] =!= "" &],
		"Set WOLFRAM_CLOUD_USER and WOLFRAM_CLOUD_PASSWORD as release secrets"];
	loadPublishing[];
	(* PacletPage checks the archive hash and the sources before any cloud connection. *)
	prepared = Block[{$CloudConnected = False},
		pageCall["PublishPacletPage", pacletDirectory, "PARILink", "DryRun" -> True, "Build" -> False,
			"ResourceOptions" -> {"Build" -> False, "Parallel" -> False}]
	];
	checkArchive[prepared];
	require[Quiet[Check[CloudConnect[account, password], $Failed]] =!= $Failed && TrueQ[$CloudConnected],
		"Could not connect to the publishing account"];
	result = pageCall["PublishPacletPage", pacletDirectory, "PARILink", "Account" -> account, "Build" -> False,
		"ResourceOptions" -> {"Build" -> False, "Parallel" -> False}, "Monitor" -> True];
	require[AssociationQ[result] && TrueQ[result["Resource"]["Deployed"]], "PacletPage publication failed"];
	require[TrueQ[result["Check"]["OK"]], "The published documentation site did not pass its checks"];
	Print["PASS: published ", result["Resource"]["Resource"]];
	Print[result["Site"]["Site"]];
]

Exit @ Catch[
	Switch[command,
		"all", check[]; runTests[False],
		"check", check[],
		"test", runTests[False],
		"test-pari", runTests[True],
		"docs", With[{options = loadPublishing[]},
			result = pageCall["BuildPacletDocumentation", pacletDirectory, Sequence @@ options];
			require[AssociationQ[result] && Lookup[result, "Failed", None] === {}, "Documentation build failed"];
			Print[result]
		],
		"build", build[],
		"check-release", checkRelease[],
		"publish", publish[],
		_, require[False, "Unknown command: " <> command]
	];
	0,
	"exit"
]
