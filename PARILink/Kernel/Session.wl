(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{StartPARISession, PARISession}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{$pariSessions, pariSessionData, pariCloseSession, pariRequest}];

(* ::Section:: *)
(*Usage Messages*)

StartPARISession::usage = "StartPARISession[] starts PARI/GP and gives a PARISession, or a Failure when GP cannot be found or started.\n\
StartPARISession[\"Executable\" -> path] uses the GP program at path.\n\
The option \"Executable\" -> Automatic uses the program that PARILINK_GP names, then the GP in the paclet, then a GP on PATH. \"StackLimit\" -> \
256 * 1024^2 is the largest stack of GP in bytes, and TimeConstraint -> 30 limits the start, in seconds.";
PARISession::usage = "PARISession[...] represents a PARI/GP session. StartPARISession creates it, and it stays as it is: it is the handle of the \
session.\n\
session[\"property\"] gives a session property. session[\"Properties\"] lists the properties.\n\
DeleteObject[session] closes the session.";
$pariSessions::usage = "$pariSessions holds the state of every session of this kernel, by session ID: its \"Status\", and its \"Process\", \
\"Executable\" and \"Version\" where known.";
pariSessionData::usage = "pariSessionData[session] gives the state of a session, an association, or a Failure with the tag \
\"PARIInvalidSession\" when the session is not known. A session whose GP has ended is marked as stopped first.";
pariCloseSession::usage = "pariCloseSession[session, status] ends the GP of a session, stores status, which is \"Stopped\" or \"Closed\", as its \
status, forgets its objects and gives Null. A session that is not known is left alone.";
pariRequest::usage = "pariRequest[session, code, mode, timeConstraint] has the GP of a session that is ready evaluate the string code, and gives \
an association with the \"Result\", which is a value or a Failure, and the \"StandardOutput\" and \"StandardError\" that GP wrote. mode is \
\"Automatic\", \"Object\", \"String\" or \"Copy\". When the session is not ready or the request itself fails it gives a Failure. A request that \
ends without a valid response stops the session.";
$pariSessionProperties::usage = "$pariSessionProperties lists the names of the properties of a session.";
pariRegisterSession::usage = "pariRegisterSession[process, executable] records a started GP process as a session that is ready and gives its \
PARISession.";
pariSupportedVersionQ::usage = "pariSupportedVersionQ[version] gives True when version is a list {major, minor, patch} for PARI/GP 2.17 or later.";
pariAcceptedSession::usage = "pariAcceptedSession[session, version] gives the session with its version recorded when version, the value that GP \
gave for version(), is one that PARILink supports. Otherwise it stops the session and gives a Failure.";
pariErrorResult::usage = "pariErrorResult[session, kindNode, messageNode] gives the Failure with the tag \"PARIError\" for an error that GP \
reported, from the nodes that hold its name and its text.";
pariPayloadResult::usage = "pariPayloadResult[session, payload] gives the value or the Failure that the payload of a response holds.";
pariRequestResult::usage = "pariRequestResult[session, response] gives the association that pariRequest gives for a response of GP, and stops \
the session when the response is not valid or GP abandoned the request.";
pariSessionProperty::usage = "pariSessionProperty[session, property] gives the value of a property of a session, the Failure for a session that \
is not known, or Missing[\"UnknownProperty\", property] for a name that is not a property.";
pariDeleteSession::usage = "pariDeleteSession[session] closes a session and gives Null, also when it was closed before. A session that is not \
known gives a Failure.";
pariSessionStatusBox::usage = "pariSessionStatusBox[sessionID, form] gives the boxes of the stored status of a session, or of \"Unavailable\", \
in the given form.";

(* ::Section:: *)
(*Function Definitions*)

(* A session owns one GP process and every value that GP keeps for it. Only one request runs at a time. A request
   that times out, is aborted or gets a response that is not valid stops the session, because a late response could
   be read as the answer to the next request. *)

$pariSessions = <||>;
$pariSessionProperties = {"Status", "Version", "Executable", "Properties"};

Options[StartPARISession] = {"Executable" -> Automatic, "StackLimit" -> 256 * 1024 ^ 2, TimeConstraint -> 30};

pariRegisterSession[process_ProcessObject, executable_String] :=
	Module[{sessionID},
		sessionID = CreateUUID[];
		AssociateTo[$pariSessions, sessionID -> <|"Process" -> process, "Executable" -> executable, "Status" -> "Ready"|>];
		PARISession[sessionID]
	]

pariSupportedVersionQ[version : {_Integer, _Integer, _Integer}] := OrderedQ[{{2, 17, 0}, version}]
pariSupportedVersionQ[___] := False

(* allow BarePattern: version is whatever GP gave for version(), or the Failure of that request *)
pariAcceptedSession[session : PARISession[sessionID_String], version_] :=
	If[pariSupportedVersionQ[version],
		AssociateTo[$pariSessions, sessionID -> Append[$pariSessions[sessionID], "Version" -> StringRiffle[IntegerString /@ version, "."]]];
		session,

		pariCloseSession[session, "Stopped"];
		If[FailureQ[version], version, pariFailure["PARIUnsupportedVersion", "PARILink requires PARI/GP 2.17 or newer.", <|"Version" -> version|>]]
	]

StartPARISession[opts : OptionsPattern[]] :=
	Enclose[
		Module[{timeConstraint, stackLimit, executable, process, session, version},
			Confirm[pariCheckOptions[StartPARISession, {opts}]];
			timeConstraint = OptionValue[TimeConstraint];
			ConfirmBy[timeConstraint, pariTimeConstraintQ, pariFailure["PARIInvalidOption", "TimeConstraint must be positive or Infinity."]];
			stackLimit = OptionValue["StackLimit"];
			ConfirmAssert[
				IntegerQ[stackLimit] && stackLimit >= 8 * 1024 ^ 2,
				pariFailure["PARIInvalidOption", "StackLimit must be an integer of at least 8 MiB, in bytes."]
			];
			executable = Confirm[pariFindExecutable[OptionValue["Executable"]]];
			process = Confirm[pariStartProcess[executable, stackLimit]];
			session = pariRegisterSession[process, executable];
			version = CheckAbort[
				pariOutput[pariRequest[session, "version()", "Automatic", timeConstraint], "Discard"],
				pariCloseSession[session, "Stopped"];
				Abort[]
			];
			pariAcceptedSession[session, version]
		],
		innerFailure
	]
StartPARISession[___] := invalidArgumentsFailure[StartPARISession]

pariSessionData[session : PARISession[sessionID_String]] :=
	Module[{state},
		state = Lookup[$pariSessions, sessionID, None];
		Which[
			!AssociationQ[state],
				pariFailure["PARIInvalidSession", "This PARI session is not available in this kernel."],
			MemberQ[{"Ready", "Busy"}, state["Status"]] && ProcessStatus[state["Process"]] =!= "Running",
				pariCloseSession[session, "Stopped"];
				$pariSessions[sessionID],
			True,
				state
		]
	]
pariSessionData[_] := pariFailure["PARIInvalidSession", "This PARI session is not valid."]

pariCloseSession[session : PARISession[sessionID_String], status : ("Stopped" | "Closed")] :=
	Module[{state},
		state = Lookup[$pariSessions, sessionID, None];
		If[AssociationQ[state],
			If[MatchQ[Lookup[state, "Process", None], _ProcessObject], pariStopProcess[state["Process"]]];
			AssociateTo[$pariSessions, sessionID -> Append[KeyTake[state, {"Executable", "Version"}], "Status" -> status]];
			pariForgetObjects[session]
		];
		Null
	]

(* allow BarePattern: each node is any value that the JSON of a response can hold *)
pariErrorResult[session_PARISession, kindNode_, messageNode_] :=
	Enclose[
		Module[{errorName, errorText},
			errorName = Confirm[pariDecode[session, kindNode]];
			errorText = Confirm[pariDecode[session, messageNode]];
			If[StringQ[errorName] && StringQ[errorText],
				pariFailure["PARIError", "PARI/GP could not evaluate the expression.", <|"PARIError" -> errorName, "PARIMessage" -> errorText|>],
				pariFailure["PARIProtocolError", "PARI/GP returned an invalid error response."]
			]
		],
		innerFailure
	]

pariPayloadResult[session_PARISession, {"ok", node_}] := pariDecode[session, node]
pariPayloadResult[_PARISession, {"incomplete"}] :=
	pariFailure["PARIInterrupted", "GP ended the request without returning a result. The session was stopped."]
pariPayloadResult[session_PARISession, {"error", kindNode_, messageNode_}] := pariErrorResult[session, kindNode, messageNode]
pariPayloadResult[_PARISession, _] := pariFailure["PARIProtocolError", "PARI/GP returned an invalid response."]

pariRequestResult[session_PARISession, response_Association] :=
	Module[{result},
		result = pariPayloadResult[session, response["Payload"]];
		If[MatchQ[result, Failure["PARIProtocolError" | "PARIInterrupted", _]], pariCloseSession[session, "Stopped"]];
		<|"Result" -> result, "StandardOutput" -> response["StandardOutput"], "StandardError" -> response["StandardError"]|>
	]

pariRequest[session : PARISession[sessionID_String], code_String, mode_String, timeConstraint_?pariTimeConstraintQ] :=
	Enclose[
		Module[{state, response},
			state = Confirm[pariSessionData[session]];
			ConfirmAssert[
				state["Status"] === "Ready",
				pariFailure["PARIInvalidSession", "The PARI session is not ready.", <|"Status" -> state["Status"]|>]
			];
			AssociateTo[$pariSessions, sessionID -> Append[state, "Status" -> "Busy"]];
			response = CheckAbort[
				pariExchange[state["Process"], code, mode, timeConstraint],
				pariCloseSession[session, "Stopped"];
				Abort[]
			];
			If[FailureQ[response],
				pariCloseSession[session, "Stopped"];
				response,

				AssociateTo[$pariSessions, sessionID -> state];
				pariRequestResult[session, response]
			]
		],
		innerFailure
	]
(* A session whose form is not PARISession[id] gives the same Failure here as for its properties. *)
pariRequest[session_PARISession, _String, _String, _?pariTimeConstraintQ] := pariSessionData[session]

pariSessionProperty[_PARISession, "Properties"] := $pariSessionProperties
pariSessionProperty[session_PARISession, property : ("Status" | "Version" | "Executable")] :=
	Replace[pariSessionData[session], state_Association :> Lookup[state, property, Missing["UnknownProperty", property]]]
pariSessionProperty[_PARISession, property_String] := Missing["UnknownProperty", property]

(* PARISession[...] itself has no definition, because it is the handle of a session. Only a property request evaluates. *)
PARISession[sessionData___][property_String] := pariSessionProperty[PARISession[sessionData], property]
PARISession[___][___] := invalidArgumentsFailure[PARISession]

pariDeleteSession[session_PARISession] := Replace[pariSessionData[session], _Association :> pariCloseSession[session, "Closed"]]

PARISession /: DeleteObject[session_PARISession] := pariDeleteSession[session]

(* The stored status is shown as it is. Showing a session must not ask about its process or change its state. *)
pariSessionStatusBox[sessionID_String, form : (StandardForm | TraditionalForm)] :=
	ToBoxes[Lookup[Lookup[$pariSessions, sessionID, <||>], "Status", "Unavailable"], form]

(* With puts the computed box into InterpretationBox, which holds its arguments. *)
PARISession /: MakeBoxes[session : PARISession[sessionID_String], form : (StandardForm | TraditionalForm)] :=
	With[{statusBox = pariSessionStatusBox[sessionID, form]},
		InterpretationBox[RowBox[{"PARISession", "[", statusBox, "]"}], session]
	]
