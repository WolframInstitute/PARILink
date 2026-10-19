(* Compare the public link against independent native-GP snapshots. *)
root = Nest[ParentDirectory, DirectoryName[$InputFileName], 2];
PacletDirectoryLoad[FileNameJoin[{root, "PARILink"}]];
Needs["WolframInstitute`PARILink`"];
manifest = Import[ExpandFileName[$ScriptCommandLine[[2]]], "RawJSON"];
resultPath = FileNameJoin[{manifest["output"], "report.json"}];
SetEnvironment["GP_SVG_VIEWER" -> manifest["viewer"]];
SetEnvironment["GP_POSTSCRIPT_VIEWER" -> manifest["viewer"]];

integerText[n_Integer] := If[n < 0, "-", ""] <> IntegerString[Abs[n]];
snapshot[n_Integer] := {"i", integerText[n]};
snapshot[n_Rational] := {"q", integerText[Numerator[n]], integerText[Denominator[n]]};
snapshot[n_Complex] := {"c", snapshot[Re[n]], snapshot[Im[n]]};
snapshot[s_String] := {"s", ToCharacterCode[s, "UTF-8"]};
snapshot[v_List] := {"v", snapshot /@ v};
snapshot[o_PARIObject] := {"o", o["Type"], Lookup[objectHashes, First[o], "missing"]};
snapshot[x_] := {"unexpected", ToString[x, InputForm]};

hashObjects[value_] := Module[{objects, lengths, stream, hashes},
	objects = DeleteDuplicates @ Cases[{value}, _PARIObject, Infinity];
	If[objects === {}, Return[<||>]];
	If[FileExistsQ["audit-objects.txt"], DeleteFile["audit-objects.txt"]];
	lengths = Flatten[PARICall[session, "apply", writer, #, "Output" -> "Discard",
		TimeConstraint -> manifest["timeout"]] & /@ Partition[objects, UpTo[256]], 1];
	If[! MatchQ[lengths, {_Integer ..}] || Length[lengths] =!= Length[objects], Return[<||>]];
	stream = OpenRead["audit-objects.txt", BinaryFormat -> True];
	hashes = WithCleanup[
		Hash[ReadByteArray[stream, #], "SHA256", "HexString"] & /@ lengths,
		Close[stream]
	];
	AssociationThread[First /@ objects, hashes]
];

report = If[MemberQ[$ScriptCommandLine, "resume"] && FileExistsQ[resultPath], Import[resultPath, "RawJSON"], {}];
completed = #["file"] & /@ report;
Do[
	file = Import[entry["path"], "RawJSON"];
	name = file["file"];
	If[MemberQ[completed, name], Continue[]];
	directory = FileNameJoin[{manifest["output"], "linked", name}];
	If[! DirectoryQ[directory], CreateDirectory[directory, CreateIntermediateDirectories -> True]];
	SetDirectory[directory];
	SetEnvironment["GPTMPDIR" -> directory];
	session = StartPARISession["Executable" -> manifest["gp"]];
	If[FailureQ[session], Print[session]; Exit[1]];
	If[MemberQ[{"parallel", "parallel-alarm"}, name], PARICall[session, "default", "nbthreads", 2, "Output" -> "Discard"]];
	PARIEvaluate[session, "setrand(1)", "Output" -> "Discard"];
	If[StringQ[manifest["data"]], PARICall[session, "default", "datadir", manifest["data"], "Output" -> "Discard"]];
	writer = PARIEvaluate[session, "x -> {my(s=Str(x));write(\"audit-objects.txt\",s);#s+1}", "ReturnType" -> "Object"];
	cases = {};
	WithCleanup[
		Do[
			If[session["Status"] =!= "Ready",
				AppendTo[cases, <|"line" -> case["line"], "status" -> "not-run"|>]; Continue[]];
			actual = PARIEvaluate[session, case["code"], "Output" -> "Capture", TimeConstraint -> manifest["timeout"]];
			If[FailureQ[actual],
				observed = If[MatchQ[actual, Failure["PARIError", _]], {"error", actual["PARIError"]}, {"failure", actual[[1]]}],
				objectHashes = hashObjects[actual["Result"]];
				observed = {"ok", snapshot[actual["Result"]]}
			];
			standardOutput = If[AssociationQ[actual], actual["StandardOutput"], Replace[actual["StandardOutput"], Except[_String] -> ""]];
			standardError = Replace[actual["StandardError"], Except[_String] -> ""];
			matched = SameQ[observed, case["expected"]] && standardOutput === case["stdout"];
			stackWarning = SameQ[observed, case["expected"]] && StringContainsQ[standardError, "Warning: increasing stack size"] &&
				StringDelete[standardOutput, "\n"] === StringDelete[case["stdout"], "\n"];
			environment = (SameQ[observed, case["expected"]] || First[observed] === First[case["expected"]] === "ok") &&
				(name === "time" || StringContainsQ[case["code"],
					RegularExpression["\\b(getheap|getstack|gettime|getwalltime|getabstime)\\b"]] || stackWarning);
			status = Which[matched, "matched", environment, "environment", True, "failed"];
			AppendTo[cases, Join[<|"line" -> case["line"], "status" -> status|>,
				If[status =!= "matched", <|"actual" -> observed, "stdout" -> standardOutput,
					"stderr" -> standardError|>, <||>]]];
			If[Mod[Length[cases], 100] === 0, Print[name, ": ", Length[cases], " checked"]],
			{case, file["cases"]}
		],
		DeleteObject[session]; ResetDirectory[]
	];
	(* Native nonlocal errors have no value to compare. Check that the link
	   stops cleanly, in separate sessions so the remaining suite can run. *)
	boundaries = Table[
		other = StartPARISession["Executable" -> manifest["gp"]];
		WithCleanup[
			actual = PARIEvaluate[other, case["code"], TimeConstraint -> 5, "Output" -> "Capture"];
			safeStop = MatchQ[actual, Failure["PARIInterrupted" | "PARIProcessStopped", _]] && other["Status"] === "Stopped";
			<|"line" -> case["line"], "status" -> If[safeStop, "native-no-result", "uncompared"],
				"linkResult" -> If[FailureQ[actual], First[actual], "result"], "linkStatus" -> other["Status"]|>,
			DeleteObject[other]
		],
		{case, file["missing"]}
	];
	AppendTo[report, <|"file" -> name, "source" -> Lookup[file, "source", name], "cases" -> cases,
		"nativeMissing" -> boundaries, "nativeTimeout" -> file["timeout"]|>];
	If[Export[resultPath <> ".tmp", report, "RawJSON"] === $Failed, Exit[1]];
	RenameFile[resultPath <> ".tmp", resultPath, OverwriteTarget -> True];
	Print[name, ": ", Count[#["status"] & /@ cases, "matched"], "/", Length[cases], " matched"],
	{entry, manifest["files"]}
];
counts = Counts[Flatten[Function[file, (#["status"] & /@ Join[file["cases"], file["nativeMissing"]])] /@ report]];
Print[counts];
Exit[If[Total[Lookup[counts, {"failed", "not-run", "uncompared"}, 0]] > 0 || MemberQ[Lookup[report, "nativeTimeout"], True], 1, 0]];
