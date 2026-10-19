Needs["WolframInstitute`PARILink`"];

session = StartPARISession[];

VerificationTest[
	{Head[session], session["Status"], StringMatchQ[session["Version"], DigitCharacter .. ~~ "." ~~ DigitCharacter .. ~~ "." ~~ DigitCharacter ..]},
	{PARISession, "Ready", True}, TestID -> "start-and-handshake"
]

VerificationTest[session["Process"], Missing["UnknownProperty", "Process"], TestID -> "process-is-private"]

VerificationTest[PARICall[session, "factor", 360], {{2, 3}, {3, 2}, {5, 1}}, TestID -> "factorization-matrix"]
VerificationTest[PARICall[session, "eulerphi", 360], 96, TestID -> "euler-totient"]
VerificationTest[PARICall[session, "qfbclassno", -23], 3, TestID -> "quadratic-class-number"]

VerificationTest[
	PARICall[session, "abs", -(10^100 + 7)], 10^100 + 7, TestID -> "large-integer-round-trip"
]

VerificationTest[PARICall[session, "conj", 1/3 + I/7], 1/3 - I/7, TestID -> "exact-complex-round-trip"]
VerificationTest[PARICall[session, "conj", -1/3 - I/7], -1/3 + I/7, TestID -> "negative-exact-complex-round-trip"]

VerificationTest[
	PARICall[session, "concat", {"éα😀\n\"\\", {1/3, -10^50}, {}}, {}],
	{"éα😀\n\"\\", {1/3, -10^50}, {}}, TestID -> "nested-vector-round-trip"
]

VerificationTest[
	PARICall[session, "Str", "\");quit();print(\"injected\")\\\n"], "\");quit();print(\"injected\")\\\n",
	TestID -> "strings-cannot-inject-code"
]

VerificationTest[
	PARICall[session, "Str", StringRepeat["é", 3000]], StringRepeat["é", 3000], TestID -> "long-utf8-input"
]

VerificationTest[
	PARIEvaluate[session, "[Vecsmall([1,2]),[5,6]~,matrix(0,0)]"],
	{{1, 2}, {5, 6}, {}}, TestID -> "container-types"
]

VerificationTest[
	PARIEvaluate[session, "print(\"hello\");print1(\"tail\");42", "Output" -> "Capture"],
	<|"Result" -> 42, "StandardOutput" -> "hello\ntail", "StandardError" -> ""|>, TestID -> "capture-output"
]

VerificationTest[
	Module[{failure = PARIEvaluate[session, "print(\"before\");1/0", "Output" -> "Capture"]},
		{MatchQ[failure, Failure["PARIError", _]], failure["PARIError"], failure["StandardOutput"],
			StringQ[failure["PARIMessage"]], PARIEvaluate[session, "2+3"]}
	], {True, "e_INV", "before\n", True, 5}, TestID -> "gp-error-preserves-output-and-session"
]

VerificationTest[
	Module[{object = PARIEvaluate[session, "x^3-x-1"]}, WithCleanup[
		{object["Type"], PARICall[session, "nfdisc", object], MatchQ[Normal[object], Failure["PARIUnsupportedValue", _]]},
		DeleteObject[object]
	]], {"t_POL", -23, True}, TestID -> "retained-polynomial"
]

VerificationTest[
	Module[{object = PARIEvaluate[session, "[1,2/3]", "ReturnType" -> "Object"]}, WithCleanup[
		{object["Type"], Normal[object]}, DeleteObject[object]
	]], {"t_VEC", {1, 2/3}}, TestID -> "forced-object-can-copy-exact-value"
]

VerificationTest[
	Module[{object = PARIEvaluate[session, "sqrt(2)"]}, WithCleanup[
		{object["Type"], StringStartsQ[object["String"], "1.414"], MatchQ[Normal[object], Failure["PARIUnsupportedValue", _]]},
		DeleteObject[object]
	]], {"t_REAL", True, True}, TestID -> "approximate-values-keep-pari-precision"
]

VerificationTest[
	Module[{object = PARIEvaluate[session, "vector(10001,i,i)"], before}, WithCleanup[
		before = PARIEvaluate[session, "#parilinkobjects"];
		{object["Type"], MatchQ[Normal[object], Failure["PARIUnsupportedValue", _]],
			PARIEvaluate[session, "#parilinkobjects"] === before},
		DeleteObject[object]
	]], {"t_VEC", True, True}, TestID -> "large-container-stays-an-object-without-copy-leaks"
]

VerificationTest[
	Module[{field = PARIEvaluate[session, "bnfinit(x^2+23)", "ReturnType" -> "Object"]}, WithCleanup[
		{field["Type"], PARICall[session, "bnfisprincipal", field, 2]}, DeleteObject[field]
	]], {"t_VEC", {{0}, {2, 0}}}, TestID -> "number-field-object"
]

VerificationTest[
	Module[{curve = PARIEvaluate[session, "ellinit([0,0,0,-1,0],7)", "ReturnType" -> "Object"]}, WithCleanup[
		PARICall[session, "ellcard", curve], DeleteObject[curve]
	]], 8, TestID -> "elliptic-curve-object"
]

VerificationTest[
	PARIEvaluate[session, "x^2+1", "ReturnType" -> "String"], "x^2 + 1", TestID -> "explicit-string-result"
]

VerificationTest[
	Module[{object = PARIEvaluate[session, "x"], other = StartPARISession[]}, WithCleanup[
		MatchQ[PARICall[other, "type", object], Failure["PARIInvalidObject", _]],
		DeleteObject[object]; DeleteObject[other]
	]], True, TestID -> "objects-cannot-cross-sessions"
]

VerificationTest[
	Module[{object = PARIEvaluate[session, "x"]},
		DeleteObject[object]; MatchQ[PARICall[session, "type", object], Failure["PARIInvalidObject", _]]
	], True, TestID -> "released-object-is-invalid"
]

VerificationTest[
	Module[{other = StartPARISession[], object},
		object = PARIEvaluate[other, "x"]; DeleteObject[other];
		{other["Status"], MatchQ[Normal[object], Failure["PARIInvalidObject", _]], DeleteObject[other]}
	], {"Closed", True, Null}, TestID -> "closing-invalidates-objects-and-is-idempotent"
]

VerificationTest[
	Module[{other = StartPARISession[], result}, WithCleanup[
		result = PARIEvaluate[other, "while(1,)", TimeConstraint -> 0.1];
		{MatchQ[result, Failure["PARITimeout", _]], other["Status"], MatchQ[PARIEvaluate[other, "1"], Failure["PARIInvalidSession", _]]},
		DeleteObject[other]
	]], {True, "Stopped", True}, TestID -> "timeout-stops-session"
]

VerificationTest[
	Module[{other = StartPARISession[], aborted}, WithCleanup[
		aborted = CheckAbort[TimeConstrained[PARIEvaluate[other, "while(1,)", TimeConstraint -> Infinity], 0.2, Abort[]], True];
		{aborted, other["Status"]}, DeleteObject[other]
	]], {True, "Stopped"}, TestID -> "interrupted-request-stops-session"
]

VerificationTest[
	Module[{other = StartPARISession[], result}, WithCleanup[
		result = PARIEvaluate[other, "my(s=strchr(vector(1024,i,65)));for(i=1,17000,print1(s));0", "Output" -> "Discard"];
		{If[FailureQ[result], First[result], result], other["Status"]}, DeleteObject[other]
	]], {"PARIOutputLimit", "Stopped"}, TestID -> "excessive-output-stops-session"
]

VerificationTest[
	Module[{other = StartPARISession[], result}, WithCleanup[
		result = PARIEvaluate[other, "quit()"];
		{MatchQ[result, Failure["PARIProcessStopped", _]], other["Status"]}, DeleteObject[other]
	]], {True, "Stopped"}, TestID -> "process-exit-stops-session"
]

VerificationTest[
	Module[{other = StartPARISession[], result}, WithCleanup[
		result = PARIEvaluate[other, "parilinkencode(x,depth=0,references=1)=\"[1,2]\";1"];
		{MatchQ[result, Failure["PARIProtocolError", _]], other["Status"]}, DeleteObject[other]
	]], {True, "Stopped"}, TestID -> "malformed-response-stops-session"
]

DeleteObject[session];
