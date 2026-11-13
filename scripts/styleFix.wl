(* ::Package:: *)

PackageImport["CodeParser`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[{FixStyle, FixedStyleText}];

(* ::Section:: *)
(*Usage Messages*)

FixStyle::usage = "FixStyle[] rewrites the Wolfram Language files named on the command line, or every such file of the repository, \
to fix the style issues a program can fix, and gives the paths of the files it changed. With no file named, it also writes the \
table of rules in docs/coding-guides/README.md.\n\
FixStyle[files] rewrites the given files, a list of paths.\n\
It fixes indentation with spaces, spacing around operators, commas and comments, closing brackets that should start a line, \
statements that share a line, raw newlines and long lines in message strings, and the header of a paclet test file. A file is \
written only when the fixed text parses to the same code as the original. A file with no issues left is removed from \
scripts/style-legacy.txt.";
FixedStyleText::usage = "FixedStyleText[text, kind] gives the code in text with the mechanical style fixes applied, as for a file of \
the given kind, or a Failure when the fixed text would not parse to the same code.\n\
FixedStyleText[text, kind, loadDepth] also gives a paclet test file the header that loads the paclet from loadDepth directories up.";
lineOffsets::usage = "lineOffsets[lines] gives, for each line of a text, the number of characters before it.";
offsetOf::usage = "offsetOf[offsets, {line, column}] gives the number of characters before a position in a text.";
applyEdits::usage = "applyEdits[text, edits] gives text after replacing, for each edit {start, end, replacement}, the characters after \
offset start up to offset end. Edits must not overlap.";
spaceRun::usage = "spaceRun[text] gives the number of spaces and tabs at the end of a string.";
leadingRun::usage = "leadingRun[text] gives the number of spaces and tabs at the start of a string.";
tabbedLine::usage = "tabbedLine[line] gives a line with its leading whitespace as tabs, one per four columns, and without trailing whitespace.";
tabsFix::usage = "tabsFix[text] gives text with every line indented by tabs, except lines that start inside a string or a comment.";
commentFix::usage = "commentFix[text] gives text with a space inside each end of every comment that is not a notebook cell marker or title.";
tokenEdit::usage = "tokenEdit[lines, offsets, token, {before, after}] gives the edit that puts the strings before and after around a \
token, in place of the whitespace next to it. Leading indentation is kept, and nothing is added at the end of a line.";
spacingEdits::usage = "spacingEdits[source, lines] gives the edits that give each flagged operator one space on each side, each \
flagged ? and :: no space, and each flagged comma one space after it.";
spacingFix::usage = "spacingFix[text] gives text with the spacing of operators and commas fixed.";
statementEdits::usage = "statementEdits[source, lines] gives the edits that move each statement after a semicolon to its own line, for \
compound expressions whose first statement starts a line.";
statementFix::usage = "statementFix[text] gives text with one statement per line, where the indentation to use is clear.";
closerEdits::usage = "closerEdits[source, lines] gives the edits that move a closing bracket to its own line, at most one per line of text.";
closerFix::usage = "closerFix[text] gives text in which each closing bracket that should start a line does so.";
wrappedLine::usage = "wrappedLine[line, width, prefix] gives a line of string source as a list of pieces of at most width characters, \
each but the last ending in a space and a backslash; the first piece is prefix characters shorter.";
wrappedString::usage = "wrappedString[literal, column] gives the source of a string literal that starts at the given column, with raw \
newlines written as \\n\\ and lines wrapped near 150 characters.";
messageStrings::usage = "messageStrings[tree] gives the string tokens that are the value of a message definition, such as a usage message.";
messageStringEdits::usage = "messageStringEdits[source, lines] gives the edits that rewrite message strings with a raw newline or a long line.";
messageStringFix::usage = "messageStringFix[text] gives text with message strings wrapped and without raw newlines.";
loadStatement::usage = "loadStatement[depth] gives the statement that loads the paclet from depth directories above a test file.";
testHeaderFix::usage = "testHeaderFix[text, depth] gives the text of a test file with the statement that loads the paclet before its \
first Needs, or at the top when it has none. A file that has the statement is returned unchanged.";
codeSkeleton::usage = "codeSkeleton[text] gives the abstract syntax of code without source positions and with strings read as values, \
to compare two texts for equal code.";
fixPass::usage = "fixPass[text] applies each mechanical fix once.";
styleLoadDepth::usage = "styleLoadDepth[file] gives the number of directories between a paclet test file and the paclet folder, or \
None for any other file.";
prunedLegacyLines::usage = "prunedLegacyLines[lines, cleanPaths] gives the lines of the legacy list without the lines that name one of cleanPaths.";
pruneLegacyList::usage = "pruneLegacyList[files] removes from scripts/style-legacy.txt each of the given files that has no style issues left, \
and gives the repository paths it removed.";
fixStyleFile::usage = "fixStyleFile[file] rewrites one file with the mechanical fixes and gives True when it changed.";

(* ::Section:: *)
(*Function Definitions*)

lineOffsets[lines : {___String}] := Most @ FoldList[Plus, 0, StringLength[lines] + 1]

offsetOf[offsets : {___Integer}, {line_Integer, column_Integer}] := Extract[offsets, {line}] + column - 1

applyEdits[text_String, edits : {{_Integer, _Integer, _String} ...}] :=
	Fold[
		Function[{current, edit}, StringTake[current, First[edit]] <> Last[edit] <> StringDrop[current, Extract[edit, {2}]]],
		text,
		ReverseSortBy[edits, First]
	]

spaceRun[text_String] := StringLength @ StringJoin @ StringCases[text, run : (" " | "\t") ... ~~ EndOfString :> run]

leadingRun[text_String] := StringLength @ StringJoin @ StringCases[text, StartOfString ~~ run : (" " | "\t") ... :> run]

tabbedLine[line_String] :=
	Module[{leadingLength, columns},
		leadingLength = leadingRun[line];
		columns = StringLength @ StringReplace[StringTake[line, leadingLength], "\t" -> "    "];
		StringRepeat["\t", Round[columns / 4]] <> StringTrim[StringDrop[line, leadingLength], (" " | "\t") .. ~~ EndOfString]
	]

tabsFix[text_String] :=
	Module[{lines, exemptLines},
		lines = StringSplit[text, "\n", All];
		exemptLines = continuedLines[styleSource[text, "Data"]["Tokens"]];
		StringRiffle[MapIndexed[Function[{line, position}, If[MemberQ[exemptLines, First[position]], line, tabbedLine[line]]], lines], "\n"]
	]

commentFix[text_String] :=
	Module[{lines, offsets, comments, pairs, unspaced},
		lines = StringSplit[text, "\n", All];
		offsets = lineOffsets[lines];
		comments = Cases[styleSource[text, "Data"]["Tokens"], LeafNode["Comment", __]];
		pairs = Partition[Prepend[comments, None], 2, 1];
		unspaced = Cases[pairs, {previous_, comment : LeafNode["Comment", body_String, _]} /; !(cellMarkerQ[body] || cellTitleQ[previous, comment] || spacedCommentQ[body]) :> comment];
		applyEdits[
			text,
			Map[
				Function[comment,
					{offsetOf[offsets, nodeStart[comment]], offsetOf[offsets, nodeEnd[comment]], "(* " <> StringTrim[StringTake[Extract[comment, {2}], {3, -3}]] <> " *)"}
				],
				unspaced
			]
		]
	]

tokenEdit[lines : {___String}, offsets : {___Integer}, token_LeafNode, {before_String, after_String}] :=
	Module[{line, startColumn, endColumn, lineText, leftText, rightText, leftRun, rightRun, firstQ, lastQ},
		{line, startColumn} = nodeStart[token];
		endColumn = Last @ nodeEnd[token];
		lineText = Extract[lines, {line}];
		leftText = StringTake[lineText, startColumn - 1];
		rightText = StringDrop[lineText, endColumn - 1];
		leftRun = spaceRun[leftText];
		rightRun = leadingRun[rightText];
		firstQ = leftRun === StringLength[leftText];
		lastQ = rightRun === StringLength[rightText];
		{
			offsetOf[offsets, {line, If[firstQ, startColumn, startColumn - leftRun]}],
			offsetOf[offsets, {line, endColumn + rightRun}],
			If[firstQ, "", before] <> Extract[token, {2}] <> If[lastQ, "", after]
		}
	]

spacingEdits[source_Association, lines : {___String}] :=
	Module[{offsets, flaggedOperators, firstOnLine, commaWindows, flaggedCommas},
		offsets = lineOffsets[lines];
		flaggedOperators = Catenate @ Map[
			Function[node, Cases[operatorWindows[Last[node]], window : {_, token_, _} /; spacingIssue[First[node], window] =!= {} :> {First[node], token}]],
			operatorNodes[source["Concrete"]]
		];
		firstOnLine = lineStartTokens[source["Tokens"]];
		commaWindows = Cases[Partition[source["Tokens"], 3, 1], {_LeafNode, LeafNode["Comma", __], _LeafNode}];
		flaggedCommas = Cases[commaWindows, window : {_, comma_, _} /; MemberQ[Lookup[commaWindowIssues[window, firstOnLine], "Rule"], "CommaSpacing"] :> comma];
		Join[
			Map[
				Function[flagged, tokenEdit[lines, offsets, Last[flagged], If[MatchQ[First[flagged], "PatternTest" | "MessageName"], {"", ""}, {" ", " "}]]],
				flaggedOperators
			],
			Map[Function[comma, tokenEdit[lines, offsets, comma, {"", " "}]], flaggedCommas]
		]
	]

spacingFix[text_String] := applyEdits[text, DeleteDuplicates @ spacingEdits[styleSource[text, "Data"], StringSplit[text, "\n", All]]]

statementEdits[source_Association, lines : {___String}] :=
	Module[{offsets, firstOnLine, compounds, movable, pairs},
		offsets = lineOffsets[lines];
		firstOnLine = firstTokens[source["Tokens"]];
		compounds = Cases[source["Concrete"], InfixNode["CompoundExpression", children_List, _] :> children, Infinity];
		movable = Select[compounds, nodeStart[Lookup[firstOnLine, nodeLine[First[#]]]] === nodeStart[First[#]] &];
		pairs = Catenate @ Map[Function[children, Map[Function[pair, Append[pair, nodeLine[First[children]]]], sameLinePairs[children]]], movable];
		Map[
			Function[pair,
				{
					offsetOf[offsets, nodeEnd[First[pair]]],
					offsetOf[offsets, nodeStart[Extract[pair, {2}]]],
					"\n" <> lineIndentation[lines, Last[pair]]
				}
			],
			pairs
		]
	]

statementFix[text_String] := applyEdits[text, DeleteDuplicates @ statementEdits[styleSource[text, "Data"], StringSplit[text, "\n", All]]]

closerEdits[source_Association, lines : {___String}] :=
	Module[{offsets, pairs, firstPairs},
		offsets = lineOffsets[lines];
		pairs = trailingCloserPairs[locatedSource[source]];
		firstPairs = Values @ Map[First, GroupBy[SortBy[pairs, nodeStart[Last[#]] &], nodeLine[Last[#]] &]];
		Map[
			Function[pair,
				Module[{closeLine, closeColumn, leftText},
					{closeLine, closeColumn} = nodeStart[Last[pair]];
					leftText = StringTake[Extract[lines, {closeLine}], closeColumn - 1];
					{
						offsetOf[offsets, {closeLine, closeColumn - spaceRun[leftText]}],
						offsetOf[offsets, {closeLine, closeColumn}],
						"\n" <> lineIndentation[lines, nodeLine[First[pair]]]
					}
				]
			],
			firstPairs
		]
	]

closerFix[text_String] :=
	FixedPoint[Function[current, applyEdits[current, closerEdits[styleSource[current, "Data"], StringSplit[current, "\n", All]]]], text, 50]

(* A break goes after a space that is not escaped and not the last character before a final backslash, so that a wrapped line is left alone. *)
wrappedLine[line_String, width_Integer, prefix_Integer] :=
	Module[{limit, breakPositions},
		limit = Max[width - prefix, 40];
		breakPositions = Select[Map[First, StringPosition[line, RegularExpression["(?<!\\\\) (?!\\\\?$)"]]], # < limit &];
		If[StringLength[line] <= limit || breakPositions === {},
			{line},
			Prepend[wrappedLine[StringDrop[line, Max[breakPositions]], width, 0], StringTake[line, Max[breakPositions]] <> "\\"]
		]
	]

wrappedString[literal_String, column_Integer] :=
	Module[{unbroken, sourceLines},
		unbroken = StringReplace[literal, $rawNewline -> "\\n\\\n"];
		sourceLines = StringSplit[unbroken, "\n", All];
		StringRiffle[
			Catenate @ MapIndexed[Function[{line, position}, wrappedLine[line, 150, If[position === {1}, column - 1, 0]]], sourceLines],
			"\n"
		]
	]

messageStrings[tree_List] :=
	Cases[tree, BinaryNode["Set", {InfixNode["MessageName", __], ___, token : LeafNode["String", __]}, _] :> token, Infinity]

messageStringEdits[source_Association, lines : {___String}] :=
	Module[{offsets, widths, candidates, rewritten},
		offsets = lineOffsets[lines];
		widths = StringLength[StringReplace[lines, "\t" -> "    "]];
		candidates = Select[
			messageStrings[source["Concrete"]],
			StringContainsQ[Extract[#, {2}], $rawNewline] || Max[Take[widths, {nodeLine[#], First @ nodeEnd[#]}]] > 150 &
		];
		rewritten = Map[Function[token, {token, wrappedString[Extract[token, {2}], Last @ nodeStart[token]]}], candidates];
		Map[
			Function[pair, {offsetOf[offsets, nodeStart[First[pair]]], offsetOf[offsets, nodeEnd[First[pair]]], Last[pair]}],
			Select[rewritten, Last[#] =!= Extract[First[#], {2}] && ToExpression[Last[#]] === ToExpression[Extract[First[#], {2}]] &]
		]
	]

messageStringFix[text_String] := applyEdits[text, messageStringEdits[styleSource[text, "Data"], StringSplit[text, "\n", All]]]

loadStatement[depth_Integer] := "PacletDirectoryLoad[DirectoryName[$TestFileName, " <> ToString[depth] <> "]]"

testHeaderFix[text_String, depth_Integer] :=
	Which[
		StringContainsQ[text, "PacletDirectoryLoad[DirectoryName[$TestFileName"],
			text,
		StringContainsQ[text, RegularExpression["(?m)^Needs\\["]],
			StringReplace[text, RegularExpression["(?m)^Needs\\["] -> loadStatement[depth] <> "\nNeeds[", 1],
		True,
			loadStatement[depth] <> "\nNeeds[\"WolframInstitute`PARILink`\"]\n\n" <> text
	]

codeSkeleton[text_String] :=
	Replace[
		CodeParse[StringReplace[text, StartOfString ~~ "#!" ~~ Except["\n"] ... -> ""]],
		{LeafNode[String, literal_String, _] :> ToExpression[literal], _Association -> Null},
		{0, Infinity}
	]

fixPass[text_String] := messageStringFix @ closerFix @ statementFix @ spacingFix @ commentFix @ tabsFix[text]

FixedStyleText[text_String, kind_String, loadDepth : (_Integer | None)] :=
	Enclose @ Module[{headed, fixed},
		headed = If[kind === "Test" && IntegerQ[loadDepth], testHeaderFix[text, loadDepth], text];
		fixed = FixedPoint[fixPass, headed, 20];
		ConfirmAssert[codeSkeleton[fixed] === codeSkeleton[headed], "the fixed text does not parse to the same code"];
		fixed
	]
FixedStyleText[text_String, kind_String] := FixedStyleText[text, kind, None]
FixedStyleText[___] := invalidArgumentsFailure[FixedStyleText]

styleLoadDepth[file_String] :=
	Module[{parts},
		parts = FileNameSplit @ RepositoryPath[file];
		If[MatchQ[parts, {"PARILink", "Tests", ___, _}], Length[parts] - 1, None]
	]

fixStyleFile[file_String] :=
	Module[{text, fixed},
		text = readText[file];
		fixed = If[StringQ[text], FixedStyleText[text, styleSourceKind[file], styleLoadDepth[file]], text];
		Which[
			FailureQ[fixed],
				LogError[<|"File" -> file|>, "not fixed: ", fixed["Message"]];
				False,
			fixed === text,
				False,
			True,
				writeText[file, fixed];
				LogInfo["  fixed ", RepositoryPath[file]];
				True
		]
	]

(* A legacy file with no issues left is dropped from the list; comment lines and the order of the rest stay. *)
prunedLegacyLines[lines : {___String}, cleanPaths : {___String}] := Select[lines, !MemberQ[cleanPaths, StringTrim[#]] &]

pruneLegacyList[files : {___String}] :=
	Module[{legacyPaths, paths, cleanPaths, text},
		legacyPaths = styleLegacyFiles[];
		paths = Map[Function[file, StringReplace[RepositoryPath[file], "\\" -> "/"]], files];
		cleanPaths = Select[Intersection[paths, legacyPaths], StyleIssues[FileNameJoin[{$RepositoryRoot, #}]] === {} &];
		text = If[cleanPaths === {}, None, readText[$styleLegacyFile]];
		If[StringQ[text],
			writeText[$styleLegacyFile, StringRiffle[prunedLegacyLines[StringSplit[text, "\n", All], cleanPaths], "\n"]];
			LogInfo["  ", Length[cleanPaths], " file(s) left the legacy list"]
		];
		cleanPaths
	]

FixStyle[files : {___String}] :=
	Module[{changed},
		changed = Select[files, fixStyleFile];
		LogInfo["  ", Length[changed], " of ", Length[files], " file(s) rewritten"];
		pruneLegacyList[files];
		changed
	]
FixStyle[] :=
	Module[{everythingQ, changed},
		everythingQ = $ScriptArguments === {};
		changed = FixStyle[If[everythingQ, styleFiles[], Map[resolveStyleFile, $ScriptArguments]]];
		If[everythingQ && FailureQ[writeStyleRules[]], LogError["the table of rules in docs/coding-guides/README.md could not be written"]];
		changed
	]
FixStyle[___] := invalidArgumentsFailure[FixStyle]
