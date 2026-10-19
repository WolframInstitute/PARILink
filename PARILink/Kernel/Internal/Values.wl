(* Exact values cross the link; other values retain their PARI identity. *)

PackageScoped[pariFailure]
PackageScoped[pariString]
PackageScoped[pariEncode]
PackageScoped[pariDecode]
PackageScoped[pariTimeQ]
PackageScoped[pariCheckOptions]
PackageScoped[pariEnclose]

pariFailure[tag_String, message_String, data_ : <||>] :=
	Failure[tag, Join[<|"MessageTemplate" -> message|>, data]]

(* Keep the original API failure when Confirm unwinds a nested conversion. *)
SetAttributes[pariEnclose, HoldAll]
pariEnclose[expression_] := Enclose[expression,
	Function[failure, SelectFirst[{failure["Information"], failure["Expression"]}, FailureQ, failure]]
]

pariTimeQ[value_] := value === Infinity || (MatchQ[value, _Integer | _Rational | _Real] && TrueQ[value > 0])

pariCheckOptions[function_, options_List] := With[{keys = First /@ Options[function]},
	{unknown = Complement[First /@ Flatten[options], Join[keys, SymbolName /@ Cases[keys, _Symbol]]]},
	If[unknown === {}, Null,
		pariFailure["PARIInvalidOption", "Unknown option names.", <|"Options" -> unknown|>]
	]
]

(* Byte literals avoid GP string escapes, source injection, and locale-dependent text. *)
pariString[text_String] := "strchr([" <> StringRiffle[IntegerString /@ ToCharacterCode[text, "UTF-8"], ","] <> "])"

pariIntegerString[value_Integer] := If[value < 0, "-", ""] <> IntegerString[Abs[value]]

pariEncode[_, value_Integer] := pariIntegerString[value]
pariEncode[_, value_Rational] := "(" <> pariIntegerString[Numerator[value]] <> "/" <> IntegerString[Denominator[value]] <> ")"
pariEncode[_, True] := "1"
pariEncode[_, False] := "0"
pariEncode[_, value_String] := If[StringContainsQ[value, FromCharacterCode[0]],
	pariFailure["PARIUnsupportedValue", "PARI/GP strings cannot contain a null character."],
	pariString[value]
]
pariEncode[session_, value_Complex] := pariEnclose @ With[{
	real = Confirm @ pariEncode[session, Re[value]], imaginary = Confirm @ pariEncode[session, Im[value]]
}, "(" <> real <> "+I*" <> imaginary <> ")"]
pariEncode[session_, values_List] := pariEnclose @ With[{parts = Confirm[pariEncode[session, #]] & /@ values},
	"[" <> StringRiffle[parts, ","] <> "]"
]
pariEncode[session_, object_PARIObject] := pariObjectArgument[session, object]
pariEncode[_, value_] := pariFailure["PARIUnsupportedValue", "This value cannot be sent to PARI/GP.", <|"Head" -> Head[value]|>]

pariInteger[text_String] := If[StringMatchQ[text, RegularExpression["-?(0|[1-9][0-9]*)"]],
	If[StringStartsQ[text, "-"], -FromDigits[StringDrop[text, 1]], FromDigits[text]],
	pariFailure["PARIProtocolError", "PARI/GP returned an invalid integer."]
]

pariDecode[session_, value_, depth_ : 0] := If[depth <= 64,
	pariDecodeNode[session, value, depth],
	pariFailure["PARIProtocolError", "PARI/GP returned a value nested too deeply."]
]

pariDecodeNode[_, {"i", text_String}, _] := pariInteger[text]
pariDecodeNode[_, {"q", numerator_String, denominator_String}, _] := pariEnclose @ With[{
	n = Confirm @ pariInteger[numerator], d = Confirm @ pariInteger[denominator]
}, If[d > 0, n/d, pariFailure["PARIProtocolError", "PARI/GP returned an invalid fraction."]]]
pariDecodeNode[session_, {"c", real_, imaginary_}, depth_] := pariEnclose @ With[{
	a = Confirm @ pariDecode[session, real, depth + 1], b = Confirm @ pariDecode[session, imaginary, depth + 1]
}, If[MatchQ[{a, b}, {(_Integer | _Rational), (_Integer | _Rational)}],
	a + I b, pariFailure["PARIProtocolError", "PARI/GP returned an invalid exact complex number."]
]]
pariDecodeNode[_, {"s", bytes : {___Integer}}, _] := pariEnclose @ With[{
	valid = ConfirmBy[bytes, AllTrue[#, 0 <= # <= 255 &] &,
		pariFailure["PARIProtocolError", "PARI/GP returned invalid text bytes."]],
	text = Quiet @ Check[FromCharacterCode[bytes, "UTF-8"], $Failed]
}, If[StringQ[text] && ToCharacterCode[text, "UTF-8"] === valid,
	text, pariFailure["PARIProtocolError", "PARI/GP returned invalid UTF-8 text."]
]]
pariDecodeNode[session_, {"v", values_List}, depth_] := pariEnclose @ Map[
	Confirm[pariDecode[session, #, depth + 1]] &, values
]
pariDecodeNode[session_, {"o", id_Integer?Positive, type_String}, _] := If[
	StringMatchQ[type, RegularExpression["t_[A-Z]+"]],
	pariCreateObject[session, id, type],
	pariFailure["PARIProtocolError", "PARI/GP returned an invalid object type."]
]
pariDecodeNode[_, {"u"}, _] := pariFailure["PARIUnsupportedValue", "This PARI value has no lossless Wolfram Language representation."]
pariDecodeNode[_, _, _] := pariFailure["PARIProtocolError", "PARI/GP returned an invalid value."]
