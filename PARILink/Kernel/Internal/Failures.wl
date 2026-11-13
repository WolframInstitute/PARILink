(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{invalidArgumentsFailure, innerFailure, pariFailure}];

(* ::Section:: *)
(*Usage Messages*)

invalidArgumentsFailure::usage = "invalidArgumentsFailure[function] issues the message function::args and gives the Failure that a public \
function returns for arguments that match none of its definitions. The Failure has the tag \"InvalidArguments\".";
innerFailure::usage = "innerFailure[failure] gives the Failure that a failed confirmation stands for: the Failure given as the last argument of \
the confirmation, or else the confirmed expression when it is a Failure, or else failure itself. Used as the second argument of Enclose, it \
keeps the tag and the data of a Failure that a helper made.";
pariFailure::usage = "pariFailure[tag, message] gives a Failure with the tag and the message.\n\
pariFailure[tag, message, data] adds the fields of the association data, such as \"Path\" or \"Status\".";

(* ::Section:: *)
(*Function Definitions*)

(* Every public function ends with Name[___] := invalidArgumentsFailure[Name]. The message is the generic one
   every symbol inherits (General::args), so no file defines its own. *)
invalidArgumentsFailure[function_Symbol] := (
	Message[MessageName[function, "args"], function];
	Failure["InvalidArguments", <|"MessageTemplate" -> MessageName[function, "args"], "MessageParameters" -> {function}|>]
)

(* Enclose[body, innerFailure] returns the Failure that PARILink made, such as one with the tag "PARIInvalidSession",
   in place of a "ConfirmationFailed" Failure around it. *)
innerFailure[failure_Failure] := SelectFirst[{failure["Information"], failure["Expression"]}, FailureQ, failure]

pariFailure[tag_String, message_String, data_Association] := Failure[tag, Join[<|"MessageTemplate" -> message|>, data]]
pariFailure[tag_String, message_String] := pariFailure[tag, message, <||>]
