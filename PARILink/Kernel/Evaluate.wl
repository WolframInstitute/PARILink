(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{PARICall, PARIEvaluate}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{pariOutput}];

(* ::Section:: *)
(*Usage Messages*)

PARICall::usage = "PARICall[session, name, args] calls the GP function with the given name on the arguments args and gives its value. The \
arguments are sent as data, not as GP source code.\n\
The options are those of PARIEvaluate.";
PARIEvaluate::usage = "PARIEvaluate[session, code] evaluates GP source code, a string, in a PARI session and gives the value of its last \
expression.\n\
The options are TimeConstraint -> 30, in seconds or Infinity, \"ReturnType\" -> Automatic (or \"Object\", \"String\") and \"Output\" -> \
\"Print\" (or \"Capture\", \"Discard\"). Automatic copies a value that has an exact Wolfram Language form and keeps any other value in GP as a \
PARIObject.";
pariOutput::usage = "pariOutput[response, output] gives the result of a request in the output mode. response is what pariRequest gave. \
\"Discard\" gives the result. \"Print\" writes what GP printed and gives the result. \"Capture\" gives the response with its \"Result\", \
\"StandardOutput\" and \"StandardError\"; a Failure gets the two outputs as fields. A Failure in place of the response is passed on.";

(* ::Section:: *)
(*Function Definitions*)

(* A call and an evaluation share one path: a call writes its arguments as GP source and evaluates that. *)

Options[PARIEvaluate] = {TimeConstraint -> 30, "ReturnType" -> Automatic, "Output" -> "Print"};
Options[PARICall] = Options[PARIEvaluate];

pariOutput[failure_Failure, _String] := failure
pariOutput[response_Association, "Discard"] := response["Result"]
pariOutput[response_Association, "Capture"] :=
	Replace[
		response["Result"],
		{
			Failure[tag_, data_Association] :> Failure[tag, Join[data, KeyDrop[response, "Result"]]],
			_ :> response
		}
	]
pariOutput[response_Association, "Print"] := (
	If[response["StandardOutput"] =!= "", WriteString[$Output, response["StandardOutput"]]];
	If[response["StandardError"] =!= "", WriteString[$Messages, response["StandardError"]]];
	response["Result"]
)

PARIEvaluate[session_PARISession, code_String, opts : OptionsPattern[]] :=
	Enclose[
		Module[{timeConstraint, returnType, output},
			Confirm[pariCheckOptions[PARIEvaluate, {opts}]];
			timeConstraint = OptionValue[TimeConstraint];
			returnType = OptionValue["ReturnType"];
			output = OptionValue["Output"];
			Which[
				!pariTimeConstraintQ[timeConstraint],
					pariFailure["PARIInvalidOption", "TimeConstraint must be positive or Infinity."],
				!MemberQ[{Automatic, "Object", "String"}, returnType],
					pariFailure["PARIInvalidOption", "ReturnType must be Automatic, Object, or String."],
				!MemberQ[{"Print", "Capture", "Discard"}, output],
					pariFailure["PARIInvalidOption", "Output must be Print, Capture, or Discard."],
				StringContainsQ[code, FromCharacterCode[0]],
					pariFailure["PARIUnsupportedValue", "GP source code cannot contain a null character."],
				True,
					pariOutput[pariRequest[session, code, Replace[returnType, Automatic -> "Automatic"], timeConstraint], output]
			]
		],
		innerFailure
	]
PARIEvaluate[___] := invalidArgumentsFailure[PARIEvaluate]

(* Only a GP identifier is taken as a function name, so that a name cannot carry GP source code. *)
PARICall[session_PARISession, name_String, arguments : Longest[Except[_Rule | _RuleDelayed]...], opts : OptionsPattern[]] :=
	If[StringMatchQ[name, RegularExpression["[A-Za-z][A-Za-z0-9_]*"]],
		Enclose[
			Module[{encodedArguments},
				encodedArguments = Map[Confirm[pariEncode[session, #]] &, {arguments}];
				PARIEvaluate[session, name <> "(" <> StringRiffle[encodedArguments, ","] <> ")", opts]
			],
			innerFailure
		],
		pariFailure["PARIInvalidFunction", "Use a GP function name. Use PARIEvaluate for GP source code."]
	]
PARICall[___] := invalidArgumentsFailure[PARICall]
