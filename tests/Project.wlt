(* Tests of the development scripts: the shared helpers, the list of project commands, the build fingerprint, the
   release checks and the launcher of child kernels. They need neither GP nor cloud credentials. *)

Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "scripts", "run.wls"}]]["Load"]
Needs["PARILink`Scripts`"]

runTask = PARILink`Scripts`PackageScope`RunTask;
requireOrLog = PARILink`Scripts`PackageScope`RequireOrLog;
quietCheck = PARILink`Scripts`PackageScope`quietCheck;
taskFailureQ = PARILink`Scripts`PackageScope`taskFailureQ;
buildFingerprint = PARILink`Scripts`PackageScope`buildFingerprint;
releaseTag = PARILink`Scripts`PackageScope`releaseTag;
gitCommand = PARILink`Scripts`PackageScope`gitCommand;
gitText = PARILink`Scripts`PackageScope`gitText;
withEntitledKernels = PARILink`Scripts`PackageScope`withEntitledKernels;

(* Gives body applied to a new temporary directory and deletes the directory afterwards. *)
withDirectory[body_Function] :=
	Module[{directory},
		directory = CreateDirectory[];
		WithCleanup[body[directory], DeleteDirectory[directory, DeleteContents -> True]]
	]

(* Writes text to a file, and creates its directory first when needed. *)
writeFixtureFile[file_String, text_String] := (
	If[!DirectoryQ[DirectoryName[file]], CreateDirectory[DirectoryName[file], CreateIntermediateDirectories -> True]];
	Export[file, text, "Text"]
)

(* The result of a step of a script, or "refused" when a required value failed its test. A refused step logs no
   error, so that the test run itself does not count it. *)
refuseStep[___] := Throw["refused", "RefusedStep"]
SetAttributes[stepResult, HoldFirst];
stepResult[body_] := Block[{PARILink`Scripts`PackageScope`failTask = refuseStep}, Catch[body, "RefusedStep"]]

VerificationTest[
	RepositoryPath[FileNameJoin[{$RepositoryRoot, "scripts", "common.wl"}]],
	FileNameJoin[{"scripts", "common.wl"}],
	TestID -> "Scripts: repository paths are relative to the root"
]

(* A required value that fails its test stops the task and gives its Failure. The script then exits with status 1. *)
VerificationTest[
	Module[{failure},
		failure = runTask[requireOrLog[3, EvenQ]];
		{First[failure], taskFailureQ[failure], runTask[requireOrLog[4, EvenQ]]}
	],
	{"ScriptTaskFailure", True, 4},
	TestID -> "Scripts: a required value that fails stops the task"
]

VerificationTest[
	{quietCheck[1 + 1], First @ quietCheck[1 / 0]},
	{2, "MessageFailure"},
	TestID -> "Scripts: a message makes a checked step fail"
]

(* Every project command is a function of the script package. *)
VerificationTest[
	{
		Sort[Keys[PARILink`Scripts`PackageScope`$projectCommands]],
		AllTrue[Values[PARILink`Scripts`PackageScope`$projectCommands], MatchQ[DownValues[#], {__}] &]
	},
	{
		{
			"all", "build", "check", "check-build", "check-release", "ci", "ci-build", "docs", "lint", "publish", "style", "style-fix", "test",
			"test-pari"
		},
		True
	},
	TestID -> "Scripts: every project command has a function"
]

VerificationTest[
	First /@ {RunProject[1], CheckPaclet[1], TestPaclet[1], TestPARI[1], BuildPaclet[1], CheckRelease[1], PublishPaclet[1], RunCI[1]},
	ConstantArray["InvalidArguments", 8],
	{RunProject::args, CheckPaclet::args, TestPaclet::args, TestPARI::args, BuildPaclet::args, CheckRelease::args, PublishPaclet::args, RunCI::args},
	TestID -> "Scripts: commands reject other arguments"
]

(* A changed file changes the fingerprint when the documentation cache depends on it. PacletPage tracks each reference
   page itself, so a reference page does not count. *)
VerificationTest[
	withDirectory @ Function[directory,
		Block[
			{
				$RepositoryRoot = directory,
				$PacletDirectory = FileNameJoin[{directory, "PARILink"}],
				$DocumentationDirectory = FileNameJoin[{directory, "docs", "en"}]
			},
			Module[{files, runtime, fingerprint},
				files = Map[
					FileNameJoin[Prepend[#, directory]] &,
					{{"PARILink", "Kernel", "Test.wl"}, {"PARILink", "Resources", "startup.gp"}, {"docs", "en", "Guides", "Test.md"}, {"docs", "en", "Symbols", "Test.md"}}
				];
				Scan[writeFixtureFile[#, "original"] &, files];
				runtime = {"2.19.0", "gp-binary-hash"};
				fingerprint = buildFingerprint[runtime];
				Join[
					Map[
						Function[file,
							Module[{changedQ},
								writeFixtureFile[file, "changed"];
								changedQ = buildFingerprint[runtime] =!= fingerprint;
								writeFixtureFile[file, "original"];
								changedQ
							]
						],
						files
					],
					{buildFingerprint[{"2.17.4", "gp-binary-hash"}] =!= fingerprint, buildFingerprint[{"2.19.0", "rebuilt-gp-binary"}] =!= fingerprint}
				]
			]
		]
	],
	{True, True, True, False, True, True},
	TestID -> "Build: invalidate caches for code, resources, guides, and GP; track symbol pages individually"
]

releaseEnvironment = <|
	"GITHUB_ACTIONS" -> "true",
	"GITHUB_EVENT_NAME" -> "push",
	"GITHUB_REF_TYPE" -> "tag",
	"GITHUB_REF_NAME" -> "v0.1.0",
	"GITHUB_REF" -> "refs/tags/v0.1.0"
|>;

VerificationTest[
	{
		stepResult[releaseTag[releaseEnvironment, "0.1.0"]],
		stepResult[releaseTag[Append[releaseEnvironment, "GITHUB_EVENT_NAME" -> "workflow_dispatch"], "0.1.0"]]
	},
	{"v0.1.0", "v0.1.0"},
	TestID -> "Release: a matching release tag is accepted after a push or a manual start"
]

VerificationTest[
	Map[
		stepResult[releaseTag[Join[releaseEnvironment, #], "0.1.0"]] &,
		{
			<|"GITHUB_ACTIONS" -> "false"|>,
			<|"GITHUB_EVENT_NAME" -> "workflow_dispatch", "GITHUB_REF_TYPE" -> "branch", "GITHUB_REF" -> "refs/heads/main"|>,
			<|"GITHUB_EVENT_NAME" -> "pull_request"|>,
			<|"GITHUB_EVENT_NAME" -> "release"|>,
			<|"GITHUB_REF_TYPE" -> "branch"|>,
			<|"GITHUB_REF" -> "refs/heads/v0.1.0"|>,
			<|"GITHUB_REF_NAME" -> "v0.2.0", "GITHUB_REF" -> "refs/tags/v0.2.0"|>
		}
	],
	ConstantArray["refused", 7],
	TestID -> "Release: branches, PRs, and mismatched tags cannot publish"
]

VerificationTest[
	Map[
		stepResult[releaseTag[Join[releaseEnvironment, <|"GITHUB_REF_NAME" -> "v" <> #, "GITHUB_REF" -> "refs/tags/v" <> #|>], #]] &,
		{"01.2.3", "1.2", "1.2.3-rc1", "1.2.3.4", "1.2.3\n", "1.2.3+build"}
	],
	ConstantArray["refused", 6],
	TestID -> "Release: malformed or prerelease version tags cannot publish"
]

VerificationTest[
	stepResult[releaseTag[<||>, "0.1.0"]],
	"refused",
	TestID -> "Release: local runs without workflow metadata cannot publish"
]

(* Commits every file of the fixture repository. *)
commitFixture[message_String] := (
	gitCommand["add", "."];
	gitCommand["-c", "commit.gpgsign=false", "commit", "--quiet", "-m", message]
)

(* Each step changes the fixture repository, and the release is checked after it: a clean tagged commit on main
   passes; an untracked file, a change, a tag on another commit, another workflow commit and a commit that main does
   not have are refused. *)
VerificationTest[
	withDirectory @ Function[directory,
		Block[{$RepositoryRoot = directory, $PacletDirectory = FileNameJoin[{directory, "PARILink"}]},
			Module[{info, untracked, original, environment, steps},
				info = FileNameJoin[{directory, "PARILink", "PacletInfo.wl"}];
				untracked = FileNameJoin[{directory, "untracked.txt"}];
				original = "PacletObject[<|\"Name\" -> \"WolframInstitute/PARILink\", \"Version\" -> \"0.1.0\"|>]";
				writeFixtureFile[info, original];
				gitCommand["init", "--quiet", "--initial-branch=main"];
				gitCommand["config", "user.name", "PARILink tests"];
				gitCommand["config", "user.email", "tests@example.invalid"];
				commitFixture["test(release): create a fixture"];
				gitCommand["-c", "tag.gpgsign=false", "tag", "v0.1.0"];
				gitCommand["update-ref", "refs/remotes/origin/main", "HEAD"];
				environment = Append[releaseEnvironment, "GITHUB_SHA" -> gitText["rev-parse", "HEAD"]];
				steps = {
					Function[Null, Null],
					Function[Null, writeFixtureFile[untracked, "uncommitted"]],
					Function[Null,
						DeleteFile[untracked];
						writeFixtureFile[info, original <> "\n(* changed *)\n"]
					],
					Function[Null, commitFixture["test(release): change the fixture"]],
					Function[Null, gitCommand["-c", "tag.gpgsign=false", "tag", "--force", "v0.1.0"]],
					Function[Null, environment["GITHUB_SHA"] = gitText["rev-parse", "HEAD"]],
					Function[Null, gitCommand["update-ref", "refs/remotes/origin/main", "HEAD"]]
				};
				Map[
					Function[step,
						step[];
						stepResult[CheckRelease[environment]]
					],
					steps
				]
			]
		]
	],
	{"v0.1.0", "refused", "refused", "refused", "refused", "refused", "v0.1.0"},
	TestID -> "Release: verify tag, workflow commit, clean checkout, and main ancestry in Git"
]

(* What RunProcess or StartProcess was asked to start, in place of starting a wolframscript command: the command, the
   option or property, the kernel that WOLFRAMSCRIPT_KERNELPATH names, and whether the rest of the environment is that
   of this process. *)
launchRecord[command_List, setting_, environment_Rule] :=
	{
		command,
		setting,
		Lookup[Last[environment], "WOLFRAMSCRIPT_KERNELPATH"],
		KeyDrop[Last[environment], "WOLFRAMSCRIPT_KERNELPATH"] === KeyDrop[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH"]
	}

(* Evaluates body while RunProcess and StartProcess give the launchRecord of a wolframscript command. The built-in
   definitions come back afterwards. *)
SetAttributes[withRecordedLaunches, HoldFirst];
withRecordedLaunches[body_] :=
	(* allow QualifiedSymbol: only Internal`InheritedBlock keeps the built-in definitions of RunProcess and StartProcess while a test adds one *)
	Internal`InheritedBlock[{RunProcess, StartProcess},
		Unprotect[RunProcess, StartProcess];
		DownValues[RunProcess] = Prepend[
			DownValues[RunProcess],
			HoldPattern[RunProcess[command : {"wolframscript", ___String}, property_, environment_Rule]] :> launchRecord[command, property, environment]
		];
		DownValues[StartProcess] = Prepend[
			DownValues[StartProcess],
			HoldPattern[StartProcess[command : {"wolframscript", ___String}, directory_Rule, environment_Rule]] :> launchRecord[command, directory, environment]
		];
		Protect[RunProcess, StartProcess];
		body
	]

VerificationTest[
	withRecordedLaunches @ withEntitledKernels[RunProcess[{"/path with spaces/WolframKernel", "-noprompt", "-script", "/tmp/build.wl"}, "ExitCode"]],
	{{"wolframscript", "-file", "/tmp/build.wl"}, "ExitCode", "/path with spaces/WolframKernel", True},
	TestID -> "Build: synchronous child kernels use the entitlement launcher"
]

VerificationTest[
	withRecordedLaunches @ withEntitledKernels[
		StartProcess[{"/path with spaces/WolframKernel", "-noprompt", "-script", "/tmp/build.wl"}, ProcessDirectory -> "/tmp"]
	],
	{{"wolframscript", "-file", "/tmp/build.wl"}, ProcessDirectory -> "/tmp", "/path with spaces/WolframKernel", True},
	TestID -> "Build: asynchronous child kernels keep their environment and options"
]

VerificationTest[
	Module[{file, kernel, result},
		file = CreateTemporary[];
		kernel = SelectFirst[
			Map[FileNameJoin[Prepend[#, $InstallationDirectory]] &, {{"MacOS", "WolframKernel"}, {"Executables", "WolframKernel"}, {"Executables", "WolframKernel.exe"}}],
			FileExistsQ
		];
		WithCleanup[
			Export[file, "Print[\"PARILINK-CHILD-KERNEL\"];", "Text"],
			result = withEntitledKernels[RunProcess[{kernel, "-noprompt", "-script", file}]];
			{result["ExitCode"], StringTrim[result["StandardOutput"]]},
			DeleteFile[file]
		]
	],
	{0, "PARILINK-CHILD-KERNEL"},
	TestID -> "Build: the entitlement launcher executes a child script"
]

VerificationTest[
	withEntitledKernels[RunProcess[{"git", "--version"}, "ExitCode"]],
	0,
	TestID -> "Build: other processes pass through unchanged"
]

(* The launcher is only replaced for the time of the call. *)
VerificationTest[
	Module[{runDefinitions, startDefinitions},
		runDefinitions = DownValues[RunProcess];
		startDefinitions = DownValues[StartProcess];
		withEntitledKernels[Null];
		{DownValues[RunProcess] === runDefinitions, DownValues[StartProcess] === startDefinitions}
	],
	{True, True},
	TestID -> "Build: the launcher is restored afterwards"
]
