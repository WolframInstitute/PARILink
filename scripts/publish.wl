(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{CheckRelease, PublishPaclet}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{releaseTag, gitCommand, gitText}];

(* ::Section:: *)
(*Usage Messages*)

CheckRelease::usage = "CheckRelease[] checks that this is a release-tag workflow in GitHub Actions whose tag matches PacletInfo.wl, points to HEAD, \
is on main and has no uncommitted changes. It gives the tag, and stops the current task when a check fails.\n\
CheckRelease[environment] reads the workflow variables from the association environment and not from the process.";
PublishPaclet::usage = "PublishPaclet[] publishes the verified build of a release with PacletPage: the paclet resource and the documentation \
site. It refuses anything but a release-tag workflow, and connects to the Wolfram Cloud with WOLFRAM_CLOUD_USER and WOLFRAM_CLOUD_PASSWORD.";
$releaseTagPattern::usage = "$releaseTagPattern is the pattern of a release tag: v, then MAJOR.MINOR.PATCH without leading zeros.";
releaseWorkflowQ::usage = "releaseWorkflowQ[environment] gives True when the association environment describes a GitHub Actions workflow that \
runs for a tag, after a push or when started by hand.";
matchingTagQ::usage = "matchingTagQ[tag, environment, version] gives True when tag is a release tag for the version and the workflow of the \
association environment runs for that tag.";
releaseTag::usage = "releaseTag[environment, version] gives the tag of the release-tag workflow that the association environment describes, and \
stops the current task when the workflow is not one or its tag does not match the version.";
gitCommand::usage = "gitCommand[arguments] runs git in the repository with the given string arguments and gives the result of RunProcess.";
gitText::usage = "gitText[arguments] gives the output of the git command with the given string arguments, and stops the current task when git fails.";

(* ::Section:: *)
(*Function Definitions*)

$releaseTagPattern = RegularExpression["v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)"];

releaseWorkflowQ[environment_Association] :=
	And[
		Lookup[environment, {"GITHUB_ACTIONS", "GITHUB_REF_TYPE"}] === {"true", "tag"},
		MemberQ[{"push", "workflow_dispatch"}, Lookup[environment, "GITHUB_EVENT_NAME"]]
	]
releaseWorkflowQ[___] := False

matchingTagQ[tag_String, environment_Association, version_String] :=
	And[
		StringMatchQ[tag, $releaseTagPattern],
		tag === "v" <> version,
		Lookup[environment, "GITHUB_REF"] === "refs/tags/" <> tag
	]
matchingTagQ[___] := False

releaseTag[environment_Association, version_String] :=
	Module[{tag},
		tag = Lookup[environment, "GITHUB_REF_NAME", ""];
		RequireOrLog[environment, releaseWorkflowQ, "Publishing requires a release-tag workflow in GitHub Actions"];
		RequireOrLog[tag, matchingTagQ[#, environment, version] &, "The release tag must be vX.Y.Z matching PacletInfo.wl"]
	]

gitCommand[arguments__String] := RunProcess[{"git", "-C", $RepositoryRoot, arguments}]

gitText[arguments__String] :=
	Module[{result},
		result = gitCommand[arguments];
		RequireOrLog[result, AssociationQ[#] && #["ExitCode"] === 0 &, "Git could not verify the release checkout"];
		StringTrim[result["StandardOutput"]]
	]

CheckRelease[environment_Association] :=
	Module[{tag, commit, ancestorCheck},
		tag = releaseTag[environment, PacletObject[File[$PacletDirectory]]["Version"]];
		commit = gitText["rev-parse", "HEAD"];
		RequireOrLog[gitText["rev-parse", "refs/tags/" <> tag <> "^{commit}"], # === commit &, "The tag does not point to HEAD"];
		RequireOrLog[Lookup[environment, "GITHUB_SHA"], StringQ, "The workflow commit is missing"];
		RequireOrLog[gitText["rev-parse", environment["GITHUB_SHA"] <> "^{commit}"], # === commit &, "The checkout differs from the workflow commit"];
		ancestorCheck = gitCommand["merge-base", "--is-ancestor", "HEAD", "origin/main"];
		RequireOrLog[ancestorCheck["ExitCode"], # === 0 &, "The release commit is not on main"];
		RequireOrLog[gitText["status", "--porcelain"], # === "" &, "The release checkout has uncommitted changes"];
		LogInfo["OK: release tag ", tag];
		tag
	]
CheckRelease[] := CheckRelease[Association[GetEnvironment[]]]
CheckRelease[___] := invalidArgumentsFailure[CheckRelease]

(* CloudConnect can print a message and still connect, so its messages go to the log and only the connection is
   required. *)
PublishPaclet[] :=
	Module[{account, password, connection, result},
		CheckRelease[];
		account = environmentSetting["WOLFRAM_CLOUD_USER"];
		password = environmentSetting["WOLFRAM_CLOUD_PASSWORD"];
		CheckBuild[];
		connection = CloudConnect[account, password];
		RequireOrLog[$CloudConnected, TrueQ, "Could not connect to the publishing account: ", connection];
		result = pageCall[
			"PublishPacletPage", $PacletDirectory, "PARILink",
			"Account" -> account,
			"Build" -> False,
			"ResourceOptions" -> {"Build" -> False, "Parallel" -> False},
			"Monitor" -> True
		];
		RequireOrLog[result, AssociationQ, "PacletPage publication failed"];
		RequireOrLog[result["Resource"]["Deployed"], TrueQ, "PacletPage publication failed"];
		RequireOrLog[result["Check"]["OK"], TrueQ, "The published documentation site did not pass its checks"];
		LogInfo["OK: published ", result["Resource"]["Resource"]];
		LogInfo[result["Site"]["Site"]]
	]
PublishPaclet[___] := invalidArgumentsFailure[PublishPaclet]
