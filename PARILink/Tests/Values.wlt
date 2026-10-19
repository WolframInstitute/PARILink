Needs["WolframInstitute`PARILink`"];

encode = WolframInstitute`PARILink`PackageScope`pariEncode;
decode = WolframInstitute`PARILink`PackageScope`pariDecode;
unknownSession = PARISession["unavailable"];

VerificationTest[
	Names["WolframInstitute`PARILink`*"],
	{"PARICall", "PARIEvaluate", "PARIObject", "PARISession", "StartPARISession"},
	TestID -> "public-api"
]

VerificationTest[
	Length[WolframInstitute`PARILink`PackageScope`$pariSessions], 0,
	TestID -> "loading-does-not-start-a-session"
]

VerificationTest[
	MatchQ[StartPARISession["Executable" -> FileNameJoin[{$TemporaryDirectory, CreateUUID[]}]], Failure["PARIExecutableNotFound", _]],
	True, TestID -> "missing-executable"
]

VerificationTest[
	And @@ (MatchQ[StartPARISession[#], Failure["PARIInvalidOption", _]] & /@
		{"Typo" -> 1, "Executable" -> 42, "StackLimit" -> 0, "StackLimit" -> 8 * 1024^2 - 1,
			"StackLimit" -> 1024.^3, "StackLimit" -> Infinity, TimeConstraint -> -1, TimeConstraint -> 1 + I}),
	True, TestID -> "start-option-validation"
]

VerificationTest[
	And @@ (MatchQ[PARIEvaluate[unknownSession, "1", #], Failure["PARIInvalidOption", _]] & /@
		{"Typo" -> 1, "ReturnType" -> "Invalid", "Output" -> "Invalid", TimeConstraint -> 0}),
	True, TestID -> "evaluation-option-validation"
]

VerificationTest[
	MatchQ[PARICall[unknownSession, "factor);quit(", 10], Failure["PARIInvalidFunction", _]],
	True, TestID -> "function-name-cannot-inject-code"
]

VerificationTest[
	And @@ (MatchQ[encode[unknownSession, #], Failure["PARIUnsupportedValue", _]] & /@
		{1.5, Pi, <|"a" -> 1|>, "a" <> FromCharacterCode[0] <> "b"}),
	True, TestID -> "unsupported-inputs-are-explicit"
]

VerificationTest[
	MatchQ[encode[unknownSession, {1, {2, 1.5}}], Failure["PARIUnsupportedValue", _]],
	True, TestID -> "nested-unsupported-input-propagates"
]

VerificationTest[
	encode[unknownSession, 10^100 + 7], IntegerString[10^100 + 7],
	TestID -> "large-integers-stay-exact"
]

VerificationTest[
	{encode[unknownSession, -123], encode[unknownSession, -2/7]}, {"-123", "(-2/7)"},
	TestID -> "negative-arguments-keep-their-sign"
]

VerificationTest[
	decode[unknownSession, {"v", {{"i", "123456789012345678901234567890"}, {"q", "-2", "7"}, {"c", {"i", "1"}, {"q", "1", "3"}}}}],
	{123456789012345678901234567890, -2/7, 1 + I/3}, TestID -> "decode-exact-values"
]

VerificationTest[
	decode[unknownSession, {"s", ToCharacterCode["éα😀\n\"\\", "UTF-8"]}], "éα😀\n\"\\",
	TestID -> "decode-unicode-text"
]

VerificationTest[
	And @@ (MatchQ[decode[unknownSession, #], Failure["PARIProtocolError", _]] & /@ {
		{"i", "1+1"}, {"q", "1", "0"}, {"s", {256}}, {"s", {255}}, {"v", {{"bad"}}},
		{"o", 1, "not-a-type"}, {"o", 0, "t_POL"}, {"c", {"s", {}}, {"i", "1"}}, {"unknown"}
	}), True, TestID -> "malformed-protocol-values-are-rejected"
]

VerificationTest[
	MatchQ[decode[unknownSession, Nest[{"v", {#}} &, {"i", "1"}, 66]], Failure["PARIProtocolError", _]],
	True, TestID -> "decoder-depth-is-bounded"
]

VerificationTest[
	MatchQ[PARIEvaluate[unknownSession, "1"], Failure["PARIInvalidSession", _]],
	True, TestID -> "unknown-session"
]

VerificationTest[
	MatchQ[Normal[PARIObject["unavailable"]], Failure["PARIInvalidObject", _]],
	True, TestID -> "unknown-object"
]

VerificationTest[
	MatchQ[PARIEvaluate[unknownSession, "1" <> FromCharacterCode[0]], Failure["PARIUnsupportedValue", _]],
	True, TestID -> "source-cannot-contain-null"
]
