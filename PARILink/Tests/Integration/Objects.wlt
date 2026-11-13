(* Integration tests of what a session keeps between requests: variables, functions, lists and maps of GP, the files
   of the requests, and the stack of GP. They need GP; set PARILINK_GP to choose one. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]
Needs["WolframInstitute`PARILink`"]

(* Gives body applied to the objects or sessions and releases them afterwards, in the order given. *)
withObjects[objects_List, body_Function] := WithCleanup[body @@ objects, Scan[DeleteObject, objects]]
withObject[object_, body_Function] := withObjects[{object}, body]

session = StartPARISession[];

(* The startup file uses these names for its arguments. A variable of the user with the same name is another variable. *)
VerificationTest[
	PARIEvaluate[session, "value=11;result=12;code=13;mode=14;marker=15"];
	PARIEvaluate[session, "[value,result,code,mode,marker]"],
	{11, 12, 13, 14, 15},
	TestID -> "user-variables-do-not-shadow-bridge-state"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "n -> n^2+1"],
		Function[function, {function["String"], PARICall[session, "apply", function, {1, 2, 3}]}]
	],
	{"(n)->n^2+1", {2, 5, 10}},
	TestID -> "closures-do-not-capture-bridge-locals"
]

VerificationTest[
	PARIEvaluate[session, "f(n) =\n{\n  n^2 + 1\n}\nf(3)"],
	10,
	TestID -> "multiline-gp-scripts"
]

VerificationTest[
	withObject[
		StartPARISession[],
		Function[other,
			PARIEvaluate[other, "inline(prsin);"];
			PARIEvaluate[other, "prsin()=parfor(i=1,1,2,E,return(E));"];
			PARIEvaluate[other, "prsin()"]
		]
	],
	2,
	TestID -> "inline-declarations-use-the-gp-script-parser"
]

(* Each request writes its code to a file in the temporary directory. A result, a GP error and a timeout must all remove it. *)
VerificationTest[
	Module[{directory, other},
		directory = CreateDirectory[];
		WithCleanup[
			Block[{$TemporaryDirectory = directory},
				other = StartPARISession[];
				PARIEvaluate[other, "1+1"];
				PARIEvaluate[other, "1/0", "Output" -> "Discard"];
				PARIEvaluate[other, "while(1,)", TimeConstraint -> 0.2];
				{other["Status"], FileNames["*", directory]}
			],
			DeleteObject[other];
			DeleteDirectory[directory, DeleteContents -> True]
		]
	],
	{"Stopped", {}},
	TestID -> "request-files-are-removed-after-results-errors-and-timeouts"
]

(* Setting parisize makes GP drop the request. The session must notice at once, not when the time limit ends. *)
VerificationTest[
	withObject[
		StartPARISession[],
		Function[other,
			Module[{result},
				result = PARIEvaluate[other, "default(parisize,16000000)", TimeConstraint -> 5];
				{Replace[result, Failure[tag_, _] :> tag], other["Status"]}
			]
		]
	],
	{"PARIInterrupted", "Stopped"},
	TestID -> "stack-reset-stops-session-without-waiting-for-timeout"
]

VerificationTest[
	withObject[
		StartPARISession[],
		Function[other, {PARIEvaluate[other, "allocatemem(16000000)"], other["Status"], PARIEvaluate[other, "1+1"]}]
	],
	{0, "Ready", 2},
	TestID -> "stack-allocation-preserves-a-completed-request"
]

VerificationTest[
	withObject[
		PARICall[session, "List", {1, 2}],
		Function[list, {list["Type"], PARICall[session, "listput", list, 3], PARICall[session, "Vec", list]}]
	],
	{"t_LIST", 3, {1, 2, 3}},
	TestID -> "retained-lists-support-mutation"
]

VerificationTest[
	withObject[
		PARICall[session, "Map"],
		Function[map,
			PARICall[session, "mapput", map, "answer", 42];
			{
				map["Type"],
				PARICall[session, "mapget", map, "answer"],
				PARICall[session, "mapdelete", map, "answer"],
				PARICall[session, "mapisdefined", map, "answer"]
			}
		]
	],
	{"t_LIST", 42, 0, 0},
	TestID -> "retained-maps-support-mutation"
]

(* GP gives the place of a released value to the next one. The released object must not name the new value. *)
VerificationTest[
	Module[{released},
		released = PARIEvaluate[session, "x"];
		DeleteObject[released];
		withObject[
			PARIEvaluate[session, "y"],
			Function[current, {MatchQ[PARICall[session, "type", released], Failure["PARIInvalidObject", _]], current["String"]}]
		]
	],
	{True, "y"},
	TestID -> "reused-storage-does-not-revive-released-objects"
]

VerificationTest[
	withObject[
		PARICall[session, "List", {1, 2}],
		Function[list, {MatchQ[Normal[list], Failure["PARIUnsupportedValue", _]], PARICall[session, "Vec", list]}]
	],
	{True, {1, 2}},
	TestID -> "mutable-containers-require-explicit-conversion"
]

DeleteObject[session];
