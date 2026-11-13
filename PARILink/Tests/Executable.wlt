(* Tests for the search for GP in Kernel/Internal/Process.wl: an explicit program, PARILINK_GP, the GP in the paclet,
   PATH and common locations, and the execute permission of the GP in the paclet. They need no GP. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`PARILink`"]

findGP = WolframInstitute`PARILink`PackageScope`pariFindExecutable;
bundledGP = WolframInstitute`PARILink`PackageScope`pariBundledExecutable;
executableFile = WolframInstitute`PARILink`PackageScope`pariExecutableFile;

(* Gives body applied to a new temporary directory and deletes the directory afterwards. *)
withDirectory[body_Function] :=
	Module[{directory},
		directory = CreateDirectory[];
		WithCleanup[body[directory], DeleteDirectory[directory, DeleteContents -> True]]
	]

(* The tag of a Failure, or the value itself. *)
failureTag[Failure[tag_, _]] := tag
failureTag[value_] := value

VerificationTest[
	Map[
		FileNameTake[bundledGP["/runtime", #]] &,
		{"MacOSX-ARM64", "MacOSX-x86-64", "Linux-ARM64", "Linux-x86-64", "Windows-x86-64"}
	],
	{"gp", "gp", "gp", "gp", "gp.exe"},
	TestID -> "bundle-executable-for-each-platform"
]

VerificationTest[
	withDirectory @ Function[directory,
		Module[{bundled, override, common, missing, pathProgram},
			{bundled, override, common, missing} = Map[FileNameJoin[{directory, #}] &, {"bundled", "override", "common", "missing"}];
			pathProgram = FileNameJoin[{directory, "gp"}];
			Scan[Export[#, "test", "Text"] &, {bundled, override, pathProgram, common}];
			{
				findGP[override] === override,
				findGP[Automatic, override, bundled, directory, {common}, "Unix"] === override,
				findGP[Automatic, "", bundled, directory, {common}, "Unix"] === bundled,
				findGP[Automatic, "", missing, directory, {common}, "Unix"] === pathProgram,
				findGP[Automatic, "", missing, "", {common}, "Unix"] === common,
				failureTag[findGP[Automatic, missing, bundled, directory, {common}, "Unix"]],
				failureTag[findGP[Automatic, "", missing, $Failed, {}, "Unix"]]
			}
		]
	],
	{True, True, True, True, True, "PARIExecutableNotFound", "PARIExecutableNotFound"},
	TestID -> "explicit-and-environment-overrides-then-bundle-then-path-with-no-silent-override-fallback"
]

VerificationTest[
	withDirectory @ Function[directory,
		Module[{program},
			program = FileNameJoin[{directory, "gp.exe"}];
			Export[program, "test", "Text"];
			findGP[Automatic, "", None, "\"" <> directory <> "\";", {}, "Windows"] === program
		]
	],
	True,
	TestID -> "windows-path-with-quotes-and-empty-entries"
]

(* An empty path names no program. It gives the Failure without the messages of ExpandFileName and FileType. *)
VerificationTest[
	findGP[""],
	Failure["PARIExecutableNotFound", <|"MessageTemplate" -> "The GP executable could not be found.", "Path" -> ""|>],
	TestID -> "empty-executable-path-gives-a-failure-without-messages"
]

VerificationTest[
	{failureTag[findGP[42]], failureTag[findGP[None]]},
	{"PARIInvalidOption", "PARIInvalidOption"},
	TestID -> "executable-must-be-automatic-or-a-path"
]

(* Extracting an archive can drop the execute permission of GP. It is restored only when it is missing, so that a GP
   that the user may run but not change still starts. *)
VerificationTest[
	If[$OperatingSystem === "Windows",
		{True, True},

		withDirectory @ Function[directory,
			Module[{program},
				program = FileNameJoin[{directory, "gp"}];
				Export[program, "test", "Text"];
				RunProcess[{"/bin/chmod", "644", program}];
				{executableFile[program] === program, StringContainsQ[FileInformation[program, "UnixPermissionsString"], "x"]}
			]
		]
	],
	{True, True},
	TestID -> "lost-execute-permission-is-restored"
]

VerificationTest[
	If[$OperatingSystem === "Windows",
		True,

		withDirectory @ Function[directory,
			Module[{program},
				program = FileNameJoin[{directory, "gp"}];
				Export[program, "test", "Text"];
				RunProcess[{"/bin/chmod", "755", program}];
				Block[{RunProcess = Function[Null, Throw["chmod ran", "Permission"]]}, Catch[executableFile[program], "Permission"]] === program
			]
		]
	],
	True,
	TestID -> "an-executable-program-is-left-as-it-is"
]
