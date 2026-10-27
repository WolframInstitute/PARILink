(* Build and release checks run without cloud credentials or GP. *)

VerificationTest[
	Module[{directory = CreateDirectory[], files, fingerprint, runtime = {"2.19.0", "gp-binary-hash"}, changed},
		files = FileNameJoin[Prepend[#, directory]] & /@ {
			{"PARILink", "Kernel", "Test.wl"}, {"PARILink", "Resources", "startup.gp"},
			{"docs", "en", "Guides", "Test.md"}, {"docs", "en", "Symbols", "Test.md"}
		};
		WithCleanup[
			Scan[(CreateDirectory[DirectoryName[#], CreateIntermediateDirectories -> True]; Export[#, "original", "Text"]) &, files],
			Block[{root = directory, pacletDirectory = FileNameJoin[{directory, "PARILink"}], docsDirectory = FileNameJoin[{directory, "docs", "en"}]},
				fingerprint = buildFingerprint[runtime];
				changed = Map[Function[file,
					Export[file, "changed", "Text"];
					With[{different = buildFingerprint[runtime] =!= fingerprint}, Export[file, "original", "Text"]; different]
				], files];
				Join[changed, {buildFingerprint[{"2.17.4", "gp-binary-hash"}] =!= fingerprint,
					buildFingerprint[{"2.19.0", "rebuilt-gp-binary"}] =!= fingerprint}]
			],
			DeleteDirectory[directory, DeleteContents -> True]
		]
	],
	{True, True, True, False, True, True},
	TestID -> "Build: invalidate caches for code, resources, guides, and GP; track symbol pages individually"
]

releaseEnvironment = <|
	"GITHUB_ACTIONS" -> "true", "GITHUB_EVENT_NAME" -> "push", "GITHUB_REF_TYPE" -> "tag",
	"GITHUB_REF_NAME" -> "v0.1.0", "GITHUB_REF" -> "refs/tags/v0.1.0"
|>;

VerificationTest[
	releaseTag[releaseEnvironment, "0.1.0"],
	"v0.1.0",
	TestID -> "Release: matching release-tag push is accepted"
]

VerificationTest[
	releaseTag[Append[releaseEnvironment, "GITHUB_EVENT_NAME" -> "workflow_dispatch"], "0.1.0"],
	"v0.1.0",
	TestID -> "Release: manual run on a matching release tag is accepted"
]

VerificationTest[
	Block[{Print = (Null &)},
		Catch[releaseTag[Join[releaseEnvironment, #], "0.1.0"], "exit"] & /@ {
			<|"GITHUB_ACTIONS" -> "false"|>,
			<|"GITHUB_EVENT_NAME" -> "workflow_dispatch", "GITHUB_REF_TYPE" -> "branch", "GITHUB_REF" -> "refs/heads/main"|>,
			<|"GITHUB_EVENT_NAME" -> "pull_request"|>, <|"GITHUB_EVENT_NAME" -> "release"|>,
			<|"GITHUB_REF_TYPE" -> "branch"|>, <|"GITHUB_REF" -> "refs/heads/v0.1.0"|>,
			<|"GITHUB_REF_NAME" -> "v0.2.0", "GITHUB_REF" -> "refs/tags/v0.2.0"|>
		}
	],
	ConstantArray[1, 7],
	TestID -> "Release: branches, PRs, and mismatched tags cannot publish"
]

VerificationTest[
	Block[{Print = (Null &)},
		Catch[releaseTag[Join[releaseEnvironment, <|"GITHUB_REF_NAME" -> "v" <> #, "GITHUB_REF" -> "refs/tags/v" <> #|>], #], "exit"] & /@
			{"01.2.3", "1.2", "1.2.3-rc1", "1.2.3.4", "1.2.3\n", "1.2.3+build"}
	],
	ConstantArray[1, 6],
	TestID -> "Release: malformed or prerelease version tags cannot publish"
]

VerificationTest[
	Block[{Print = (Null &)}, Catch[releaseTag[<||>, "0.1.0"], "exit"]],
	1,
	TestID -> "Release: local runs without workflow metadata cannot publish"
]

VerificationTest[
	Module[{directory = CreateDirectory[], info, environment, results = {}, verify},
		info = FileNameJoin[{directory, "PARILink", "PacletInfo.wl"}];
		CreateDirectory[DirectoryName[info]];
		Export[info, "PacletObject[<|\"Name\" -> \"WolframInstitute/PARILink\", \"Version\" -> \"0.1.0\"|>]", "Text"];
		WithCleanup[
			Null,
			Block[{root = directory, pacletDirectory = DirectoryName[info], Print = (Null &)},
				git["init", "--quiet", "--initial-branch=main"];
				git["config", "user.name", "PARILink tests"];
				git["config", "user.email", "tests@example.invalid"];
				git["add", "."];
				git["-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "test(release): create a fixture"];
				git["-c", "tag.gpgsign=false", "tag", "v0.1.0"];
				git["update-ref", "refs/remotes/origin/main", "HEAD"];
				environment = Append[releaseEnvironment, "GITHUB_SHA" -> gitText["rev-parse", "HEAD"]];
				verify[] := AppendTo[results, Catch[checkRelease[environment]; True, "exit"]];
				verify[];
				Export[FileNameJoin[{directory, "untracked.txt"}], "uncommitted", "Text"];
				verify[];
				DeleteFile[FileNameJoin[{directory, "untracked.txt"}]];
				Export[info, Import[info, "Text"] <> "\n(* changed *)\n", "Text"];
				verify[];
				git["add", "."];
				git["-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "test(release): change the fixture"];
				verify[];
				git["-c", "tag.gpgsign=false", "tag", "--force", "v0.1.0"];
				verify[];
				environment["GITHUB_SHA"] = gitText["rev-parse", "HEAD"];
				verify[];
				git["update-ref", "refs/remotes/origin/main", "HEAD"];
				verify[];
				results
			],
			DeleteDirectory[directory, DeleteContents -> True]
		]
	],
	{True, 1, 1, 1, 1, 1, True},
	TestID -> "Release: verify tag, workflow commit, clean checkout, and main ancestry in Git"
]

VerificationTest[
	Internal`InheritedBlock[{RunProcess},
		Unprotect[RunProcess];
		DownValues[RunProcess] = Prepend[DownValues[RunProcess],
			HoldPattern[RunProcess[arguments : {"wolframscript", ___String}, property_, environment_Rule]] :>
				{arguments, property, Lookup[Last[environment], "WOLFRAMSCRIPT_KERNELPATH"],
					KeyDrop[Last[environment], "WOLFRAMSCRIPT_KERNELPATH"] ===
						KeyDrop[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH"]}];
		Protect[RunProcess];
		withEntitledKernels[RunProcess[{"/path with spaces/WolframKernel", "-noprompt", "-script", "/tmp/build.wl"}, "ExitCode"]]
	],
	{{"wolframscript", "-file", "/tmp/build.wl"}, "ExitCode", "/path with spaces/WolframKernel", True},
	TestID -> "Build: synchronous child kernels use the entitlement launcher"
]

VerificationTest[
	Internal`InheritedBlock[{StartProcess},
		Unprotect[StartProcess];
		DownValues[StartProcess] = Prepend[DownValues[StartProcess],
			HoldPattern[StartProcess[arguments : {"wolframscript", ___String}, directory_Rule, environment_Rule]] :>
				{arguments, directory, Lookup[Last[environment], "WOLFRAMSCRIPT_KERNELPATH"],
					KeyDrop[Last[environment], "WOLFRAMSCRIPT_KERNELPATH"] ===
						KeyDrop[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH"]}];
		Protect[StartProcess];
		withEntitledKernels[StartProcess[{"/path with spaces/WolframKernel", "-noprompt", "-script", "/tmp/build.wl"},
			ProcessDirectory -> "/tmp"]]
	],
	{{"wolframscript", "-file", "/tmp/build.wl"}, ProcessDirectory -> "/tmp", "/path with spaces/WolframKernel", True},
	TestID -> "Build: asynchronous child kernels keep their environment and options"
]

VerificationTest[
	Module[{file = CreateTemporary[], kernel, result},
		kernel = SelectFirst[FileNameJoin[Prepend[#, $InstallationDirectory]] & /@
			{{"MacOS", "WolframKernel"}, {"Executables", "WolframKernel"}, {"Executables", "WolframKernel.exe"}}, FileExistsQ];
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
