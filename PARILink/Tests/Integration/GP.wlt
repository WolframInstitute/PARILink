(* Integration tests of a session from start to close: values that are copied, output, GP errors, values that GP
   keeps, and each way a request can end without a response. They need GP; set PARILINK_GP to choose one. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]
Needs["WolframInstitute`PARILink`"]

(* Gives body applied to the objects or sessions and releases them afterwards, in the order given. *)
withObjects[objects_List, body_Function] := WithCleanup[body @@ objects, Scan[DeleteObject, objects]]
withObject[object_, body_Function] := withObjects[{object}, body]

(* Text outside ASCII and the characters that a GP string would need to escape. *)
unicodeText = "\[EAcute]\[Alpha]" <> FromCharacterCode[128512] <> "\n\"\\";

session = StartPARISession[];

VerificationTest[
	{
		MatchQ[session, _PARISession],
		session["Status"],
		StringMatchQ[session["Version"], DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter..]
	},
	{True, "Ready", True},
	TestID -> "start-and-handshake"
]

VerificationTest[
	session["Process"],
	Missing["UnknownProperty", "Process"],
	TestID -> "process-is-private"
]

VerificationTest[
	PARICall[session, "factor", 360],
	{{2, 3}, {3, 2}, {5, 1}},
	TestID -> "factorization-matrix"
]

VerificationTest[
	PARICall[session, "eulerphi", 360],
	96,
	TestID -> "euler-totient"
]

VerificationTest[
	PARICall[session, "qfbclassno", -23],
	3,
	TestID -> "quadratic-class-number"
]

VerificationTest[
	PARICall[session, "abs", -(10 ^ 100 + 7)],
	10 ^ 100 + 7,
	TestID -> "large-integer-round-trip"
]

VerificationTest[
	PARICall[session, "conj", 1 / 3 + I / 7],
	1 / 3 - I / 7,
	TestID -> "exact-complex-round-trip"
]

VerificationTest[
	PARICall[session, "conj", -1 / 3 - I / 7],
	-1 / 3 + I / 7,
	TestID -> "negative-exact-complex-round-trip"
]

VerificationTest[
	PARICall[session, "concat", {unicodeText, {1 / 3, -10 ^ 50}, {}}, {}],
	{unicodeText, {1 / 3, -10 ^ 50}, {}},
	TestID -> "nested-vector-round-trip"
]

VerificationTest[
	PARICall[session, "Str", "\");quit();print(\"injected\")\\\n"],
	"\");quit();print(\"injected\")\\\n",
	TestID -> "strings-cannot-inject-code"
]

VerificationTest[
	PARICall[session, "Str", StringRepeat["\[EAcute]", 3000]],
	StringRepeat["\[EAcute]", 3000],
	TestID -> "long-utf8-input"
]

VerificationTest[
	PARIEvaluate[session, "[Vecsmall([1,2]),[5,6]~,matrix(0,0)]"],
	{{1, 2}, {5, 6}, {}},
	TestID -> "container-types"
]

VerificationTest[
	PARIEvaluate[session, "print(\"hello\");print1(\"tail\");42", "Output" -> "Capture"],
	<|"Result" -> 42, "StandardOutput" -> "hello\ntail", "StandardError" -> ""|>,
	TestID -> "capture-output"
]

VerificationTest[
	Module[{failure},
		failure = PARIEvaluate[session, "print(\"before\");1/0", "Output" -> "Capture"];
		{
			MatchQ[failure, Failure["PARIError", _]],
			failure["PARIError"],
			failure["StandardOutput"],
			StringQ[failure["PARIMessage"]],
			PARIEvaluate[session, "2+3"]
		}
	],
	{True, "e_INV", "before\n", True, 5},
	TestID -> "gp-error-preserves-output-and-session"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "x^3-x-1"],
		Function[polynomial,
			{polynomial["Type"], PARICall[session, "nfdisc", polynomial], MatchQ[Normal[polynomial], Failure["PARIUnsupportedValue", _]]}
		]
	],
	{"t_POL", -23, True},
	TestID -> "retained-polynomial"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "[1,2/3]", "ReturnType" -> "Object"],
		Function[vector, {vector["Type"], Normal[vector]}]
	],
	{"t_VEC", {1, 2 / 3}},
	TestID -> "forced-object-can-copy-exact-value"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "sqrt(2)"],
		Function[number,
			{number["Type"], StringStartsQ[number["String"], "1.414"], MatchQ[Normal[number], Failure["PARIUnsupportedValue", _]]}
		]
	],
	{"t_REAL", True, True},
	TestID -> "approximate-values-keep-pari-precision"
]

(* Normal on a vector that is too long to copy must not leave a new object behind in GP. *)
VerificationTest[
	withObject[
		PARIEvaluate[session, "vector(10001,i,i)"],
		Function[vector,
			Module[{objectCount},
				objectCount = PARIEvaluate[session, "#parilinkobjects"];
				{
					vector["Type"],
					MatchQ[Normal[vector], Failure["PARIUnsupportedValue", _]],
					PARIEvaluate[session, "#parilinkobjects"] === objectCount
				}
			]
		]
	],
	{"t_VEC", True, True},
	TestID -> "large-container-stays-an-object-without-copy-leaks"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "bnfinit(x^2+23)", "ReturnType" -> "Object"],
		Function[field, {field["Type"], PARICall[session, "bnfisprincipal", field, 2]}]
	],
	{"t_VEC", {{0}, {2, 0}}},
	TestID -> "number-field-object"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "ellinit([0,0,0,-1,0],7)", "ReturnType" -> "Object"],
		Function[curve, PARICall[session, "ellcard", curve]]
	],
	8,
	TestID -> "elliptic-curve-object"
]

VerificationTest[
	PARIEvaluate[session, "x^2+1", "ReturnType" -> "String"],
	"x^2 + 1",
	TestID -> "explicit-string-result"
]

VerificationTest[
	withObjects[
		{PARIEvaluate[session, "x"], StartPARISession[]},
		Function[{polynomial, other}, MatchQ[PARICall[other, "type", polynomial], Failure["PARIInvalidObject", _]]]
	],
	True,
	TestID -> "objects-cannot-cross-sessions"
]

VerificationTest[
	Module[{polynomial},
		polynomial = PARIEvaluate[session, "x"];
		DeleteObject[polynomial];
		MatchQ[PARICall[session, "type", polynomial], Failure["PARIInvalidObject", _]]
	],
	True,
	TestID -> "released-object-is-invalid"
]

VerificationTest[
	Module[{other, polynomial},
		other = StartPARISession[];
		polynomial = PARIEvaluate[other, "x"];
		DeleteObject[other];
		{other["Status"], MatchQ[Normal[polynomial], Failure["PARIInvalidObject", _]], DeleteObject[other]}
	],
	{"Closed", True, Null},
	TestID -> "closing-invalidates-objects-and-is-idempotent"
]

VerificationTest[
	withObject[
		StartPARISession[],
		Function[other,
			Module[{result},
				result = PARIEvaluate[other, "while(1,)", TimeConstraint -> 0.1];
				{MatchQ[result, Failure["PARITimeout", _]], other["Status"], MatchQ[PARIEvaluate[other, "1"], Failure["PARIInvalidSession", _]]}
			]
		]
	],
	{True, "Stopped", True},
	TestID -> "timeout-stops-session"
]

VerificationTest[
	withObject[
		StartPARISession[],
		Function[other,
			Module[{abortedQ},
				abortedQ = CheckAbort[TimeConstrained[PARIEvaluate[other, "while(1,)", TimeConstraint -> Infinity], 0.2, Abort[]], True];
				{abortedQ, other["Status"]}
			]
		]
	],
	{True, "Stopped"},
	TestID -> "interrupted-request-stops-session"
]

VerificationTest[
	withObject[
		StartPARISession[],
		Function[other,
			Module[{result},
				result = PARIEvaluate[other, "my(s=strchr(vector(1024,i,65)));for(i=1,17000,print1(s));0", "Output" -> "Discard"];
				{Replace[result, Failure[tag_, _] :> tag], other["Status"]}
			]
		]
	],
	{"PARIOutputLimit", "Stopped"},
	TestID -> "excessive-output-stops-session"
]

VerificationTest[
	withObject[
		StartPARISession[],
		Function[other,
			Module[{result},
				result = PARIEvaluate[other, "quit()"];
				{MatchQ[result, Failure["PARIProcessStopped", _]], other["Status"]}
			]
		]
	],
	{True, "Stopped"},
	TestID -> "process-exit-stops-session"
]

(* Replacing a function of the startup file makes GP send a response that is not valid. *)
VerificationTest[
	withObject[
		StartPARISession[],
		Function[other,
			Module[{result},
				result = PARIEvaluate[other, "parilinkencode(x,depth=0,references=1)=\"[1,2]\";1"];
				{MatchQ[result, Failure["PARIProtocolError", _]], other["Status"]}
			]
		]
	],
	{True, "Stopped"},
	TestID -> "malformed-response-stops-session"
]

DeleteObject[session];
