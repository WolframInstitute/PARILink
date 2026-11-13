(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{TestPaclet, TestPARI}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{runTests}];

(* ::Section:: *)
(*Usage Messages*)

TestPaclet::usage = "TestPaclet[] runs the tests that do not need GP: the paclet tests and the tests of the scripts. With test files named on \
the command line it runs only those files.";
TestPARI::usage = "TestPARI[] runs the tests that need GP, the files of PARILink/Tests/Integration, and prints which GP they use. PARILINK_GP \
names the GP program; without it PARILink finds one.";
logGPVersion::usage = "logGPVersion[] starts the GP that the tests will use, prints its version and its path, and closes it. It stops the \
current task when GP does not start.";
runTests::usage = "runTests[files] runs the test files, a list of paths, and prints the number of tests that passed in each. It stops the current \
task when no file is given, a file has no tests or a test fails.";
offlineTestFiles::usage = "offlineTestFiles[] lists the test files that do not need GP: those of the paclet and those of the scripts.";
show::usage = "show[expression] gives the InputForm text of an expression, without evaluating it when it is wrapped in HoldForm.";
testResults::usage = "testResults[report] gives the list of test results of a test report.";
testFileReport::usage = "testFileReport[file] runs the tests of one file, prints the number that passed, and gives the test report.";
reportFailure::usage = "reportFailure[result] prints the test ID, the actual output, the expected output and the messages of a failed test result.";
reportFailures::usage = "reportFailures[report] prints each failed test of a test report.";

(* ::Section:: *)
(*Function Definitions*)

offlineTestFiles[] := Join[FileNames["*.wlt", FileNameJoin[{$PacletDirectory, "Tests"}]], FileNames["*.wlt", FileNameJoin[{$RepositoryRoot, "tests"}]]]

show[HoldForm[expression_]] := ToString[Unevaluated[expression], InputForm]
show[expression_] := ToString[expression, InputForm]

testResults[report_TestReportObject] := Replace[report["TestResults"], results_Association :> Values[results]]

testFileReport[file_String] :=
	Module[{report},
		RequireOrLog[file, FileExistsQ, "Test file not found: ", file];
		report = TestReport[file];
		RequireOrLog[report, MatchQ[#, _TestReportObject] &, "Could not run ", file];
		RequireOrLog[testResults[report], MatchQ[#, {__}] &, "No tests found in ", file];
		LogInfo["  ", FileNameTake[file], ": ", report["TestsSucceededCount"], "/", report["TestsSucceededCount"] + report["TestsFailedCount"]];
		report
	]

reportFailure[result_TestResultObject] :=
	LogInfo[
		"FAIL: ", result["TestID"],
		"\n  Actual: ", show[result["ActualOutput"]],
		"\n  Expected: ", show[result["ExpectedOutput"]],
		Replace[result["ActualMessages"], {messages : {__} :> "\n  Messages: " <> show[messages], _ -> ""}]
	]

reportFailures[report_TestReportObject] := Scan[reportFailure, Select[testResults[report], #["Outcome"] =!= "Success" &]]

runTests[files : {___String}] :=
	Module[{reports, passed, failed, runtimeFailures},
		RequireOrLog[files, # =!= {} &, "No test files found"];
		reports = testFileReport /@ files;
		passed = Total[Map[#["TestsSucceededCount"] &, reports]];
		failed = Total[Map[#["TestsFailedCount"] &, reports]];
		runtimeFailures = Total[Map[Length[#["RuntimeFailures"]] &, reports]];
		If[failed + runtimeFailures > 0,
			Scan[reportFailures, reports];
			failTask[failed, " failed test(s), ", runtimeFailures, " runtime failure(s)"]
		];
		LogInfo["OK: ", passed, " tests passed"]
	]

TestPaclet[] := (
	LoadPaclet[];
	runTests[If[$ScriptArguments === {}, offlineTestFiles[], resolveStyleFile /@ $ScriptArguments]]
)
TestPaclet[___] := invalidArgumentsFailure[TestPaclet]

logGPVersion[] :=
	Module[{session},
		session = pariLinkFunction["StartPARISession"][];
		RequireOrLog[session, !FailureQ[#] &, "GP is required for these tests: ", session];
		WithCleanup[
			LogInfo["  GP ", session["Version"], " | ", session["Executable"]],
			DeleteObject[session]
		]
	]

TestPARI[] := (
	LoadPaclet[];
	logGPVersion[];
	runTests[FileNames["*.wlt", FileNameJoin[{$PacletDirectory, "Tests", "Integration"}]]]
)
TestPARI[___] := invalidArgumentsFailure[TestPARI]
