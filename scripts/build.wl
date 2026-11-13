(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{BuildPaclet, BuildDocumentation, CheckBuild, RunCI, RunCIBuild}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{loadPublishing, pageCall, withEntitledKernels, checkArchive, checkRuntime, buildInputFiles, buildFingerprint}];

(* ::Section:: *)
(*Usage Messages*)

BuildPaclet::usage = "BuildPaclet[] builds the documentation and the paclet archive with PacletPage, without a cloud connection, and checks the \
archive: that it loads in a fresh kernel, holds every documentation page and runs its own GP. The documentation examples are evaluated with GP.";
BuildDocumentation::usage = "BuildDocumentation[] builds the documentation notebooks with PacletPage, without the archive.";
CheckBuild::usage = "CheckBuild[] checks the archive that PacletPage built, without building it again, and gives the result of PacletPage.";
RunCI::usage = "RunCI[] runs the checks, the tests without GP and the tests with GP, in this one kernel.";
RunCIBuild::usage = "RunCIBuild[] runs the checks, the tests without GP, the tests with GP and the paclet build, in this one kernel.";
loadPublishing::usage = "loadPublishing[] loads the pinned PacletPage tools under .deps and gives the options for a documentation build.";
entitlementQ::usage = "entitlementQ[] gives True when WOLFRAMSCRIPT_ENTITLEMENTID is set, as it can be in continuous integration.";
entitledEnvironment::usage = "entitledEnvironment[kernel] gives the environment of the current process with WOLFRAMSCRIPT_KERNELPATH set to the \
kernel.";
kernelLauncherQ::usage = "kernelLauncherQ[command] gives True when the command is a path to a WolframKernel executable.";
entitledRunProcess::usage = "entitledRunProcess[kernel, file, arguments] runs the script file with wolframscript, for the kernel, and gives the \
process result.";
entitledStartProcess::usage = "entitledStartProcess[kernel, file, options] starts the script file with wolframscript, for the kernel, with the \
options.";
$runProcessOverride::usage = "$runProcessOverride is the rule that has RunProcess start a WolframKernel script through wolframscript.";
$startProcessOverride::usage = "$startProcessOverride is the rule that has StartProcess start a WolframKernel script through wolframscript.";
setLauncherDownValues::usage = "setLauncherDownValues[runDownValues, startDownValues] sets the definitions of RunProcess and StartProcess.";
withEntitledKernels::usage = "withEntitledKernels[body] evaluates body with the launch of WolframKernel scripts by RunProcess and StartProcess \
replaced by wolframscript, so that a fresh kernel finds the on-demand entitlement. It restores both functions afterwards. Other processes, GP \
among them, start as usual.";
pacletPageFunction::usage = "pacletPageFunction[name] gives the PacletPage function of the given name, once PacletPage is loaded.";
pageCall::usage = "pageCall[name, arguments] calls the PacletPage function name with the arguments, through entitled kernels when an entitlement \
is set.";
checkRuntime::usage = "checkRuntime[command, path] runs the command \"check\" or \"check-archive\" of scripts/runtime.py on a runtime directory or \
an archive, for every system when PARILINK_REQUIRE_ALL_RUNTIMES is 1. It stops the current task when the runtime does not pass.";
checkArchive::usage = "checkArchive[result] checks the result that PacletPage gave for an archive: its fresh-kernel load check, its documentation \
and its bundled GP. It stops the current task when a check fails.";
buildInputFiles::usage = "buildInputFiles[] lists the files that decide whether a build can reuse the documentation cache: the scripts, the \
paclet metadata, the kernel, the resources and the guide pages. A reference page is not among them, because PacletPage tracks each page itself.";
buildFingerprint::usage = "buildFingerprint[runtime] gives a hash of the build inputs, the Wolfram version, the system and runtime, the list \
{version, hash} of the GP that evaluates the documentation examples.";
prepareBuild::usage = "prepareBuild[] checks the staged runtime, loads the paclet and starts GP once. It gives an association with the \
\"Fingerprint\" of the build inputs, the \"Stamp\" file that records it, and whether the build is \"Incremental\". A build that is not \
incremental starts without the documentation cache.";

(* ::Section:: *)
(*Function Definitions*)

loadPublishing[] :=
	Module[{page, parser, converter},
		page = FileNameJoin[{$RepositoryRoot, ".deps", "PacletPage"}];
		parser = FileNameJoin[{$RepositoryRoot, ".deps", "WolframParser", "Parser"}];
		converter = FileNameJoin[{$RepositoryRoot, ".deps", "MarkdownToNotebook", "MarkdownToNotebook.wl"}];
		Scan[
			RequireOrLog[#, FileExistsQ, "Run make deps to fetch the pinned documentation tools; missing ", #] &,
			{FileNameJoin[{page, "PacletInfo.wl"}], FileNameJoin[{parser, "PacletInfo.wl"}], converter}
		];
		PacletDirectoryLoad[page];
		PacletDirectoryLoad[parser];
		Needs["Wolfram`Parser`"];
		Needs["WolframInstitute`PacletPage`"];
		{
			"Source" -> $DocumentationDirectory,
			"Definition" -> FileNameJoin[{$RepositoryRoot, "docs", "ResourceDefinition.md"}],
			"Converter" -> converter,
			"Dependencies" -> {parser},
			"Parallel" -> False,
			"TimeConstraint" -> 180,
			"Prune" -> True
		}
	]

entitlementQ[] := StringQ[Environment["WOLFRAMSCRIPT_ENTITLEMENTID"]] && Environment["WOLFRAMSCRIPT_ENTITLEMENTID"] =!= ""

(* PacletPage starts its build and archive checks with WolframKernel -script. An on-demand entitlement belongs to
   wolframscript, so with an entitlement those processes must use that launcher. The overrides last only for the
   PacletPage call. *)
kernelLauncherQ[command_String] := FileBaseName[command] === "WolframKernel"

entitledEnvironment[kernel_String] := Append[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH" -> kernel]

entitledRunProcess[kernel_String, file_String, arguments___] :=
	RunProcess[{"wolframscript", "-file", file}, arguments, ProcessEnvironment -> entitledEnvironment[kernel]]

entitledStartProcess[kernel_String, file_String, options___] :=
	StartProcess[{"wolframscript", "-file", file}, options, ProcessEnvironment -> entitledEnvironment[kernel]]

$runProcessOverride = HoldPattern[RunProcess[{kernel_String, "-noprompt", "-script", file_String}, arguments___] /; kernelLauncherQ[kernel]] :> entitledRunProcess[kernel, file, arguments];

$startProcessOverride = HoldPattern[StartProcess[{kernel_String, "-noprompt", "-script", file_String}, options___] /; kernelLauncherQ[kernel]] :> entitledStartProcess[kernel, file, options];

setLauncherDownValues[runDownValues_List, startDownValues_List] := (
	Unprotect[RunProcess, StartProcess];
	DownValues[RunProcess] = runDownValues;
	DownValues[StartProcess] = startDownValues;
	Protect[RunProcess, StartProcess]
)

SetAttributes[withEntitledKernels, HoldFirst];
(* allow BarePattern: body is any expression, held until the overrides are in place *)
withEntitledKernels[body_] :=
	Module[{savedRunProcess, savedStartProcess},
		savedRunProcess = DownValues[RunProcess];
		savedStartProcess = DownValues[StartProcess];
		WithCleanup[
			setLauncherDownValues[Prepend[savedRunProcess, $runProcessOverride], Prepend[savedStartProcess, $startProcessOverride]],
			body,
			setLauncherDownValues[savedRunProcess, savedStartProcess]
		]
	]

pacletPageFunction[name_String] := Symbol["WolframInstitute`PacletPage`" <> name]

pageCall[name_String, arguments___] :=
	If[entitlementQ[],
		withEntitledKernels[pacletPageFunction[name][arguments]],

		pacletPageFunction[name][arguments]
	]

checkRuntime[command : ("check" | "check-archive"), path_String] :=
	Module[{allSystems, result},
		allSystems = If[Environment["PARILINK_REQUIRE_ALL_RUNTIMES"] === "1", {"--all"}, {}];
		result = RunProcess[Join[{"python3", FileNameJoin[{$ScriptsDirectory, "runtime.py"}], command, path}, allSystems]];
		LogInfo[result["StandardOutput"]];
		RequireOrLog[result["ExitCode"], # === 0 &, "Bundled runtime check failed. Run make runtime stage-runtime. ", result["StandardError"]]
	]

checkArchive[result_Association] :=
	Module[{resource},
		resource = result["Resource"];
		RequireOrLog[resource["Load"]["OK"], TrueQ, "The archive failed its fresh-kernel load check"];
		RequireOrLog[resource["Documentation"]["Missing"], # === {} &, "The archive is missing documentation pages"];
		RequireOrLog[resource["Documentation"]["Flagged"], # === <||> &, "The archive has invalid documentation pages"];
		LogInfo["OK: ", resource["Pages"], " documentation pages; archive loads cleanly"];
		checkRuntime["check-archive", resource["Archive"]];
		LogInfo[resource["Archive"]]
	]
checkArchive[result_] := failTask["PacletPage build failed: ", result]

(* PacletPage tracks each page. Its own hash of the code does not include GP or the Resources directory, so the
   caches are reset when one of these files changes. *)
buildInputFiles[] :=
	Sort @ Select[
		Join[
			FileNames["*", FileNameJoin[{$RepositoryRoot, "scripts"}]],
			{FileNameJoin[{$PacletDirectory, "PacletInfo.wl"}]},
			FileNames["*", FileNameJoin[{$PacletDirectory, "Kernel"}], Infinity],
			FileNames["*", FileNameJoin[{$PacletDirectory, "Resources"}], Infinity],
			FileNames["*", FileNameJoin[{$DocumentationDirectory, "Guides"}], Infinity]
		],
		FileType[#] === File &
	]

buildFingerprint[runtime : {_String, _String}] :=
	Module[{rootDepth, fileHashes},
		rootDepth = Length[FileNameSplit[$RepositoryRoot]];
		fileHashes = Map[Function[file, {FileNameDrop[file, rootDepth], FileHash[file, "SHA256", "HexString"]}], buildInputFiles[]];
		Hash[{$Version, $SystemID, runtime, fileHashes}, "SHA256", "HexString"]
	]

prepareBuild[] :=
	Module[{session, runtime, fingerprint, stamp, incrementalQ, cache},
		checkRuntime["check", FileNameJoin[{$PacletDirectory, "Resources", "Runtime"}]];
		LoadPaclet[];
		session = pariLinkFunction["StartPARISession"][];
		RequireOrLog[session, !FailureQ[#] &, "GP is required to evaluate documentation examples: ", session];
		runtime = WithCleanup[{session["Version"], FileHash[session["Executable"], "SHA256", "HexString"]}, DeleteObject[session]];
		fingerprint = buildFingerprint[runtime];
		stamp = FileNameJoin[{$PacletDirectory, "build", "build-context.txt"}];
		incrementalQ = FileExistsQ[stamp] && StringTrim[ReadString[stamp]] === fingerprint;
		cache = FileNameJoin[{$PacletDirectory, "build", "cache"}];
		If[!incrementalQ && DirectoryQ[cache], DeleteDirectory[cache, DeleteContents -> True]];
		<|"Fingerprint" -> fingerprint, "Stamp" -> stamp, "Incremental" -> incrementalQ|>
	]

BuildPaclet[] :=
	Module[{options, buildContext, result},
		options = loadPublishing[];
		buildContext = prepareBuild[];
		result = Block[{$CloudConnected = False},
			pageCall[
				"PublishPacletPage", $PacletDirectory, "PARILink",
				"DryRun" -> True,
				"BuildOptions" -> options,
				"ResourceOptions" -> {"Parallel" -> False, "Incremental" -> buildContext["Incremental"]},
				"Monitor" -> True
			]
		];
		RequireOrLog[result, AssociationQ, "PacletPage build failed"];
		RequireOrLog[Lookup[result["Build"], "Failed", None], # === {} &, "Documentation pages failed to build"];
		RequireOrLog[Lookup[result["Build"], "Unevaluated", None], # === <||> &, "Documentation examples did not evaluate"];
		checkArchive[result];
		Export[buildContext["Stamp"], buildContext["Fingerprint"], "Text"];
		result["Resource"]["Archive"]
	]
BuildPaclet[___] := invalidArgumentsFailure[BuildPaclet]

BuildDocumentation[] :=
	Module[{options, result},
		options = loadPublishing[];
		prepareBuild[];
		result = pageCall["BuildPacletDocumentation", $PacletDirectory, Sequence @@ options];
		RequireOrLog[result, AssociationQ, "Documentation build failed"];
		RequireOrLog[Lookup[result, "Failed", None], # === {} &, "Documentation pages failed to build"];
		LogInfo[result]
	]
BuildDocumentation[___] := invalidArgumentsFailure[BuildDocumentation]

(* PacletPage checks the archive hash and the sources before any cloud connection. *)
CheckBuild[] :=
	Module[{prepared},
		loadPublishing[];
		prepared = Block[{$CloudConnected = False},
			pageCall[
				"PublishPacletPage", $PacletDirectory, "PARILink",
				"DryRun" -> True,
				"Build" -> False,
				"ResourceOptions" -> {"Build" -> False, "Parallel" -> False}
			]
		];
		checkArchive[prepared];
		prepared
	]
CheckBuild[___] := invalidArgumentsFailure[CheckBuild]

RunCI[] := (
	CheckPaclet[];
	TestPaclet[];
	TestPARI[]
)
RunCI[___] := invalidArgumentsFailure[RunCI]

RunCIBuild[] := (
	RunCI[];
	BuildPaclet[]
)
RunCIBuild[___] := invalidArgumentsFailure[RunCIBuild]
