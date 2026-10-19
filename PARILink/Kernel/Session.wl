(* Explicit sessions own processes and all retained PARI values. *)

PackageExported[StartPARISession]
PackageExported[PARISession]
PackageScoped[$pariSessions]
PackageScoped[pariSessionData]
PackageScoped[pariCloseSession]
PackageScoped[pariRequest]

StartPARISession::usage = "StartPARISession[] starts PARI/GP. StartPARISession[\"Executable\" -> path] uses the GP executable at path."
PARISession::usage = "PARISession[...] represents a PARI/GP session. session[\"property\"] gives a session property. DeleteObject[session] closes it."

$pariSessions = <||>

Options[StartPARISession] = {"Executable" -> Automatic, "StackLimit" -> 256 * 1024^2, TimeConstraint -> 30}

StartPARISession[opts : OptionsPattern[]] := pariEnclose @ Module[{executable, process, session, version, time, stackLimit},
	Confirm @ pariCheckOptions[StartPARISession, {opts}];
	time = OptionValue[TimeConstraint];
	ConfirmBy[time, pariTimeQ, pariFailure["PARIInvalidOption", "TimeConstraint must be positive or Infinity."]];
	stackLimit = OptionValue["StackLimit"];
	ConfirmAssert[IntegerQ[stackLimit] && stackLimit >= 8 * 1024^2,
		pariFailure["PARIInvalidOption", "StackLimit must be an integer of at least 8 MiB, in bytes."]];
	executable = Confirm @ pariFindExecutable[OptionValue["Executable"]];
	process = Confirm @ pariStartProcess[executable, stackLimit];
	session = PARISession[CreateUUID[]];
	AssociateTo[$pariSessions, First[session] -> <|"Process" -> process, "Executable" -> executable, "Status" -> "Ready"|>];
	version = CheckAbort[pariOutput[pariRequest[session, "version()", "Automatic", time], "Discard"],
		pariCloseSession[session, "Stopped"]; Abort[]];
	If[MatchQ[version, {_Integer, _Integer, _Integer}] && OrderedQ[{{2, 17, 0}, version}],
		AssociateTo[$pariSessions, First[session] -> Append[$pariSessions[First[session]], "Version" -> StringRiffle[IntegerString /@ version, "."]]];
		session,
		pariCloseSession[session, "Stopped"];
		If[FailureQ[version], version, pariFailure["PARIUnsupportedVersion", "PARILink requires PARI/GP 2.17 or newer.", <|"Version" -> version|>]]
	]
]

pariSessionData[session : PARISession[id_String]] := With[{state = Lookup[$pariSessions, id, None]},
	Which[
		! AssociationQ[state], pariFailure["PARIInvalidSession", "This PARI session is not available in this kernel."],
		MemberQ[{"Ready", "Busy"}, state["Status"]] && ProcessStatus[state["Process"]] =!= "Running",
			pariCloseSession[session, "Stopped"]; $pariSessions[id],
		True, state
	]
]
pariSessionData[_] := pariFailure["PARIInvalidSession", "This PARI session is not valid."]

pariCloseSession[session : PARISession[id_String], status_String] := With[{state = Lookup[$pariSessions, id, None]},
	If[AssociationQ[state],
		If[MatchQ[Lookup[state, "Process", None], _ProcessObject], pariStopProcess[state["Process"]]];
		AssociateTo[$pariSessions, id -> Append[KeyTake[state, {"Executable", "Version"}], "Status" -> status]];
		pariForgetObjects[session]
	];
	Null
]

pariRequest[session : PARISession[id_String], code_String, mode_String, time_] := pariEnclose @ Module[{state, response, result},
	state = Confirm @ pariSessionData[session];
	ConfirmAssert[state["Status"] === "Ready", pariFailure["PARIInvalidSession", "The PARI session is not ready.", <|"Status" -> state["Status"]|>]];
	AssociateTo[$pariSessions, id -> Append[state, "Status" -> "Busy"]];
	response = CheckAbort[pariExchange[state["Process"], code, mode, time], pariCloseSession[session, "Stopped"]; Abort[]];
	If[FailureQ[response],
		pariCloseSession[session, "Stopped"];
		response,
		AssociateTo[$pariSessions, id -> state];
		result = Replace[response["Payload"], {
			{"ok", value_} :> pariDecode[session, value],
			{"incomplete"} :> pariFailure["PARIInterrupted", "GP ended the request without returning a result. The session was stopped."],
			{"error", kind_, message_} :> pariEnclose @ With[{
				name = Confirm @ pariDecode[session, kind], text = Confirm @ pariDecode[session, message]
			}, If[StringQ[name] && StringQ[text],
				pariFailure["PARIError", "PARI/GP could not evaluate the expression.", <|"PARIError" -> name, "PARIMessage" -> text|>],
				pariFailure["PARIProtocolError", "PARI/GP returned an invalid error response."]
			]],
			_ :> pariFailure["PARIProtocolError", "PARI/GP returned an invalid response."]
		}];
		If[MatchQ[result, Failure["PARIProtocolError" | "PARIInterrupted", _]], pariCloseSession[session, "Stopped"]];
		<|"Result" -> result, "StandardOutput" -> response["StandardOutput"], "StandardError" -> response["StandardError"]|>
	]
]

(session_PARISession)["Properties"] := {"Status", "Version", "Executable", "Properties"}
(session_PARISession)[property : "Status" | "Version" | "Executable"] := pariEnclose @ With[{state = Confirm @ pariSessionData[session]},
	Lookup[state, property, Missing["UnknownProperty", property]]
]
(session_PARISession)[property_String] := Missing["UnknownProperty", property]

PARISession /: DeleteObject[session_PARISession] := pariEnclose @ With[{state = Confirm @ pariSessionData[session]},
	pariCloseSession[session, "Closed"]
]

PARISession /: MakeBoxes[session : PARISession[id_String], form_] := With[{
	status = Lookup[Lookup[$pariSessions, id, <||>], "Status", "Unavailable"]
}, InterpretationBox[RowBox[{"PARISession", "[", ToBoxes[status, form], "]"}], session]]
