(* Process details are private. A failed exchange is never reused. *)

PackageScoped[pariFindExecutable]
PackageScoped[pariStartProcess]
PackageScoped[pariExchange]
PackageScoped[pariStopProcess]

pariFindExecutable[path_String] := If[FileType[ExpandFileName[path]] === File,
	ExpandFileName[path], pariFailure["PARIExecutableNotFound", "The GP executable could not be found.", <|"Path" -> path|>]
]

pariFindExecutable[Automatic] := With[{
	override = Environment["PARILINK_GP"],
	path = Replace[Environment["PATH"], Except[_String] -> ""],
	name = If[$OperatingSystem === "Windows", "gp.exe", "gp"]
}, If[StringQ[override] && StringTrim[override] =!= "",
	pariFindExecutable[override],
	With[{candidates = Join[
		FileNameJoin[{#, name}] & /@ DeleteCases[StringSplit[path, If[$OperatingSystem === "Windows", ";", ":"]], ""],
		If[$OperatingSystem === "MacOSX", {"/opt/homebrew/bin/gp", "/usr/local/bin/gp", "/opt/local/bin/gp"}, {}]
	]}, Replace[SelectFirst[candidates, FileType[#] === File &, None],
		None :> pariFailure["PARIExecutableNotFound", "Install PARI/GP or set the Executable option to its GP program."]
	]]
]]

pariFindExecutable[_] := pariFailure["PARIInvalidOption", "Executable must be Automatic or a file path."]

pariStartProcess[executable_String] := With[{
	startup = PacletObject["WolframInstitute/PARILink"]["AssetLocation", "GPStartup"]
}, If[StringQ[startup] && FileExistsQ[startup],
	Replace[Quiet @ Check[StartProcess[{
		executable, "-f", "-q", "--default", "colors=no", "--default", "breakloop=0",
		"--default", "parisizemax=268435456", startup
	}], $Failed], Except[_ProcessObject] :> pariFailure["PARIStartFailed", "The GP process could not be started."]],
	pariFailure["PARIStartFailed", "The PARILink startup file is missing."]
]]

pariStopProcess[process_ProcessObject] := (
	If[ProcessStatus[process] === "Running", Quiet @ KillProcess[process]];
	Null
)

pariRead[process_, channel_] := Replace[
	Quiet @ Check[ReadString[ProcessConnection[process, channel], EndOfBuffer], ""], Except[_String] -> ""
]

pariWait[process_ProcessObject, marker_String] := Module[{
	out = {}, err = {}, outSize = 0, errSize = 0, newOut, newErr,
	prefix = "\n" <> marker, tail = "", framed = False, parts = {}, fragment,
	start, finish, outputSize, payload, result, done = False
},
	While[! done,
		newOut = pariRead[process, "StandardOutput"];
		newErr = pariRead[process, "StandardError"];
		If[newOut =!= "", AppendTo[out, newOut]; outSize += StringLength[newOut]];
		If[newErr =!= "", AppendTo[err, newErr]; errSize += StringLength[newErr]];
		If[outSize + errSize > 16 * 1024^2,
			result = pariFailure["PARIOutputLimit", "PARI/GP produced too much output. The session was stopped."];
			Break[]
		];
		(* Scan each chunk once, keeping only enough text to recognize a split marker. *)
		fragment = newOut;
		If[! framed,
			tail = tail <> newOut;
			start = StringPosition[tail, prefix, 1];
			If[start === {},
				tail = StringTake[tail, -Min[StringLength[tail], StringLength[prefix] - 1]],
				outputSize = outSize - StringLength[tail] + First @ First @ start - 1;
				fragment = StringDrop[tail, Last @ First @ start];
				framed = True
			]
		];
		If[framed && fragment =!= "",
			AppendTo[parts, fragment];
			finish = StringPosition[fragment, "\n", 1];
			If[finish =!= {},
				payload = StringJoin[Most[parts], StringTake[fragment, First @ First @ finish - 1]];
				result = If[StringDrop[fragment, Last @ First @ finish] === "",
					<|"Payload" -> Quiet @ Check[ImportString[payload, "RawJSON"], $Failed],
						"StandardOutput" -> StringTake[StringJoin[out], outputSize],
						"StandardError" -> StringJoin[err] <> pariRead[process, "StandardError"]|>,
					pariFailure["PARIProtocolError", "PARI/GP returned data after its response."]
				];
				done = True
			]
		];
		If[! done && ProcessStatus[process] =!= "Running",
			result = pariFailure["PARIProcessStopped", "The GP process stopped before returning a result.",
				<|"StandardOutput" -> StringJoin[out], "StandardError" -> StringJoin[err]|>];
			done = True
		];
		If[! done && newOut === "" && newErr === "", Pause[0.01]]
	];
	result
]

pariExchange[process_ProcessObject, code_String, mode_String, time_] := Module[{marker, command},
	marker = "PARILINK:" <> StringDelete[CreateUUID[], "-"] <> ":";
	command = "parilinkrequest(" <> pariString[code] <> "," <> pariString[mode] <> "," <> pariString[marker] <> ");\n";
	CheckAbort[
		TimeConstrained[
			If[Quiet @ Check[WriteLine[process, StringTrim[command]], $Failed] === $Failed,
				pariFailure["PARIProcessStopped", "The request could not be sent to GP."],
				pariWait[process, marker]
			],
			time, pariFailure["PARITimeout", "PARI/GP exceeded the time limit. The session was stopped."]
		],
		pariStopProcess[process]; Abort[]
	]
]
