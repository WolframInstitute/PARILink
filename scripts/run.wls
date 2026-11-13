(* Loads the development scripts as the package PARILink`Scripts` and runs one command.
   project.wls calls Get[".../run.wls"]["RunProject"]. A test file calls Get[".../run.wls"]["Load"],
   which only loads the package, so that the test file runs on its own. *)
With[{scriptDirectory = DirectoryName[$InputFileName]},
	Function[command,
		Module[{context, sourceOnlyCommands, sourceOnlyIgnored, projectCommand, ignoredFiles},
			context = "PARILink`Scripts`";
			If[!NameQ["System`PackageInitialize"],
				Print["ERROR: scripts require Wolfram Language 15.0 or later; this kernel is ", $Version];
				Exit[1]
			];
			(* The lint and style commands read source files only, so they still run when a build script does not load. *)
			sourceOnlyCommands = {"lint", "style", "style-fix"};
			sourceOnlyIgnored = {"build.wl", "check.wl", "publish.wl", "test.wl"};
			projectCommand = Replace[$ScriptCommandLine, {{_, name_String, ___} :> name, _ -> None}];
			ignoredFiles = If[command === "RunProject" && MemberQ[sourceOnlyCommands, projectCommand], sourceOnlyIgnored, {}];
			If[!MemberQ[$Packages, context],
				PackageInitialize[context, scriptDirectory, <|"LoadFirstFiles" -> {"common.wl", "style.wl"}, "IgnoreFiles" -> ignoredFiles|>]
			];
			If[command === "Load",
				Null,
				Symbol[context <> "RunScript"][Symbol[context <> command]]
			]
		]
	]
]
