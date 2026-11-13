(* ::Package:: *)

PackageImport["CodeInspector`"]
PackageImport["CodeParser`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[{LintFiles, $LintMinimumConfidence}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[lintFiles];

(* ::Section:: *)
(*Usage Messages*)

LintFiles::usage = "LintFiles[files] checks the Wolfram Language files, a list of paths, with CodeInspector and against the coding guides.\n\
LintFiles[file] checks one file.";
lintFiles::usage = "lintFiles[files] checks the files, a list of paths, with CodeInspector.";
$LintMinimumConfidence::usage = "$LintMinimumConfidence is the minimum reported confidence.";
plainMessage::usage = "plainMessage[message] gives the text of a CodeInspector message, without the backtick pairs that mark its parameters.";
issueLocation::usage = "issueLocation[file, data] gives the association with the keys \"File\", \"Line\" and \"Column\" of a CodeInspector issue, \
with no line or column when the issue has no source position.";
reportIssue::usage = "reportIssue[file, issue] logs a CodeInspector issue of the file: an error for a fatal issue or an error, a warning for a \
warning or a scoping issue, and information otherwise.";
confidentQ::usage = "confidentQ[issue] gives True when the confidence of a CodeInspector issue is at least $LintMinimumConfidence.";
lintFile::usage = "lintFile[file] logs the CodeInspector issues of one file, and stops the task with a Failure when the file is missing or cannot \
be inspected.";

(* ::Section:: *)
(*Function Definitions*)

$LintMinimumConfidence = .75;

plainMessage[message_String] := StringReplace[message, "``" -> ""]
plainMessage[message_] := ToString[message]

issueLocation[file_String, data_Association] :=
	Replace[
		Lookup[data, Source, None],
		{
			{{line_Integer, column_Integer}, ___} :> <|"File" -> file, "Line" -> line, "Column" -> column|>,
			_ :> <|"File" -> file|>
		}
	]

reportIssue[file_String, InspectionObject[tag_, message_, severity_, data_Association]] :=
	Module[{sourceLocation, text},
		sourceLocation = issueLocation[file, data];
		text = StringJoin[ToString[tag], " (", ToString[severity], "): ", plainMessage[message]];
		Switch[severity,
			"Fatal" | "Error",
				LogError[sourceLocation, text],
			"Warning" | "Scoping",
				LogWarning[sourceLocation, text],
			_,
				LogInfo[
					"  ", RepositoryPath[file],
					Replace[Lookup[sourceLocation, "Line", None], {line_Integer :> ":" <> ToString[line], _ -> ""}],
					": ", text
				]
		]
	]
reportIssue[file_String, result_] := LogWarning[<|"File" -> file|>, "unrecognized CodeInspector result: ", result]

confidentQ[InspectionObject[_, _, _, data_Association]] := Lookup[data, ConfidenceLevel, 1.] >= $LintMinimumConfidence
confidentQ[_] := True

lintFile[file_String] :=
	RunTask @ Module[{issues, confidentIssues},
		RequireOrLog[FileExistsQ[file], TrueQ, "file not found: ", file];
		issues = CodeInspect[File[file]];
		RequireOrLog[issues, ListQ, <|"File" -> file|>, "CodeInspect failed: ", issues];
		confidentIssues = Select[issues, confidentQ];
		Scan[reportIssue[file, #] &, confidentIssues];
		LogInfo[
			"  ", RepositoryPath[file], ": ", Length[confidentIssues],
			" issue(s) at confidence >= ", $LintMinimumConfidence
		]
	]

lintFiles[files : {___String}] := Scan[lintFile, files]

LintFiles[files : {___String}] := (
	lintFiles[files];
	CheckStyle[files];
	Null
)
LintFiles[file_String] := LintFiles[{file}]
LintFiles[___] := invalidArgumentsFailure[LintFiles]
