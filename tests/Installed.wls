(* Installs a release archive into an empty paclet base and tests the public link with the GP of that archive alone:
   PATH is empty and PARILINK_GP is not set. CI runs it in a disposable container.
   usage: wolframscript -file tests/Installed.wls <archive> *)

(* The program is read before it loads PARILink, so it names the public symbols by their full names as strings. *)
pariLinkFunction[name_String] := Symbol["WolframInstitute`PARILink`" <> name]

innerFailure[failure_Failure] := SelectFirst[{failure["Information"], failure["Expression"]}, FailureQ, failure]

$integrationTests = FileNames["*.wlt", FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "PARILink", "Tests", "Integration"}]];

(* An integration test loads the source paclet when it runs alone. Here the tests must use the installed paclet, so
   that step is skipped. *)
installedTestReport[] := Block[{PacletDirectoryLoad = Function[Null, Null]}, TestReport[$integrationTests, ProgressReporting -> False]]

failedTestIDs[report_TestReportObject] := Map[#["TestID"] &, Select[Values[report["TestResults"]], #["Outcome"] =!= "Success" &]]

checkBundledGP[installed_PacletObject, program_String] :=
	Enclose[
		Module[{session, dataDirectory, dataValues},
			session = pariLinkFunction["StartPARISession"][];
			ConfirmAssert[!FailureQ[session], "GP did not start: " <> ToString[session, InputForm]];
			dataDirectory = StringReplace[FileNameJoin[{installed["Location"], "Resources", "Runtime", "data"}], "\\" -> "/"];
			WithCleanup[
				ConfirmAssert[session["Executable"] === program, "GP did not come from the installed archive"];
				ConfirmAssert[pariLinkFunction["PARIEvaluate"][session, "default(datadir)"] === dataDirectory, "GP is not using the installed data"];
				dataValues = pariLinkFunction["PARIEvaluate"][session, "[bnfinit(x^2+23).no,polgalois(x^8-2)[1],galoisgetpol(8),#ellmodulareqn(11),#nflist(\"A5\")]"];
				ConfirmAssert[dataValues === {3, 16, 5, 2, 10}, "Bundled number-theory data failed"];
				ConfirmAssert[First[pariLinkFunction["PARICall"][session, "ellsearch", "11a1"]] === "11a1", "The elliptic-curve database is unavailable"],
				DeleteObject[session]
			]
		],
		innerFailure
	]

(* The integration tests run last, and the paclet that answered them must still be the installed one. *)
checkInstalledArchive[archives : {___String}] :=
	Enclose[
		Module[{installed, program, report},
			ConfirmAssert[Length[archives] === 1, "Pass the paclet archive path"];
			ConfirmAssert[PacletFind["WolframInstitute/PARILink"] === {}, "Use a fresh kernel with -pacletbase pointing to an empty directory"];
			installed = ConfirmMatch[PacletInstall[ExpandFileName[First[archives]]], _PacletObject, "PacletInstall failed"];
			WithCleanup[
				Needs["WolframInstitute`PARILink`"];
				SetEnvironment[{"PARILINK_GP" -> "", "PATH" -> ""}];
				program = FileNameJoin[{installed["Location"], "Resources", "Runtime", $SystemID, If[$OperatingSystem === "Windows", "gp.exe", "gp"]}];
				ConfirmAssert[FileExistsQ[program], "The installed paclet has no GP for this platform"];
				If[$OperatingSystem =!= "Windows",
					ConfirmAssert[RunProcess[{"/bin/chmod", "644", program}, "ExitCode"] === 0, "Could not test permission repair"]
				];
				Confirm[checkBundledGP[installed, program]];
				report = installedTestReport[];
				Print[report["TestsSucceededCount"], "/", Length[report["TestResults"]], " installed integration tests passed"];
				ConfirmAssert[
					report["TestsFailedCount"] === 0 && report["TestsSucceededCount"] > 0,
					"Installed integration tests failed: " <> ToString[failedTestIDs[report], InputForm]
				];
				ConfirmAssert[PacletObject["WolframInstitute/PARILink"]["Location"] === installed["Location"], "The tests did not use the installed paclet"];
				"PASS: PacletInstall, bundled GP, data, permission repair, and integration tests",
				PacletUninstall[installed]
			]
		],
		innerFailure
	]

result = checkInstalledArchive[DeleteDuplicates @ Select[Join[$ScriptCommandLine, $CommandLine], StringQ[#] && StringEndsQ[#, ".paclet"] &]];
If[FailureQ[result],
	Print["FAIL: ", result["Message"]];
	Exit[1],

	Print[result];
	Exit[0]
]
