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

build[publish_] := Module[{options = loadPublishing[], account, result},
	account = Environment["PARILINK_PUBLISH_ACCOUNT"];
	If[TrueQ[publish], require[StringQ[account] && StringLength[StringTrim[account]] > 0, "Set PARILINK_PUBLISH_ACCOUNT before publishing"]];
	result = If[TrueQ[publish],
		WolframInstitute`PacletPage`PublishPacletPage[pacletDirectory, "PARILink", "Account" -> account,
			"BuildOptions" -> options, "ResourceOptions" -> {"Parallel" -> False}],
		Block[{$CloudConnected = False},
			WolframInstitute`PacletPage`PublishPacletPage[pacletDirectory, "PARILink", "DryRun" -> True,
				"BuildOptions" -> options, "ResourceOptions" -> {"Parallel" -> False}]
		]
	];
	require[AssociationQ[result], "PacletPage build failed"];
	require[Lookup[result["Build"], "Failed", None] === {} && Lookup[result["Build"], "Unevaluated", None] === <||>,
		"Documentation pages failed to build or evaluate"];
	require[TrueQ[result["Resource"]["Load"]["OK"]], "The archive failed its fresh-kernel load check"];
	Print["PASS: ", result["Resource"]["Pages"], " documentation pages; archive loads cleanly"];
	Print[result["Resource"]["Archive"]];
]

Exit @ Catch[
	Switch[command,
		"all", check[]; runTests[False],
		"check", check[],
		"test", runTests[False],
		"test-pari", runTests[True],
		"docs", With[{options = loadPublishing[]},
			result = WolframInstitute`PacletPage`BuildPacletDocumentation[pacletDirectory, Sequence @@ options];
			require[AssociationQ[result] && Lookup[result, "Failed", None] === {}, "Documentation build failed"];
			Print[result]
		],
		"build", build[False],
		"publish", build[True],
		_, require[False, "Unknown command: " <> command]
	];
	0,
	"exit"
]
