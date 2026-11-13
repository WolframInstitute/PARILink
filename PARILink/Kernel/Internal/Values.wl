(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{pariString, pariEncode, pariDecode, pariTimeConstraintQ, pariCheckOptions}];

(* ::Section:: *)
(*Usage Messages*)

pariString::usage = "pariString[text] gives GP source for the string text: a call of strchr on the UTF-8 bytes of text.";
pariEncode::usage = "pariEncode[session, value] gives GP source for a value that is sent to the session, or a Failure. An integer, a rational, \
True, False, a string, an exact complex number and a list of such values are sent as they are. A PARIObject of the session is sent as a reference \
to the value that GP keeps. Any other value gives a Failure with the tag \"PARIUnsupportedValue\".";
pariDecode::usage = "pariDecode[session, node] gives the value that a node of a response from GP stands for, or a Failure. A node is a list that \
starts with its kind: {\"i\", digits} for an integer, {\"q\", numerator, denominator} for a fraction, {\"c\", real, imaginary} for an exact \
complex number, {\"s\", bytes} for text, {\"v\", nodes} for a vector, {\"o\", number, type} for a value that GP keeps, which becomes a PARIObject \
of the session, and {\"u\"} for a value that cannot be copied.\n\
pariDecode[session, node, depth] reads a node that lies depth vectors deep, and gives a Failure beyond depth 64.";
pariTimeConstraintQ::usage = "pariTimeConstraintQ[value] gives True when value is Infinity or a positive integer, rational or real number.";
pariCheckOptions::usage = "pariCheckOptions[function, options] gives Null when every name in the list of option rules is an option of function, \
and otherwise a Failure with the tag \"PARIInvalidOption\" that lists the other names. A symbol option may be named by its string.";
pariIntegerString::usage = "pariIntegerString[value] gives the decimal digits of an integer, with a minus sign when it is negative.";
pariInteger::usage = "pariInteger[digits] gives the integer that the string digits holds, or a Failure when it is not a decimal integer without \
leading zeros.";
pariByteListQ::usage = "pariByteListQ[values] gives True when values is a list of integers from 0 to 255.";
pariUTF8Text::usage = "pariUTF8Text[bytes] gives the string that the list of bytes holds as UTF-8, or None when the bytes are not valid UTF-8.";
pariDecodeNode::usage = "pariDecodeNode[session, node, depth] gives the value of a node at the given depth, or a Failure. A node of a form that \
is not known gives a Failure with the tag \"PARIProtocolError\".";

(* ::Section:: *)
(*Function Definitions*)

(* Exact values cross the link as text and are read with FromDigits and FromCharacterCode, never as Wolfram Language
   code. A value without an exact Wolfram Language form stays in GP and arrives as a reference. *)

pariTimeConstraintQ[Infinity] := True
pariTimeConstraintQ[value : (_Integer | _Rational | _Real)] := TrueQ[value > 0]
pariTimeConstraintQ[___] := False

(* OptionValue takes the string name of a symbol option, so that name is accepted here too. *)
pariCheckOptions[function_Symbol, options_List] :=
	Module[{optionNames, unknownNames},
		optionNames = Keys[Options[function]];
		unknownNames = Complement[Keys[Flatten[options]], Join[optionNames, SymbolName /@ Cases[optionNames, _Symbol]]];
		If[unknownNames === {}, Null, pariFailure["PARIInvalidOption", "Unknown option names.", <|"Options" -> unknownNames|>]]
	]

(* Bytes in place of a quoted string keep GP's string escapes, code inside the text and the locale out of a request. *)
pariString[text_String] := "strchr([" <> StringRiffle[IntegerString /@ ToCharacterCode[text, "UTF-8"], ","] <> "])"

pariIntegerString[value_Integer] := If[value < 0, "-", ""] <> IntegerString[Abs[value]]

pariEncode[_PARISession, value_Integer] := pariIntegerString[value]
pariEncode[_PARISession, value_Rational] := "(" <> pariIntegerString[Numerator[value]] <> "/" <> IntegerString[Denominator[value]] <> ")"
pariEncode[_PARISession, True] := "1"
pariEncode[_PARISession, False] := "0"
pariEncode[_PARISession, text_String] :=
	If[StringContainsQ[text, FromCharacterCode[0]],
		pariFailure["PARIUnsupportedValue", "PARI/GP strings cannot contain a null character."],
		pariString[text]
	]
pariEncode[session_PARISession, value_Complex] :=
	Enclose[
		Module[{realPart, imaginaryPart},
			realPart = Confirm[pariEncode[session, Re[value]]];
			imaginaryPart = Confirm[pariEncode[session, Im[value]]];
			"(" <> realPart <> "+I*" <> imaginaryPart <> ")"
		],
		innerFailure
	]
pariEncode[session_PARISession, values_List] :=
	Enclose[
		Module[{encodedValues},
			encodedValues = Map[Confirm[pariEncode[session, #]] &, values];
			"[" <> StringRiffle[encodedValues, ","] <> "]"
		],
		innerFailure
	]
pariEncode[session_PARISession, object_PARIObject] := pariObjectArgument[session, object]
pariEncode[_PARISession, value_] := pariFailure["PARIUnsupportedValue", "This value cannot be sent to PARI/GP.", <|"Head" -> Head[value]|>]

pariInteger[digits_String] :=
	If[StringMatchQ[digits, RegularExpression["-?(0|[1-9][0-9]*)"]],
		If[StringStartsQ[digits, "-"], -FromDigits[StringDrop[digits, 1]], FromDigits[digits]],
		pariFailure["PARIProtocolError", "PARI/GP returned an invalid integer."]
	]

pariByteListQ[{}] := True
pariByteListQ[values : {__Integer}] := 0 <= Min[values] && Max[values] <= 255
pariByteListQ[___] := False

(* The bytes of a GP string need not be UTF-8. Text that does not give the same bytes back is not valid. *)
pariUTF8Text[bytes : {___Integer}] :=
	Module[{text},
		text = Quiet[Check[FromCharacterCode[bytes, "UTF-8"], None], {$CharacterEncoding::utf8}];
		If[StringQ[text] && ToCharacterCode[text, "UTF-8"] === bytes, text, None]
	]

(* allow BarePattern: node is any value that the JSON of a response can hold *)
pariDecode[session_PARISession, node_, depth_Integer] :=
	If[depth <= 64,
		pariDecodeNode[session, node, depth],
		pariFailure["PARIProtocolError", "PARI/GP returned a value nested too deeply."]
	]
(* allow BarePattern: node is any value that the JSON of a response can hold *)
pariDecode[session_PARISession, node_] := pariDecode[session, node, 0]

pariDecodeNode[_PARISession, {"i", digits_String}, _Integer] := pariInteger[digits]
pariDecodeNode[_PARISession, {"q", numeratorDigits_String, denominatorDigits_String}, _Integer] :=
	Enclose[
		Module[{numerator, denominator},
			numerator = Confirm[pariInteger[numeratorDigits]];
			denominator = Confirm[pariInteger[denominatorDigits]];
			If[denominator > 0, numerator / denominator, pariFailure["PARIProtocolError", "PARI/GP returned an invalid fraction."]]
		],
		innerFailure
	]
pariDecodeNode[session_PARISession, {"c", realNode_, imaginaryNode_}, depth_Integer] :=
	Enclose[
		Module[{realPart, imaginaryPart},
			realPart = Confirm[pariDecode[session, realNode, depth + 1]];
			imaginaryPart = Confirm[pariDecode[session, imaginaryNode, depth + 1]];
			If[MatchQ[{realPart, imaginaryPart}, {(_Integer | _Rational), (_Integer | _Rational)}],
				realPart + I * imaginaryPart,
				pariFailure["PARIProtocolError", "PARI/GP returned an invalid exact complex number."]
			]
		],
		innerFailure
	]
pariDecodeNode[_PARISession, {"s", bytes : {___Integer}}, _Integer] :=
	If[pariByteListQ[bytes],
		Replace[pariUTF8Text[bytes], None :> pariFailure["PARIProtocolError", "PARI/GP returned invalid UTF-8 text."]],
		pariFailure["PARIProtocolError", "PARI/GP returned invalid text bytes."]
	]
pariDecodeNode[session_PARISession, {"v", nodes_List}, depth_Integer] :=
	Enclose[Map[Confirm[pariDecode[session, #, depth + 1]] &, nodes], innerFailure]
pariDecodeNode[session_PARISession, {"o", objectID_Integer?Positive, type_String}, _Integer] :=
	If[StringMatchQ[type, RegularExpression["t_[A-Z]+"]],
		pariCreateObject[session, objectID, type],
		pariFailure["PARIProtocolError", "PARI/GP returned an invalid object type."]
	]
pariDecodeNode[_PARISession, {"u"}, _Integer] :=
	pariFailure["PARIUnsupportedValue", "This PARI value has no lossless Wolfram Language representation."]
pariDecodeNode[_PARISession, _, _Integer] := pariFailure["PARIProtocolError", "PARI/GP returned an invalid value."]
