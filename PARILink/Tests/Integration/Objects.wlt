Needs["WolframInstitute`PARILink`"];

session = StartPARISession[];

VerificationTest[
	PARIEvaluate[session, "value=11;result=12;code=13;mode=14;marker=15"];
	PARIEvaluate[session, "[value,result,code,mode,marker]"],
	{11, 12, 13, 14, 15}, TestID -> "user-variables-do-not-shadow-bridge-state"
]

VerificationTest[
	Module[{function = PARIEvaluate[session, "n -> n^2+1"]}, WithCleanup[
		{function["String"], PARICall[session, "apply", function, {1, 2, 3}]},
		DeleteObject[function]
	]], {"(n)->n^2+1", {2, 5, 10}}, TestID -> "closures-do-not-capture-bridge-locals"
]

VerificationTest[
	PARIEvaluate[session, "f(n) =\n{\n  n^2 + 1\n}\nf(3)"],
	10, TestID -> "multiline-gp-scripts"
]

VerificationTest[
	Module[{other = StartPARISession[]}, WithCleanup[
		PARIEvaluate[other, "inline(prsin);"];
		PARIEvaluate[other, "prsin()=parfor(i=1,1,2,E,return(E));"];
		PARIEvaluate[other, "prsin()"], DeleteObject[other]
	]], 2, TestID -> "inline-declarations-use-the-gp-script-parser"
]

VerificationTest[
	Module[{directory = CreateDirectory[], other}, WithCleanup[
		Block[{$TemporaryDirectory = directory},
			other = StartPARISession[];
			PARIEvaluate[other, "1+1"];
			PARIEvaluate[other, "1/0", "Output" -> "Discard"];
			PARIEvaluate[other, "while(1,)", TimeConstraint -> 0.2];
			{other["Status"], FileNames["*", directory]}
		],
		DeleteObject[other]; DeleteDirectory[directory, DeleteContents -> True]
	]], {"Stopped", {}}, TestID -> "request-files-are-removed-after-results-errors-and-timeouts"
]

VerificationTest[
	Module[{other = StartPARISession[], result}, WithCleanup[
		result = PARIEvaluate[other, "default(parisize,16000000)", TimeConstraint -> 5];
		{If[FailureQ[result], First[result], result], other["Status"]}, DeleteObject[other]
	]], {"PARIInterrupted", "Stopped"}, TestID -> "stack-reset-stops-session-without-waiting-for-timeout"
]

VerificationTest[
	Module[{other = StartPARISession[]}, WithCleanup[
		{PARIEvaluate[other, "allocatemem(16000000)"], other["Status"], PARIEvaluate[other, "1+1"]},
		DeleteObject[other]
	]], {0, "Ready", 2}, TestID -> "stack-allocation-preserves-a-completed-request"
]

VerificationTest[
	Module[{list = PARICall[session, "List", {1, 2}]}, WithCleanup[
		{list["Type"], PARICall[session, "listput", list, 3], PARICall[session, "Vec", list]},
		DeleteObject[list]
	]], {"t_LIST", 3, {1, 2, 3}}, TestID -> "retained-lists-support-mutation"
]

VerificationTest[
	Module[{map = PARICall[session, "Map"]}, WithCleanup[
		PARICall[session, "mapput", map, "answer", 42];
		{map["Type"], PARICall[session, "mapget", map, "answer"],
			PARICall[session, "mapdelete", map, "answer"], PARICall[session, "mapisdefined", map, "answer"]},
		DeleteObject[map]
	]], {"t_LIST", 42, 0, 0}, TestID -> "retained-maps-support-mutation"
]

VerificationTest[
	Module[{old, current},
		old = PARIEvaluate[session, "x"]; DeleteObject[old];
		current = PARIEvaluate[session, "y"];
		WithCleanup[
			{MatchQ[PARICall[session, "type", old], Failure["PARIInvalidObject", _]], current["String"]},
			DeleteObject[current]
		]
	], {True, "y"}, TestID -> "reused-storage-does-not-revive-released-objects"
]

VerificationTest[
	Module[{list = PARICall[session, "List", {1, 2}]}, WithCleanup[
		{MatchQ[Normal[list], Failure["PARIUnsupportedValue", _]], PARICall[session, "Vec", list]},
		DeleteObject[list]
	]], {True, {1, 2}}, TestID -> "mutable-containers-require-explicit-conversion"
]

DeleteObject[session];
