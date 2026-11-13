(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{
	pariFindExecutable, pariBundledExecutable, pariRuntimeArguments, pariExecutableFile, pariStartProcess, pariExchange, pariStopProcess, pariEmptyPoll,
	pariReceivedText, pariFramedText
}];

(* ::Section:: *)
(*Usage Messages*)

pariFindExecutable::usage = "pariFindExecutable[path] gives the full path of the GP program at path, or a Failure with the tag \
\"PARIExecutableNotFound\" when no file is there.\n\
pariFindExecutable[Automatic] finds GP: the program that PARILINK_GP names, then the GP in the paclet, then a GP on PATH, then one in a common \
macOS location.\n\
pariFindExecutable[Automatic, override, bundled, searchPath, commonPrograms, system] searches with the given values: override is the value of \
PARILINK_GP, bundled the path of the GP in the paclet or None, searchPath the value of PATH, commonPrograms a list of program paths, and system \
the operating system. An override or a search path that is not set is $Failed. An override that is set must exist; nothing else is tried.";
pariBundledExecutable::usage = "pariBundledExecutable[] gives the path of the GP in the paclet for this system, or None when the paclet has no \
runtime directory. The file need not exist.\n\
pariBundledExecutable[root, system] gives the path of the GP for the system ID under the runtime directory root.";
pariRuntimeArguments::usage = "pariRuntimeArguments[executable] gives the command-line arguments that the GP program at the path executable \
needs to find its data: none for a GP outside the paclet, and the data directory of the paclet for the GP in it. For the GP in the paclet it also \
restores a lost execute permission. It gives a Failure with the tag \"PARIStartFailed\" when the data or the permission cannot be had.";
pariStartProcess::usage = "pariStartProcess[executable, stackLimit] starts the GP program at the path executable with the PARILink startup file \
and the stack limit, in bytes, for its main thread and its workers. It gives the process, or a Failure with the tag \"PARIStartFailed\".";
pariExchange::usage = "pariExchange[process, code, mode, timeConstraint] has the GP process evaluate the string code and waits for the response, \
for at most timeConstraint seconds. mode is \"Automatic\", \"Object\", \"String\" or \"Copy\" and says how GP returns the value. It gives an \
association with the \"Payload\" of the response and the \"StandardOutput\" and \"StandardError\" that GP wrote, or a Failure. A request that \
fails stops the process, because a late response could be read as the answer to the next request.";
pariStopProcess::usage = "pariStopProcess[process] ends the process if it is running, and gives Null.";
$pariCommonPrograms::usage = "$pariCommonPrograms lists the paths where macOS package managers put GP.";
$pariOutputLimit::usage = "$pariOutputLimit is the number of characters that GP may write during one request.";
$pariShortWaitTime::usage = "$pariShortWaitTime is the number of seconds at the start of a request during which the reading pauses only \
briefly when nothing has arrived. A small request is answered within it.";
pariIdlePause::usage = "pariIdlePause[poll] gives the number of seconds to pause after a reading that found nothing: a short pause during \
the first $pariShortWaitTime seconds of the wait, and a longer one after it.";
pariRuntimeRoot::usage = "pariRuntimeRoot[] gives the runtime directory of the paclet, or None when the paclet does not name one.";
pariSearchDirectories::usage = "pariSearchDirectories[searchPath, system] gives the directories that the value of PATH lists on the operating \
system, without blank entries. A search path that is not set, $Failed, has none.";
pariBundledQ::usage = "pariBundledQ[executable] gives True when the path executable is the GP in the paclet for this system.";
pariExecutablePermissionQ::usage = "pariExecutablePermissionQ[file] gives True when the permissions of the file allow someone to execute it.";
pariExecutableFile::usage = "pariExecutableFile[executable] gives the path executable once the file may be executed, after adding the permission \
for its owner when it had none. It gives a Failure when the permission cannot be added. Windows has no such permission.";
pariStartupFile::usage = "pariStartupFile[] gives the path of the GP file that runs the PARILink side of each request.";
pariStartedProcess::usage = "pariStartedProcess[command] starts the command, a list of strings, and gives the process, or a Failure.";
pariReadChannel::usage = "pariReadChannel[process, channel] gives the text that is ready on \"StandardOutput\" or \"StandardError\" of the \
process, without waiting. It gives the empty string when nothing is ready or the channel is closed.";
pariTimeoutFailure::usage = "pariTimeoutFailure[] gives the Failure with the tag \"PARITimeout\".";
pariEmptyPoll::usage = "pariEmptyPoll[] gives the state of a wait before the first reading, an association: the \"Output\" and \"Error\" read so \
far with their sizes, the \"Tail\" kept while the marker is looked for, the \"ResponseParts\" after the marker, the \"OutputLength\" before it, \
the \"PayloadText\" and \"TrailingText\" of a complete response, the \"Result\", and the session time when the wait \"Started\".";
pariReceivedText::usage = "pariReceivedText[poll, newOutput, newError] gives the state of a wait with the text of one reading added.";
pariResponseText::usage = "pariResponseText[poll, fragment] gives the state of a wait with fragment, text after the marker, added to the \
response. When the fragment holds the line break that ends the response, the state gets the \"PayloadText\" and the \"TrailingText\" after it.";
pariFramedText::usage = "pariFramedText[poll, newOutput, prefix] looks for the marker of the response in the output of one reading. Before the \
marker is found, the state keeps only the end of the output that a marker split between two readings needs.";
pariCompletedResponse::usage = "pariCompletedResponse[poll, process] gives the response that a finished wait holds: the \"Payload\" read from \
JSON, or None when it is not JSON, the \"StandardOutput\" before the marker and the \"StandardError\". Text after the response gives a Failure.";
pariSettledResponse::usage = "pariSettledResponse[poll, link, idleQ] ends one reading: it sets the \"Result\" when the response is complete or \
the process has stopped, and otherwise pauses when idleQ says that nothing arrived.";
pariPolledResponse::usage = "pariPolledResponse[poll, link] reads both channels of the GP process once and gives the new state of the wait. link \
holds the \"Process\", the \"Prefix\" that starts the response and the \"Deadline\". The \"Result\" of the state is None until the response is \
complete or the wait has failed.";
pariWaitForResponse::usage = "pariWaitForResponse[process, marker, deadline] reads the output of the GP process until the response with the \
marker is complete, and gives the response or a Failure. deadline is a session time.";
pariRequestCommand::usage = "pariRequestCommand[sourceFile, mode, marker] gives the two GP statements that evaluate the code in the file and \
print the response after the marker. The second statement reports a request that GP abandoned without a response.";
pariRequestFileQ::usage = "pariRequestFileQ[sourceFile, code] writes the string code to the file as UTF-8 and gives True, or False when the \
file cannot be written.";
pariSentRequestQ::usage = "pariSentRequestQ[process, command] writes the command to the process and gives True, or False when the process \
does not take it.";
pariAwaitedResponse::usage = "pariAwaitedResponse[process, command, marker, timeConstraint] sends the command and waits for the response with \
the marker, for at most timeConstraint seconds. An abort stops the process.";

(* ::Section:: *)
(*Function Definitions*)

(* A call that asks about the paclet, a file, a process or its streams quiets every message. Whatever such a call
   reports, the result is the same: the step did not work, and the caller gets a Failure. *)

$pariCommonPrograms = {"/opt/homebrew/bin/gp", "/usr/local/bin/gp", "/opt/local/bin/gp"};
$pariOutputLimit = 16 * 1024 ^ 2;
$pariShortWaitTime = 0.02;

pariRuntimeRoot[] := Quiet[Check[PacletObject["WolframInstitute/PARILink"]["AssetLocation", "PARIRuntime"], None], All]

pariBundledExecutable[root_String, system_String] := FileNameJoin[{root, system, If[StringStartsQ[system, "Windows"], "gp.exe", "gp"]}]
pariBundledExecutable[] := Replace[pariRuntimeRoot[], {root_String :> pariBundledExecutable[root, $SystemID], _ -> None}]

pariSearchDirectories[searchPath_String, system_String] :=
	DeleteCases[Map[StringTrim[#, WhitespaceCharacter | "\""] &, StringSplit[searchPath, If[system === "Windows", ";", ":"]]], ""]
pariSearchDirectories[$Failed, _String] := {}

pariFindExecutable[""] := pariFailure["PARIExecutableNotFound", "The GP executable could not be found.", <|"Path" -> ""|>]
pariFindExecutable[path_String] :=
	Module[{fullPath},
		fullPath = ExpandFileName[path];
		If[FileType[fullPath] === File, fullPath, pariFailure["PARIExecutableNotFound", "The GP executable could not be found.", <|"Path" -> path|>]]
	]
pariFindExecutable[Automatic] :=
	pariFindExecutable[
		Automatic,
		Environment["PARILINK_GP"],
		pariBundledExecutable[],
		Environment["PATH"],
		If[$OperatingSystem === "MacOSX", $pariCommonPrograms, {}],
		$OperatingSystem
	]
pariFindExecutable[
	Automatic, override : (_String | $Failed), bundled : (_String | None), searchPath : (_String | $Failed), commonPrograms : {___String}, system_String
] :=
	Module[{programName, candidates},
		If[StringQ[override] && StringTrim[override] =!= "",
			pariFindExecutable[override],

			programName = If[system === "Windows", "gp.exe", "gp"];
			candidates = Join[
				Cases[{bundled}, _String],
				Map[FileNameJoin[{#, programName}] &, pariSearchDirectories[searchPath, system]],
				commonPrograms
			];
			Replace[
				SelectFirst[candidates, FileType[#] === File &, None],
				None :> pariFailure["PARIExecutableNotFound", "No bundled or installed GP was found. Reinstall PARILink or set the Executable option to a GP program."]
			]
		]
	]
pariFindExecutable[_] := pariFailure["PARIInvalidOption", "Executable must be Automatic or a file path."]

pariBundledQ[executable_String] :=
	Module[{bundled},
		bundled = pariBundledExecutable[];
		StringQ[bundled] && ExpandFileName[executable] === ExpandFileName[bundled]
	]

pariExecutablePermissionQ[file_String] :=
	Module[{permissions},
		permissions = Lookup[FileInformation[file], "UnixPermissionsString", None];
		StringQ[permissions] && StringContainsQ[permissions, "x"]
	]

(* Extracting a paclet archive can drop the execute permission. Only the GP of this paclet is repaired. *)
pariExecutableFile[executable_String] :=
	Which[
		$OperatingSystem === "Windows" || pariExecutablePermissionQ[executable],
			executable,
		Quiet[Check[RunProcess[{"/bin/chmod", "u+x", executable}, "ExitCode"], None], All] === 0,
			executable,
		True,
			pariFailure["PARIStartFailed", "The bundled GP program could not be made executable."]
	]

pariRuntimeArguments[executable_String] :=
	Module[{dataDirectory},
		If[pariBundledQ[executable],
			dataDirectory = FileNameJoin[{pariRuntimeRoot[], "data"}];
			Which[
				!DirectoryQ[dataDirectory],
					pariFailure["PARIStartFailed", "The bundled PARI data is missing. Reinstall PARILink."],
				FailureQ[pariExecutableFile[executable]],
					pariFailure["PARIStartFailed", "The bundled GP program could not be made executable."],
				True,
					{"--default", "datadir=" <> StringReplace[dataDirectory, "\\" -> "/"]}
			],

			{}
		]
	]

pariStartupFile[] := PacletObject["WolframInstitute/PARILink"]["AssetLocation", "GPStartup"]

pariStartedProcess[command : {__String}] :=
	Replace[Quiet[Check[StartProcess[command], None], All], Except[_ProcessObject] :> pariFailure["PARIStartFailed", "The GP process could not be started."]]

(* GP reads no user startup file, so that nothing there changes the responses or runs code. *)
pariStartProcess[executable_String, stackLimit_Integer] :=
	Module[{startupFile, runtimeArguments, stackOptions},
		startupFile = pariStartupFile[];
		runtimeArguments = pariRuntimeArguments[executable];
		stackOptions = {"--default", "parisizemax=" <> IntegerString[stackLimit], "--default", "threadsizemax=" <> IntegerString[stackLimit]};
		Which[
			!(StringQ[startupFile] && FileExistsQ[startupFile]),
				pariFailure["PARIStartFailed", "The PARILink startup file is missing."],
			FailureQ[runtimeArguments],
				runtimeArguments,
			True,
				pariStartedProcess[
					Join[{executable, "-f", "-q", "--default", "colors=no", "--default", "breakloop=0"}, stackOptions, runtimeArguments, {startupFile}]
				]
		]
	]

pariStopProcess[process_ProcessObject] := (
	If[ProcessStatus[process] === "Running", Quiet[KillProcess[process], All]];
	Null
)

pariReadChannel[process_ProcessObject, channel : ("StandardOutput" | "StandardError")] :=
	Replace[Quiet[Check[ReadString[ProcessConnection[process, channel], EndOfBuffer], ""], All], Except[_String] -> ""]

pariTimeoutFailure[] := pariFailure["PARITimeout", "PARI/GP exceeded the time limit. The session was stopped."]

pariEmptyPoll[] :=
	<|
		"Output" -> {},
		"Error" -> {},
		"OutputSize" -> 0,
		"ErrorSize" -> 0,
		"Tail" -> "",
		"ResponseParts" -> None,
		"OutputLength" -> None,
		"PayloadText" -> None,
		"TrailingText" -> None,
		"Result" -> None,
		"Started" -> SessionTime[]
	|>

pariReceivedText[poll_Association, newOutput_String, newError_String] :=
	Join[
		poll,
		<|
			"Output" -> If[newOutput === "", poll["Output"], Append[poll["Output"], newOutput]],
			"Error" -> If[newError === "", poll["Error"], Append[poll["Error"], newError]],
			"OutputSize" -> poll["OutputSize"] + StringLength[newOutput],
			"ErrorSize" -> poll["ErrorSize"] + StringLength[newError]
		|>
	]

pariResponseText[poll_Association, ""] := poll
pariResponseText[poll_Association, fragment_String] :=
	Module[{responseParts},
		responseParts = Append[poll["ResponseParts"], fragment];
		Replace[
			StringPosition[fragment, "\n", 1],
			{
				{{lineEnd_Integer, _Integer}} :> Join[
					poll,
					<|
						"ResponseParts" -> responseParts,
						"PayloadText" -> StringJoin[poll["ResponseParts"], StringTake[fragment, lineEnd - 1]],
						"TrailingText" -> StringDrop[fragment, lineEnd]
					|>
				],
				_ :> Append[poll, "ResponseParts" -> responseParts]
			}
		]
	]

(* Each reading is searched once. Until the marker is found, the state keeps the end of the output, one character
   shorter than the marker, so that a marker split between two readings is still found. *)
pariFramedText[poll_Association, newOutput_String, prefix_String] :=
	Module[{tail},
		If[ListQ[poll["ResponseParts"]],
			pariResponseText[poll, newOutput],

			tail = poll["Tail"] <> newOutput;
			Replace[
				StringPosition[tail, prefix, 1],
				{
					{{markerStart_Integer, markerEnd_Integer}} :> pariResponseText[
						Join[poll, <|"ResponseParts" -> {}, "OutputLength" -> poll["OutputSize"] - StringLength[tail] + markerStart - 1|>],
						StringDrop[tail, markerEnd]
					],
					_ :> Append[poll, "Tail" -> StringTake[tail, -Min[StringLength[tail], StringLength[prefix] - 1]]]
				}
			]
		]
	]

(* A response that is not JSON gives one of several messages. Whichever it is, the payload is not valid. *)
pariCompletedResponse[poll_Association, process_ProcessObject] :=
	If[poll["TrailingText"] === "",
		<|
			"Payload" -> Quiet[Check[ImportString[poll["PayloadText"], "RawJSON"], None], All],
			"StandardOutput" -> StringTake[StringJoin[poll["Output"]], poll["OutputLength"]],
			"StandardError" -> StringJoin[poll["Error"]] <> pariReadChannel[process, "StandardError"]
		|>,
		pariFailure["PARIProtocolError", "PARI/GP returned data after its response."]
	]

(* GP answers a small request in about a millisecond, often just after the first reading. A short pause then keeps
   the answer from waiting for a long one; a long computation is still read at the slower pace. *)
pariIdlePause[poll_Association] := If[SessionTime[] - poll["Started"] < $pariShortWaitTime, 0.001, 0.01]

pariSettledResponse[poll_Association, link_Association, idleQ : (True | False)] :=
	Which[
		StringQ[poll["PayloadText"]],
			Append[poll, "Result" -> pariCompletedResponse[poll, link["Process"]]],
		ProcessStatus[link["Process"]] =!= "Running",
			Append[
				poll,
				"Result" -> pariFailure[
					"PARIProcessStopped", "The GP process stopped before returning a result.",
					<|"StandardOutput" -> StringJoin[poll["Output"]], "StandardError" -> StringJoin[poll["Error"]]|>
				]
			],
		True,
			If[idleQ, Pause[pariIdlePause[poll]]];
			poll
	]

(* The elapsed time is checked here as well, because a busy kernel can deliver the timer of TimeConstrained late. *)
pariPolledResponse[poll_Association, link_Association] :=
	Module[{newOutput, newError, received},
		If[SessionTime[] >= link["Deadline"],
			Append[poll, "Result" -> pariTimeoutFailure[]],

			newOutput = pariReadChannel[link["Process"], "StandardOutput"];
			newError = pariReadChannel[link["Process"], "StandardError"];
			received = pariReceivedText[poll, newOutput, newError];
			If[received["OutputSize"] + received["ErrorSize"] > $pariOutputLimit,
				Append[received, "Result" -> pariFailure["PARIOutputLimit", "PARI/GP produced too much output. The session was stopped."]],
				pariSettledResponse[pariFramedText[received, newOutput, link["Prefix"]], link, newOutput === "" && newError === ""]
			]
		]
	]

pariWaitForResponse[process_ProcessObject, marker_String, deadline : (_Real | Infinity)] :=
	Module[{link, lastPoll},
		link = <|"Process" -> process, "Prefix" -> "\n" <> marker, "Deadline" -> deadline|>;
		lastPoll = NestWhile[pariPolledResponse[#, link] &, pariEmptyPoll[], #Result === None &];
		lastPoll["Result"]
	]

(* GP reads the code with its script parser, which takes several lines and inline declarations. The code runs
   outside the functions of the startup file, so that a closure in it cannot capture their local variables. The
   second statement answers when the first one ended without a response, as after GP resets its stack. *)
pariRequestCommand[sourceFile_String, mode_String, marker_String] :=
	StringJoin[
		"parilinkpending=1;iferr(parilinkresult(read(", pariString[sourceFile], "),", pariString[mode], ",", pariString[marker],
		"),parilinkexception,parilinkerror(parilinkexception,", pariString[marker], "));\n",
		"if(parilinkpending,print1(\"\\n\",", pariString[marker], ",\"[\\\"incomplete\\\"]\\n\"));"
	]

pariRequestFileQ[sourceFile_String, code_String] :=
	StringQ[Quiet[Check[Export[sourceFile, code <> "\n", "Text", CharacterEncoding -> "UTF-8"], None], All]]
pariRequestFileQ[___] := False

pariSentRequestQ[process_ProcessObject, command_String] :=
	TrueQ @ Quiet[
		Check[
			WriteLine[process, command];
			True,

			False
		],
		All
	]

pariAwaitedResponse[process_ProcessObject, command_String, marker_String, timeConstraint_?pariTimeConstraintQ] :=
	Module[{deadline},
		deadline = SessionTime[] + timeConstraint;
		CheckAbort[
			TimeConstrained[
				If[pariSentRequestQ[process, command],
					pariWaitForResponse[process, marker, deadline],
					pariFailure["PARIProcessStopped", "The request could not be sent to GP."]
				],
				timeConstraint,
				pariTimeoutFailure[]
			],
			pariStopProcess[process];
			Abort[]
		]
	]

(* The code goes to GP in a file, which is removed when the request ends, however it ends. *)
pariExchange[process_ProcessObject, code_String, mode_String, timeConstraint_?pariTimeConstraintQ] :=
	Module[{marker, sourceFile, result},
		marker = "PARILINK:" <> StringDelete[CreateUUID[], "-"] <> ":";
		WithCleanup[
			sourceFile = Quiet[Check[CreateTemporary[], None], All],
			result = If[pariRequestFileQ[sourceFile, code],
				pariAwaitedResponse[process, pariRequestCommand[sourceFile, mode, marker], marker, timeConstraint],
				pariFailure["PARIRequestFailed", "The GP request file could not be written."]
			],
			If[FailureQ[result], pariStopProcess[process]];
			If[StringQ[sourceFile] && FileExistsQ[sourceFile], Quiet[DeleteFile[sourceFile], All]]
		]
	]
