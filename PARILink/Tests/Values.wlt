(* Tests for Kernel/Internal/Values.wl: the GP source of a value that is sent, the value of a node that is received,
   and the checks of options and time limits. They need no GP. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`PARILink`"]

encode = WolframInstitute`PARILink`PackageScope`pariEncode;
decode = WolframInstitute`PARILink`PackageScope`pariDecode;
checkOptions = WolframInstitute`PARILink`PackageScope`pariCheckOptions;
timeConstraintQ = WolframInstitute`PARILink`PackageScope`pariTimeConstraintQ;

unknownSession = PARISession["unavailable"];

(* Text outside ASCII and the characters that a GP string would need to escape. *)
unicodeText = "\[EAcute]\[Alpha]" <> FromCharacterCode[128512] <> "\n\"\\";

(* The tag of a Failure, or the value itself. *)
failureTag[Failure[tag_, _]] := tag
failureTag[value_] := value

VerificationTest[
	Map[
		failureTag[encode[unknownSession, #]] &,
		{1.5, Pi, <|"a" -> 1|>, "a" <> FromCharacterCode[0] <> "b"}
	],
	ConstantArray["PARIUnsupportedValue", 4],
	TestID -> "unsupported-inputs-are-explicit"
]

VerificationTest[
	encode[unknownSession, Pi],
	Failure["PARIUnsupportedValue", <|"MessageTemplate" -> "This value cannot be sent to PARI/GP.", "Head" -> Symbol|>],
	TestID -> "unsupported-input-names-its-head"
]

VerificationTest[
	failureTag[encode[unknownSession, {1, {2, 1.5}}]],
	"PARIUnsupportedValue",
	TestID -> "nested-unsupported-input-propagates"
]

VerificationTest[
	encode[unknownSession, 10 ^ 100 + 7],
	IntegerString[10 ^ 100 + 7],
	TestID -> "large-integers-stay-exact"
]

VerificationTest[
	{encode[unknownSession, -123], encode[unknownSession, -2 / 7]},
	{"-123", "(-2/7)"},
	TestID -> "negative-arguments-keep-their-sign"
]

VerificationTest[
	{
		encode[unknownSession, True],
		encode[unknownSession, False],
		encode[unknownSession, "ab"],
		encode[unknownSession, 1 / 3 - 2 I],
		encode[unknownSession, {1, {2 / 3, "a"}, {}}]
	},
	{"1", "0", "strchr([97,98])", "((1/3)+I*-2)", "[1,[(2/3),strchr([97])],[]]"},
	TestID -> "exact-values-become-gp-source"
]

VerificationTest[
	failureTag[encode[unknownSession, PARIObject["unavailable"]]],
	"PARIInvalidObject",
	TestID -> "an-object-that-is-not-live-is-not-sent"
]

VerificationTest[
	decode[unknownSession, {"v", {{"i", "123456789012345678901234567890"}, {"q", "-2", "7"}, {"c", {"i", "1"}, {"q", "1", "3"}}}}],
	{123456789012345678901234567890, -2 / 7, 1 + I / 3},
	TestID -> "decode-exact-values"
]

VerificationTest[
	decode[unknownSession, {"s", ToCharacterCode[unicodeText, "UTF-8"]}],
	unicodeText,
	TestID -> "decode-unicode-text"
]

VerificationTest[
	Map[
		failureTag[decode[unknownSession, #]] &,
		{
			{"i", "1+1"}, {"q", "1", "0"}, {"s", {256}}, {"s", {255}}, {"v", {{"bad"}}},
			{"o", 1, "not-a-type"}, {"o", 0, "t_POL"}, {"c", {"s", {}}, {"i", "1"}}, {"unknown"}
		}
	],
	ConstantArray["PARIProtocolError", 9],
	TestID -> "malformed-protocol-values-are-rejected"
]

VerificationTest[
	{
		decode[unknownSession, {"s", {256}}],
		decode[unknownSession, {"s", {255}}]
	},
	{
		Failure["PARIProtocolError", <|"MessageTemplate" -> "PARI/GP returned invalid text bytes."|>],
		Failure["PARIProtocolError", <|"MessageTemplate" -> "PARI/GP returned invalid UTF-8 text."|>]
	},
	TestID -> "invalid-text-says-what-is-wrong"
]

VerificationTest[
	failureTag[decode[unknownSession, {"u"}]],
	"PARIUnsupportedValue",
	TestID -> "a-value-that-cannot-be-copied-is-a-failure"
]

(* A value that GP keeps arrives as its number and its type, and becomes an object of the session. *)
VerificationTest[
	Module[{object},
		object = decode[unknownSession, {"o", 7, "t_POL"}];
		{MatchQ[object, PARIObject[_String]], MatchQ[ToBoxes[object], InterpretationBox[RowBox[{"PARIObject", "[", "\"t_POL\"", "]"}], _]]}
	],
	{True, True},
	TestID -> "a-kept-value-becomes-an-object"
]

VerificationTest[
	{
		decode[unknownSession, Nest[{"v", {#}} &, {"i", "1"}, 64]] === Nest[List, 1, 64],
		failureTag[decode[unknownSession, Nest[{"v", {#}} &, {"i", "1"}, 66]]]
	},
	{True, "PARIProtocolError"},
	TestID -> "decoder-depth-is-bounded"
]

VerificationTest[
	{
		checkOptions[PARIEvaluate, {"Output" -> "Capture", TimeConstraint -> 5}],
		checkOptions[PARIEvaluate, {"TimeConstraint" -> 5}],
		checkOptions[StartPARISession, {{"Executable" -> "gp"}}],
		checkOptions[PARIEvaluate, {"Typo" -> 1, "Output" -> "Print", "Other" -> 2}]
	},
	{
		Null,
		Null,
		Null,
		Failure["PARIInvalidOption", <|"MessageTemplate" -> "Unknown option names.", "Options" -> {"Other", "Typo"}|>]
	},
	TestID -> "unknown-option-names-are-listed"
]

VerificationTest[
	Map[timeConstraintQ, {Infinity, 30, 1 / 2, 0.1, 0, -1, 1 + I, "30", -Infinity}],
	{True, True, True, True, False, False, False, False, False},
	TestID -> "time-constraint-is-positive-or-infinite"
]

VerificationTest[
	{timeConstraintQ[], timeConstraintQ[1, 2]},
	{False, False},
	TestID -> "time-constraint-predicate-is-false-for-other-arguments"
]
