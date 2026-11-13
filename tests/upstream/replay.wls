(* Compares the public link with snapshots of native GP that tests/upstream/prepare.py made. Each suite runs in a
   fresh session; the report and a checkpoint go to the output directory of the manifest.
   usage: wolframscript -file tests/upstream/replay.wls <manifest> [resume] *)

$root = Nest[ParentDirectory, DirectoryName[$InputFileName], 2];
PacletDirectoryLoad[FileNameJoin[{$root, "PARILink"}]];
Needs["WolframInstitute`PARILink`"];

$manifestPath = Replace[
	$ScriptCommandLine,
	{
		{_, path_String, ___} :> ExpandFileName[path],
		_ :> (
			Print["usage: wolframscript -file tests/upstream/replay.wls <manifest> [resume]"];
			Exit[2]
		)
	}
];
$manifest = Import[$manifestPath, "RawJSON"];
$resultPath = FileNameJoin[{$manifest["output"], "report.json"}];
$timeConstraint = $manifest["timeout"];
$objectFile = "audit-objects.txt";
$environmentPattern = RegularExpression["\\b(getheap|getstack|gettime|getwalltime|getabstime)\\b"];
SetEnvironment["GP_SVG_VIEWER" -> $manifest["viewer"]];
SetEnvironment["GP_POSTSCRIPT_VIEWER" -> $manifest["viewer"]];

integerText[value_Integer] := If[value < 0, "-", ""] <> IntegerString[Abs[value]]

(* A value as the snapshots of native GP write it. A value that GP keeps is written as its type and the hash of its
   text in GP, from objectHashes. *)
snapshot[value_Integer, _Association] := {"i", integerText[value]}
snapshot[value_Rational, _Association] := {"q", integerText[Numerator[value]], integerText[Denominator[value]]}
snapshot[value_Complex, objectHashes_Association] := {"c", snapshot[Re[value], objectHashes], snapshot[Im[value], objectHashes]}
snapshot[text_String, _Association] := {"s", ToCharacterCode[text, "UTF-8"]}
snapshot[values_List, objectHashes_Association] := {"v", Map[snapshot[#, objectHashes] &, values]}
snapshot[object_PARIObject, objectHashes_Association] := {"o", object["Type"], Lookup[objectHashes, First[object], "missing"]}
snapshot[value_, _Association] := {"unexpected", ToString[value, InputForm]}

(* GP writes the text of each object to a file through the writer function, and gives the length of each text. The
   texts are read back and hashed, so that large objects need not cross the link. *)
writtenLengths[session_PARISession, writer_PARIObject, objects_List] :=
	Flatten[
		Map[
			PARICall[session, "apply", writer, #, "Output" -> "Discard", TimeConstraint -> $timeConstraint] &,
			Partition[objects, UpTo[256]]
		],
		1
	]

hashesOfLengths[lengths : {___Integer}] :=
	Module[{stream},
		stream = OpenRead[$objectFile, BinaryFormat -> True];
		WithCleanup[Map[Hash[ReadByteArray[stream, #], "SHA256", "HexString"] &, lengths], Close[stream]]
	]

hashesOfObjects[session_PARISession, writer_PARIObject, objects : {__PARIObject}] :=
	Module[{lengths},
		If[FileExistsQ[$objectFile], DeleteFile[$objectFile]];
		lengths = writtenLengths[session, writer, objects];
		If[MatchQ[lengths, {__Integer}] && Length[lengths] === Length[objects],
			AssociationThread[Map[First, objects], hashesOfLengths[lengths]],
			<||>
		]
	]

hashObjects[session_PARISession, writer_PARIObject, value_] :=
	Module[{objects},
		objects = DeleteDuplicates @ Cases[{value}, _PARIObject, Infinity];
		If[objects === {}, <||>, hashesOfObjects[session, writer, objects]]
	]

observedResult[session_PARISession, writer_PARIObject, actual_] :=
	Which[
		MatchQ[actual, Failure["PARIError", _]],
			{"error", actual["PARIError"]},
		FailureQ[actual],
			{"failure", First[actual]},
		True,
			{"ok", snapshot[actual["Result"], hashObjects[session, writer, actual["Result"]]]}
	]

(* A difference that comes from the processes, not from the link: timing and memory queries, and the newlines of a
   warning about stack growth. *)
environmentDifferenceQ[suiteName_String, case_Association, observed_List, standardOutput_String, standardError_String] :=
	Module[{sameResultQ, stackWarningQ},
		sameResultQ = SameQ[observed, case["expected"]];
		stackWarningQ = And[
			sameResultQ,
			StringContainsQ[standardError, "Warning: increasing stack size"],
			StringDelete[standardOutput, "\n"] === StringDelete[case["stdout"], "\n"]
		];
		And[
			sameResultQ || First[observed] === First[case["expected"]] === "ok",
			suiteName === "time" || StringContainsQ[case["code"], $environmentPattern] || stackWarningQ
		]
	]

caseRecord[session_PARISession, writer_PARIObject, suiteName_String, case_Association] :=
	Module[{actual, observed, standardOutput, standardError, status},
		If[session["Status"] =!= "Ready",
			<|"line" -> case["line"], "status" -> "not-run"|>,

			actual = PARIEvaluate[session, case["code"], "Output" -> "Capture", TimeConstraint -> $timeConstraint];
			observed = observedResult[session, writer, actual];
			standardOutput = Replace[actual["StandardOutput"], Except[_String] -> ""];
			standardError = Replace[actual["StandardError"], Except[_String] -> ""];
			status = Which[
				SameQ[observed, case["expected"]] && standardOutput === case["stdout"],
					"matched",
				environmentDifferenceQ[suiteName, case, observed, standardOutput, standardError],
					"environment",
				True,
					"failed"
			];
			Join[
				<|"line" -> case["line"], "status" -> status|>,
				If[status =!= "matched", <|"actual" -> observed, "stdout" -> standardOutput, "stderr" -> standardError|>, <||>]
			]
		]
	]

(* A native nonlocal error has no value to compare. The link must stop cleanly, in a separate session, so that the
   rest of the suite can run. *)
boundaryRecord[case_Association] :=
	Module[{other, actual, safeStopQ},
		other = StartPARISession["Executable" -> $manifest["gp"]];
		WithCleanup[
			actual = PARIEvaluate[other, case["code"], TimeConstraint -> 5, "Output" -> "Capture"];
			safeStopQ = MatchQ[actual, Failure["PARIInterrupted" | "PARIProcessStopped", _]] && other["Status"] === "Stopped";
			<|
				"line" -> case["line"],
				"status" -> If[safeStopQ, "native-no-result", "uncompared"],
				"linkResult" -> If[FailureQ[actual], First[actual], "result"],
				"linkStatus" -> other["Status"]
			|>,
			DeleteObject[other]
		]
	]

startSuiteSession[suiteName_String] :=
	Module[{session},
		session = StartPARISession["Executable" -> $manifest["gp"]];
		If[FailureQ[session],
			Print[session];
			Exit[1]
		];
		If[MemberQ[{"parallel", "parallel-alarm"}, suiteName], PARICall[session, "default", "nbthreads", 2, "Output" -> "Discard"]];
		PARIEvaluate[session, "setrand(1)", "Output" -> "Discard"];
		If[StringQ[$manifest["data"]], PARICall[session, "default", "datadir", $manifest["data"], "Output" -> "Discard"]];
		session
	]

suiteCaseRecords[suite_Association] :=
	Module[{suiteName, session, writer},
		suiteName = suite["file"];
		session = startSuiteSession[suiteName];
		writer = PARIEvaluate[session, "x -> {my(s=Str(x));write(\"" <> $objectFile <> "\",s);#s+1}", "ReturnType" -> "Object"];
		WithCleanup[
			MapIndexed[
				Function[{case, position},
					Module[{record},
						record = caseRecord[session, writer, suiteName, case];
						If[Mod[First[position], 100] === 0, Print[suiteName, ": ", First[position], " checked"]];
						record
					]
				],
				suite["cases"]
			],
			DeleteObject[session]
		]
	]

writeCheckpoint[report_List] := (
	If[Export[$resultPath <> ".tmp", report, "RawJSON"] === $Failed, Exit[1]];
	RenameFile[$resultPath <> ".tmp", $resultPath, OverwriteTarget -> True]
)

(* Runs the suite of one manifest entry in its own directory and gives the report with the suite added. A suite that
   a resumed report has is left out. *)
replaySuite[report_List, entry_Association] :=
	Module[{suite, suiteName, directory, cases, boundaries, newReport},
		suite = Import[entry["path"], "RawJSON"];
		suiteName = suite["file"];
		If[MemberQ[Lookup[report, "file"], suiteName],
			report,

			directory = FileNameJoin[{$manifest["output"], "linked", suiteName}];
			If[!DirectoryQ[directory], CreateDirectory[directory, CreateIntermediateDirectories -> True]];
			SetDirectory[directory];
			SetEnvironment["GPTMPDIR" -> directory];
			cases = WithCleanup[suiteCaseRecords[suite], ResetDirectory[]];
			boundaries = Map[boundaryRecord, suite["missing"]];
			newReport = Append[
				report,
				<|"file" -> suiteName, "source" -> Lookup[suite, "source", suiteName], "cases" -> cases, "nativeMissing" -> boundaries, "nativeTimeout" -> suite["timeout"]|>
			];
			writeCheckpoint[newReport];
			Print[suiteName, ": ", Count[Lookup[cases, "status"], "matched"], "/", Length[cases], " matched"];
			newReport
		]
	]

$resumedReport = If[MemberQ[$ScriptCommandLine, "resume"] && FileExistsQ[$resultPath], Import[$resultPath, "RawJSON"], {}];
$report = Fold[replaySuite, $resumedReport, $manifest["files"]];
$counts = Counts[Flatten[Map[Function[suite, Lookup[Join[suite["cases"], suite["nativeMissing"]], "status"]], $report]]];
Print[$counts];
Exit[If[Total[Lookup[$counts, {"failed", "not-run", "uncompared"}, 0]] > 0 || MemberQ[Lookup[$report, "nativeTimeout"], True], 1, 0]]
