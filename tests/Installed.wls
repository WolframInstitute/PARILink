(* Run in an empty paclet base; CI uses a disposable runner. *)
require[value_, message_] := If[! TrueQ[value], Print["FAIL: ", message]; Throw[1, "exit"]];
integrationTests = FileNames["*.wlt", FileNameJoin[{
	ParentDirectory[DirectoryName[$InputFileName]], "PARILink", "Tests", "Integration"
}]];

Exit @ Catch[
	archives = DeleteDuplicates @ Select[Join[$ScriptCommandLine, $CommandLine],
		StringQ[#] && StringEndsQ[#, ".paclet"] &];
	require[Length[archives] === 1, "Pass the paclet archive path"];
	require[PacletFind["WolframInstitute/PARILink"] === {},
		"Use a fresh kernel with -pacletbase pointing to an empty directory"];
	archive = ExpandFileName[First[archives]];
	installed = PacletInstall[archive];
	require[MatchQ[installed, _PacletObject], "PacletInstall failed"];
	WithCleanup[Null,
		Needs["WolframInstitute`PARILink`"];
		SetEnvironment[{"PARILINK_GP" -> "", "PATH" -> ""}];
		program = FileNameJoin[{installed["Location"], "Resources", "Runtime", $SystemID,
			If[$OperatingSystem === "Windows", "gp.exe", "gp"]}];
		require[FileExistsQ[program], "The installed paclet has no GP for this platform"];
		If[$OperatingSystem =!= "Windows",
			require[RunProcess[{"/bin/chmod", "644", program}, "ExitCode"] === 0, "Could not test permission repair"]
		];
		session = WolframInstitute`PARILink`StartPARISession[];
		require[! FailureQ[session], session];
		WithCleanup[Null,
			require[session["Executable"] === program, "GP did not come from the installed archive"];
			require[WolframInstitute`PARILink`PARIEvaluate[session, "default(datadir)"] ===
				StringReplace[FileNameJoin[{installed["Location"], "Resources", "Runtime", "data"}], "\\" -> "/"],
				"GP is not using the installed data"];
			require[WolframInstitute`PARILink`PARIEvaluate[session,
				"[bnfinit(x^2+23).no,polgalois(x^8-2)[1],galoisgetpol(8),#ellmodulareqn(11),#nflist(\"A5\")]"
			] === {3, 16, 5, 2, 10}, "Bundled number-theory data failed"];
			require[First[WolframInstitute`PARILink`PARICall[session, "ellsearch", "11a1"]] === "11a1",
				"The elliptic-curve database is unavailable"],
			DeleteObject[session]
		];
		report = TestReport[integrationTests, ProgressReporting -> False];
		Print[report["TestsSucceededCount"], "/", Length[report["TestResults"]], " installed integration tests passed"];
		require[report["TestsFailedCount"] === 0 && report["TestsSucceededCount"] > 0, report];
		Print["PASS: PacletInstall, bundled GP, data, permission repair, and integration tests"],
		PacletUninstall[installed]
	];
	0,
	"exit"
]
