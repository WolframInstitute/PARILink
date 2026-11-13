(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{
	$RepositoryRoot, $ScriptsDirectory, $PacletName, $PacletDirectory, $DocumentationDirectory, $GitHubActionsQ, $ScriptCommand, $ScriptArguments,
	LogInfo, LogWarning, LogError, RepositoryPath, ErrorCount, FinishScript, RunScript, LoadPaclet
}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{
	RequireOrLog, RunTask, failTask, requireNoErrors, taskFailureQ, quietCheck, environmentSetting, pariLinkFunction, invalidArgumentsFailure
}];

(* ::Section:: *)
(*Usage Messages*)

$RepositoryRoot::usage = "$RepositoryRoot is the repository directory.";
$ScriptsDirectory::usage = "$ScriptsDirectory is the directory of the development scripts.";
$PacletName::usage = "$PacletName is the full paclet name.";
$PacletDirectory::usage = "$PacletDirectory is the paclet source directory.";
$DocumentationDirectory::usage = "$DocumentationDirectory is the directory of the documentation pages, docs/en.";
$GitHubActionsQ::usage = "$GitHubActionsQ indicates whether GitHub Actions is running.";
$ScriptCommand::usage = "$ScriptCommand is the project command named on the command line, or \"all\" when none is named.";
$ScriptArguments::usage = "$ScriptArguments lists the command-line arguments after the project command.";
LogInfo::usage = "LogInfo[parts] prints information. Each of the parts is a string or any expression, which prints in InputForm.";
LogWarning::usage = "LogWarning[parts] prints a warning.\n\
LogWarning[location, parts] prints a warning for the file and position that the association location names.";
LogError::usage = "LogError[parts] prints an error and marks the script as failed.\n\
LogError[location, parts] prints an error for the file and position that the association location names. location has the key \"File\" and may \
have the keys \"Line\" and \"Column\". On GitHub Actions the error becomes an ::error file=...:: annotation.";
RepositoryPath::usage = "RepositoryPath[file] gives a path relative to the repository.";
ErrorCount::usage = "ErrorCount[] gives the number of logged errors.";
FinishScript::usage = "FinishScript[] exits with a status determined by logged errors.";
RunScript::usage = "RunScript[command] runs command[] and exits with its logged status. command is a symbol or a pure function.";
LoadPaclet::usage = "LoadPaclet[] loads the paclet from source and gives the paclet object. It stops the current task when the paclet cannot be \
read or loaded.";
RequireOrLog::usage = "RequireOrLog[value, test, parts] returns value when test[value] gives True. Otherwise it logs parts as an error and stops \
the current task with a Failure. test is a function.";
RunTask::usage = "RunTask[body] evaluates body until a required value fails, and gives its value, or the Failure that RequireOrLog threw.";
failTask::usage = "failTask[parts] logs parts as an error and stops the current task with a Failure that has the tag \"ScriptTaskFailure\".";
requireNoErrors::usage = "requireNoErrors[] stops the current task when an error has been logged, so that a command with several steps ends at \
the first step that fails.";
taskFailureQ::usage = "taskFailureQ[result] gives True when result is the Failure of a stopped task.";
quietCheck::usage = "quietCheck[expression] evaluates expression without printing its messages and gives its value, or a Failure with the tag \
\"MessageFailure\" when it issued a message.";
pariLinkFunction::usage = "pariLinkFunction[name] gives the public PARILink symbol of the given name. The scripts load the paclet while they run, \
so they cannot name its symbols when they are read.";
environmentSetting::usage = "environmentSetting[name] gives the value of an environment variable, and stops the current task when it is not set.";
invalidArgumentsFailure::usage = "invalidArgumentsFailure[function] issues the message function::args and gives the Failure that a script command \
returns for arguments that match none of its definitions. The Failure has the tag \"InvalidArguments\".";
normalizePath::usage = "normalizePath[path] gives the absolute path with the separators of this platform.";
$errorCount::usage = "$errorCount is the number of errors logged so far.";
toText::usage = "toText[expression] gives expression itself when it is a string, and its InputForm text otherwise.";
joinText::usage = "joinText[parts] joins the text of the parts, as toText gives it.";
locationQ::usage = "locationQ[expression] gives True when expression is an association with the key \"File\".";
escapeData::usage = "escapeData[text] escapes the characters of a GitHub Actions message that the runner reads as markup.";
escapeProperty::usage = "escapeProperty[text] escapes the characters of a GitHub Actions annotation property.";
locationProperties::usage = "locationProperties[location] gives the properties file=..., line=... and col=... of an annotation, as one string.";
locationText::usage = "locationText[location] gives the text file:line:column: that starts a local log line.";
emit::usage = "emit[command, label, location, parts] prints a log line. On GitHub Actions it is the workflow command ::command::, and elsewhere a \
line that starts with label. location is an association or None.";
log::usage = "log[command, label, parts] prints a log line, with the location when the first of the parts is an association with a \"File\" key.";

(* ::Section:: *)
(*Function Definitions*)

normalizePath[path_String] := FileNameJoin @ FileNameSplit @ ExpandFileName[path]

$RepositoryRoot = normalizePath @ DirectoryName[ExpandFileName[$InputFileName], 2];
$ScriptsDirectory = FileNameJoin[{$RepositoryRoot, "scripts"}];
$PacletName = "WolframInstitute/PARILink";
$PacletDirectory = FileNameJoin[{$RepositoryRoot, "PARILink"}];
$DocumentationDirectory = FileNameJoin[{$RepositoryRoot, "docs", "en"}];
$GitHubActionsQ = Environment["GITHUB_ACTIONS"] === "true";
$ScriptCommand = Replace[$ScriptCommandLine, {{_, command_String, ___} :> command, _ -> "all"}];
$ScriptArguments = Replace[$ScriptCommandLine, {{_, _, rest___} :> {rest}, _ -> {}}];

(* normalizePath joins with $PathnameSeparator, a backslash on Windows, so strip that separator and not a literal "/". *)
RepositoryPath[file_String] := StringDelete[normalizePath[file], StartOfString ~~ $RepositoryRoot ~~ $PathnameSeparator]
RepositoryPath[___] := invalidArgumentsFailure[RepositoryPath]

$errorCount = 0;

toText[text_String] := text
toText[expression_] := ToString[expression, InputForm]
joinText[parts___] := StringJoin[toText /@ {parts}]

locationQ[candidate_Association] := KeyExistsQ[candidate, "File"]
locationQ[___] := False

escapeData[text_String] := StringReplace[text, {"%" -> "%25", "\r" -> "%0D", "\n" -> "%0A"}]
escapeProperty[text_String] := StringReplace[text, {"%" -> "%25", "\r" -> "%0D", "\n" -> "%0A", ":" -> "%3A", "," -> "%2C"}]

locationProperties[sourceLocation_Association] :=
	StringRiffle[
		DeleteMissing @ {
			"file=" <> escapeProperty[RepositoryPath[sourceLocation["File"]]],
			If[IntegerQ[sourceLocation["Line"]], "line=" <> ToString[sourceLocation["Line"]], Missing[]],
			If[IntegerQ[sourceLocation["Column"]], "col=" <> ToString[sourceLocation["Column"]], Missing[]]
		},
		","
	]

locationText[sourceLocation_Association] :=
	StringJoin[
		RepositoryPath[sourceLocation["File"]],
		If[IntegerQ[sourceLocation["Line"]], ":" <> ToString[sourceLocation["Line"]], ""],
		If[IntegerQ[sourceLocation["Column"]], ":" <> ToString[sourceLocation["Column"]], ""],
		": "
	]

emit[command_String, label_String, sourceLocation : (_Association | None), parts___] :=
	Print @ If[$GitHubActionsQ,
		StringJoin["::", command, If[locationQ[sourceLocation], " " <> locationProperties[sourceLocation], ""], "::", escapeData[joinText[parts]]],
		StringJoin[label, ": ", If[locationQ[sourceLocation], locationText[sourceLocation], ""], joinText[parts]]
	]

log[command_String, label_String, sourceLocation_?locationQ, parts___] := emit[command, label, sourceLocation, parts]
log[command_String, label_String, parts___] := emit[command, label, None, parts]

(* Any expression is a valid part: it prints in InputForm. So a call never gives a Failure. *)
(* allow MissingCatchAll: every sequence of parts is valid, so there is no invalid call to catch *)
LogInfo[parts___] := Print[joinText[parts]]
(* allow MissingCatchAll: every sequence of parts is valid, so there is no invalid call to catch *)
LogWarning[parts___] := log["warning", "WARNING", parts]
(* allow MissingCatchAll: every sequence of parts is valid, so there is no invalid call to catch *)
LogError[parts___] := (
	$errorCount++;
	log["error", "ERROR", parts]
)

(* A task that cannot go on throws this Failure to RunTask, which gives it back as the value of the task. *)
failTask[parts___] := (
	If[{parts} =!= {}, LogError[parts]];
	Throw[
		Failure["ScriptTaskFailure", <|"MessageTemplate" -> "a required value failed its test: `1`", "MessageParameters" -> {joinText[parts]}|>],
		"ScriptTaskFailure"
	]
)

(* allow BarePattern: value is any expression, and test is any function that takes it *)
RequireOrLog[value_, test_, parts___] := If[TrueQ[test[value]], value, failTask[parts]]

SetAttributes[RunTask, HoldFirst];
(* allow BarePattern: body is any expression, held until the catch is in place *)
RunTask[body_] := Catch[body, "ScriptTaskFailure"]

taskFailureQ[Failure["ScriptTaskFailure", _Association]] := True
taskFailureQ[___] := False

requireNoErrors[] := If[$errorCount > 0, failTask[]]

(* Any message means that the step did not work, whichever function issued it, so every message is quieted and checked. *)
SetAttributes[quietCheck, HoldFirst];
(* allow BarePattern: expression is any expression, held until Quiet and Check are in place *)
quietCheck[expression_] := Quiet[Check[expression, Failure["MessageFailure", <|"MessageTemplate" -> "The evaluation issued a message."|>]], All]

pariLinkFunction[name_String] := Symbol["WolframInstitute`PARILink`" <> name]

ErrorCount[] := $errorCount
ErrorCount[___] := invalidArgumentsFailure[ErrorCount]

FinishScript[] :=
	If[$errorCount > 0,
		Print["\nFAILED: ", $errorCount, " error(s)."];
		Exit[1],

		Exit[0]
	]
FinishScript[___] := invalidArgumentsFailure[FinishScript]

RunScript[command : (_Symbol | _Function)] := (
	command[];
	FinishScript[]
)
RunScript[___] := invalidArgumentsFailure[RunScript]

environmentSetting[name_String] := RequireOrLog[Environment[name], StringQ[#] && StringTrim[#] =!= "" &, name, " is not set"]

LoadPaclet[] :=
	Module[{paclet, context, loaded},
		paclet = quietCheck[PacletObject[File[$PacletDirectory]]];
		RequireOrLog[paclet, PacletObjectQ, "Cannot read ", $PacletDirectory];
		PacletDirectoryLoad[$PacletDirectory];
		context = paclet["PrimaryContext"];
		loaded = Check[Needs[context], Failure["NeedsFailure", <|"MessageTemplate" -> "Needs generated messages."|>]];
		RequireOrLog[loaded, !FailureQ[#] &, "Cannot load ", context];
		paclet
	]
LoadPaclet[___] := invalidArgumentsFailure[LoadPaclet]

(* The same catch-all as in the paclet: every exported command ends with Name[___] := invalidArgumentsFailure[Name]. *)
invalidArgumentsFailure[function_Symbol] := (
	Message[MessageName[function, "args"], function];
	Failure["InvalidArguments", <|"MessageTemplate" -> MessageName[function, "args"], "MessageParameters" -> {function}|>]
)
