(* Structured arguments and explicit code evaluation share one request path. *)

PackageExported[PARICall]
PackageExported[PARIEvaluate]
PackageScoped[pariOutput]

PARICall::usage = "PARICall[session, name, args] evaluates a named PARI/GP function with structured arguments."
PARIEvaluate::usage = "PARIEvaluate[session, code] evaluates GP source code in a PARI session."

Options[PARIEvaluate] = {TimeConstraint -> 30, "ReturnType" -> Automatic, "Output" -> "Print"}
Options[PARICall] = Options[PARIEvaluate]

pariOutput[result_?FailureQ, _] := result
pariOutput[response_Association, "Discard"] := response["Result"]
pariOutput[response_Association, "Capture"] := If[FailureQ[response["Result"]],
	Replace[response["Result"], Failure[tag_, data_] :> Failure[tag, Join[data, KeyDrop[response, "Result"]]]],
	response
]
pariOutput[response_Association, "Print"] := (
	If[response["StandardOutput"] =!= "", WriteString[$Output, response["StandardOutput"]]];
	If[response["StandardError"] =!= "", WriteString[$Messages, response["StandardError"]]];
	response["Result"]
)

PARIEvaluate[session_PARISession, code_String, opts : OptionsPattern[]] := pariEnclose @ Module[{time, mode, output},
	Confirm @ pariCheckOptions[PARIEvaluate, {opts}];
	{time, mode, output} = {OptionValue[TimeConstraint], OptionValue["ReturnType"], OptionValue["Output"]};
	Which[
		! pariTimeQ[time], pariFailure["PARIInvalidOption", "TimeConstraint must be positive or Infinity."],
		! MemberQ[{Automatic, "Object", "String"}, mode], pariFailure["PARIInvalidOption", "ReturnType must be Automatic, Object, or String."],
		! MemberQ[{"Print", "Capture", "Discard"}, output], pariFailure["PARIInvalidOption", "Output must be Print, Capture, or Discard."],
		StringContainsQ[code, FromCharacterCode[0]], pariFailure["PARIUnsupportedValue", "GP source code cannot contain a null character."],
		True, pariOutput[pariRequest[session, code, Replace[mode, Automatic -> "Automatic"], time], output]
	]
]

PARICall[session_PARISession, name_String, arguments : Longest[Except[_Rule | _RuleDelayed]...], opts : OptionsPattern[]] :=
	If[StringMatchQ[name, RegularExpression["[A-Za-z][A-Za-z0-9_]*"]],
		pariEnclose @ With[{parts = Confirm[pariEncode[session, #]] & /@ {arguments}},
			PARIEvaluate[session, name <> "(" <> StringRiffle[parts, ","] <> ")", opts]
		],
		pariFailure["PARIInvalidFunction", "Use a GP function name. Use PARIEvaluate for GP source code."]
	]
