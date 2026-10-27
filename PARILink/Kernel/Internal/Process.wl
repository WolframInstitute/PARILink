(* Process details are private. A failed exchange is never reused. *)

PackageScoped[pariFindExecutable]
PackageScoped[pariBundledExecutable]
PackageScoped[pariRuntimeArguments]
PackageScoped[pariStartProcess]
PackageScoped[pariExchange]
PackageScoped[pariStopProcess]

pariFindExecutable[path_String] := If[FileType[ExpandFileName[path]] === File,
	ExpandFileName[path], pariFailure["PARIExecutableNotFound", "The GP executable could not be found.", <|"Path" -> path|>]
]

pariRuntimeRoot[] := Quiet @ Check[
	PacletObject["WolframInstitute/PARILink"]["AssetLocation", "PARIRuntime"], None
]

pariBundledExecutable[root_String, system_String] := FileNameJoin[{
	root, system, If[StringStartsQ[system, "Windows"], "gp.exe", "gp"]
}]
pariBundledExecutable[] := Replace[pariRuntimeRoot[], {
	root_String :> pariBundledExecutable[root, $SystemID], _ -> None
}]

pariFindExecutable[Automatic] := pariFindExecutable[Automatic,
	Environment["PARILINK_GP"], pariBundledExecutable[], Environment["PATH"],
	If[$OperatingSystem === "MacOSX", {"/opt/homebrew/bin/gp", "/usr/local/bin/gp", "/opt/local/bin/gp"}, {}],
	$OperatingSystem
]

pariFindExecutable[Automatic, override_, bundled_, path_, common_List, system_String] := If[
	StringQ[override] && StringTrim[override] =!= "",
	pariFindExecutable[override],
	With[{candidates = Join[
		Cases[{bundled}, _String],
		FileNameJoin[{#, If[system === "Windows", "gp.exe", "gp"]}] & /@
			DeleteCases[StringTrim[#, WhitespaceCharacter | "\""] & /@
				StringSplit[Replace[path, Except[_String] -> ""], If[system === "Windows", ";", ":"]], ""],
		common
	]}, Replace[SelectFirst[candidates, FileType[#] === File &, None],
		None :> pariFailure["PARIExecutableNotFound",
			"No bundled or installed GP was found. Reinstall PARILink or set the Executable option to a GP program."]
	]]
]

pariFindExecutable[_] := pariFailure["PARIInvalidOption", "Executable must be Automatic or a file path."]

pariRuntimeArguments[executable_String] := Module[{bundled = pariBundledExecutable[], data, permissions},
	If[! StringQ[bundled] || ExpandFileName[executable] =!= ExpandFileName[bundled], Return[{}]];
	data = FileNameJoin[{pariRuntimeRoot[], "data"}];
	If[! DirectoryQ[data], Return[pariFailure["PARIStartFailed", "The bundled PARI data is missing. Reinstall PARILink."]]];
	If[$OperatingSystem =!= "Windows",
		(* ZIP extraction may remove execute permission. Only repair this paclet's GP. *)
		permissions = UnixPermissionsString /. FileInformation[executable];
		If[! StringQ[permissions] || ! StringContainsQ[permissions, "x"],
			If[Quiet @ Check[RunProcess[{"/bin/chmod", "u+x", executable}, "ExitCode"], $Failed] =!= 0,
				Return[pariFailure["PARIStartFailed", "The bundled GP program could not be made executable."]]
			]
		]
	];
	{"--default", "datadir=" <> StringReplace[data, "\\" -> "/"]}
]

pariStartProcess[executable_String, stackLimit_Integer] := With[{
	startup = PacletObject["WolframInstitute/PARILink"]["AssetLocation", "GPStartup"],
	runtime = pariRuntimeArguments[executable]
}, If[StringQ[startup] && FileExistsQ[startup],
	If[FailureQ[runtime], Return[runtime]];
	Replace[Quiet @ Check[StartProcess[Join[{
		executable, "-f", "-q", "--default", "colors=no", "--default", "breakloop=0",
		"--default", "parisizemax=" <> IntegerString[stackLimit],
		"--default", "threadsizemax=" <> IntegerString[stackLimit]
	}, runtime, {startup}]], $Failed], Except[_ProcessObject] :> pariFailure["PARIStartFailed", "The GP process could not be started."]],
	pariFailure["PARIStartFailed", "The PARILink startup file is missing."]
]]

pariStopProcess[process_ProcessObject] := (
	If[ProcessStatus[process] === "Running", Quiet @ KillProcess[process]];
	Null
)

pariRead[process_, channel_] := Replace[
	Quiet @ Check[ReadString[ProcessConnection[process, channel], EndOfBuffer], ""], Except[_String] -> ""
]

pariWait[process_ProcessObject, marker_String, deadline_] := Module[{
	out = {}, err = {}, outSize = 0, errSize = 0, newOut, newErr,
	prefix = "\n" <> marker, tail = "", framed = False, parts = {}, fragment,
	start, finish, outputSize, payload, result, done = False
},
	While[! done,
		(* Also check elapsed time when asynchronous kernel timers are delayed. *)
		If[SessionTime[] >= deadline,
			result = pariFailure["PARITimeout", "PARI/GP exceeded the time limit. The session was stopped."];
			Break[]
		];
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

pariExchange[process_ProcessObject, code_String, mode_String, time_] := Module[{marker, command, deadline, source, result},
	marker = "PARILINK:" <> StringDelete[CreateUUID[], "-"] <> ":";
	WithCleanup[
		source = Quiet @ Check[CreateTemporary[], $Failed],
		result = If[! StringQ[source] || Quiet @ Check[Export[source, code <> "\n", "Text", CharacterEncoding -> "UTF-8"], $Failed] === $Failed,
			pariFailure["PARIRequestFailed", "The GP request file could not be written."],
			(* read uses GP's script parser, including multiline and inline declarations.
			   Evaluate outside bridge functions so closures cannot capture their locals. *)
			(* A second input line detects nonlocal exits such as a GP stack reset. *)
			command = "parilinkpending=1;iferr(parilinkresult(read(" <> pariString[source] <> ")," <> pariString[mode] <> "," <> pariString[marker] <>
				"),parilinkexception,parilinkerror(parilinkexception," <> pariString[marker] <> "));\n" <>
				"if(parilinkpending,print1(\"\\n\"," <> pariString[marker] <> ",\"[\\\"incomplete\\\"]\\n\"));\n";
			deadline = SessionTime[] + time;
			CheckAbort[
				TimeConstrained[
					If[Quiet @ Check[WriteLine[process, StringTrim[command]], $Failed] === $Failed,
						pariFailure["PARIProcessStopped", "The request could not be sent to GP."],
						pariWait[process, marker, deadline]
					],
					time, pariFailure["PARITimeout", "PARI/GP exceeded the time limit. The session was stopped."]
				],
				pariStopProcess[process]; Abort[]
			]
		],
		If[FailureQ[result], pariStopProcess[process]];
		If[StringQ[source] && FileExistsQ[source], Quiet @ DeleteFile[source]]
	]
]
