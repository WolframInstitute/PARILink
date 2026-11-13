(* ::Package:: *)

PackageImport["CodeParser`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[{StyleIssues, CheckStyle, $StyleRules}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{
	styleIssue, styleSource, styleSourceKind, styleIndex, styleFiles, styleLegacyFiles, $styleLegacyFile, nodeStart, nodeEnd, nodeLine,
	symbolNode, callNode, plainTree, readText, writeText, resolveStyleFile, styleRulesTable, writeStyleRules, styleTextIssues,
	styleSyntaxIssues, styleCodeIssues, styleDefinitionIssues
}];

(* ::Section:: *)
(*Usage Messages*)

$StyleRules::usage = "$StyleRules gives the style rules as an association from each rule name to its \"Guide\" reference, \
its \"Summary\", the file \"Kinds\" it applies to and whether an allow comment may waive it (\"Allow\").";
StyleIssues::usage = "StyleIssues[file] gives the style issues of a Wolfram Language file, each an association with the keys \
\"Rule\", \"Line\", \"Column\" and \"Message\". Cross-file rules use the other files of the same kind in the repository.\n\
StyleIssues[text, kind] checks the code in the string text as a file of kind \"Kernel\", \"Script\", \"Program\", \"Test\" or \
\"Data\", on its own.\n\
StyleIssues[text, kind, index] uses the cross-file facts in index, as given by styleIndex.";
CheckStyle::usage = "CheckStyle[] checks the Wolfram Language files named on the command line, or every such file of the \
repository, against the coding guides. It logs each issue as an error and gives a list of results per file. The issues of the \
files listed in scripts/style-legacy.txt are counted but not logged.\n\
CheckStyle[files] checks the given files, a list of paths.";
writeStyleRules::usage = "writeStyleRules[] writes the table of $StyleRules into docs/coding-guides/README.md, between its two \
style-rules markers, and gives the path of the file, or a Failure.";
styleRule::usage = "styleRule[name, guide, summary, kinds, allowQ] gives the $StyleRules entry of one rule. kinds is All or \
a list of file kinds; allowQ says whether an allow comment may waive the rule.";
styleIssue::usage = "styleIssue[rule, {line, column}, detail] gives one style issue. detail names the offending code.\n\
styleIssue[rule, node, detail] places the issue at the start of a syntax node.";
$patternExpression::usage = "$patternExpression is the pattern of an expression used as a pattern for a name: a string, alternatives, or a \
named, blank, tested or conditioned pattern.";
$syntaxNode::usage = "$syntaxNode is the pattern of a node of a CodeParser syntax tree.";
symbolNode::usage = "symbolNode[name] gives the pattern of a symbol node whose name matches the string pattern name.";
callNode::usage = "callNode[name] gives the pattern of an abstract call node whose head is a symbol with a name that matches name.\n\
callNode[name, arguments] also requires the list of argument nodes to match arguments.";
styleTextIssues::usage = "styleTextIssues[source] gives the issues found in the lines and tokens of a parsed source.";
styleSyntaxIssues::usage = "styleSyntaxIssues[source] gives the issues found in the syntax tree of a parsed source, with its whitespace.";
styleCodeIssues::usage = "styleCodeIssues[source] gives the issues found in the statements of a parsed source.";
styleDefinitionIssues::usage = "styleDefinitionIssues[source, index] gives the issues found in the definitions of a parsed source, \
given the cross-file facts in index.";
styleReport::usage = "styleReport[text, kind, index] gives the \"Issues\" of the code in text and the number of its allow comments (\"Waivers\").";
styleSource::usage = "styleSource[text, kind] parses the code in text and gives an association with the keys \"Kind\", \
\"Lines\", \"Tokens\", \"Concrete\" (syntax tree with whitespace), \"Abstract\" (top-level statements) and \"Definitions\". \
Node kinds and operators are strings, and each node ends with its source span {{line, column}, {line, column}} or None.";
styleSourceKind::usage = "styleSourceKind[file] gives the kind of a repository file: \"Test\" for a .wlt file, \"Program\" for a standalone .wls \
script, \"Kernel\" for package code of the paclet, \"Script\" for package code under scripts and \"Data\" for any other file.";
styleIndex::usage = "styleIndex[sources] gives the cross-file facts of a list of parsed sources, or of their statements and \
definitions: the names with a function definition (\"Functions\"), with a usage message (\"Usages\") and the exported names (\"Exported\").";
styleFiles::usage = "styleFiles[] lists the Wolfram Language files that CheckStyle[] checks: the kernel, the paclet tests, the \
paclet metadata, the scripts and the files under tests.";
$styleLegacyFile::usage = "$styleLegacyFile is the path of the list of files not yet converted to the coding guides.";
styleLegacyFiles::usage = "styleLegacyFiles[] gives the repository paths listed in $styleLegacyFile.";
nodeStart::usage = "nodeStart[node] gives the {line, column} where a syntax node starts, or {0, 0} for a node without a source span.";
nodeLine::usage = "nodeLine[node] gives the number of the line on which a syntax node starts.";
nodeEnd::usage = "nodeEnd[node] gives the {line, column} just after a syntax node, or {0, 0} for a node without a source span.";
plainTree::usage = "plainTree[tree] rewrites a CodeParser tree so that token kinds and operators are strings and node data is \
the source span or None.";
symbolTail::usage = "symbolTail[symbol] gives the last part of a symbol's full name, such as \"Comma\" for the comma token kind.";
readText::usage = "readText[file] gives the UTF-8 text of a file, or a Failure when it cannot be read.";
writeText::usage = "writeText[file, text] writes text to a file as UTF-8, byte for byte, and gives the file name.";
allowances::usage = "allowances[source] gives the allow comments of a parsed source as associations with the keys \"Line\" \
(of the comment), \"Target\" (the code line it covers) and \"Rules\".";
allowanceRecord::usage = "allowanceRecord[tokens, text, line] gives the record of the allow comment with the given text on the given line.";
allowTarget::usage = "allowTarget[tokens, line] gives the line an allow comment on the given line covers: its own line when \
that line has code, and the next line with code otherwise.";
waivedQ::usage = "waivedQ[issue, allowanceList] gives True when an allow comment covers the issue's line and names its rule.";
allowanceIssues::usage = "allowanceIssues[allowanceList, issues] gives an issue for each allow comment that names an unknown or \
unwaivable rule, or that waives nothing.";
issueMessage::usage = "issueMessage[issue] gives the text logged for an issue: the detail, the rule summary and the guide reference.";
withoutShebang::usage = "withoutShebang[text] gives the text of a script with its first line blanked when that line starts with #!.";
abstractFacts::usage = "abstractFacts[text] gives the top-level statements of the code in text (\"Abstract\") and its definitions (\"Definitions\").";
factsOfKind::usage = "factsOfKind[kind] gives the statements and definitions of every repository file of a kind.";
kindIndex::usage = "kindIndex[kind] gives the cross-file facts for a kind of repository file, computed once per session.";
checkStyleFile::usage = "checkStyleFile[file, legacyPaths] logs the issues of one file and gives an association with its path \
(\"File\"), whether it is a legacy file (\"Legacy\"), its \"Issues\" and its number of allow comments (\"Waivers\"); the issues of a \
legacy file are not logged.";
ruleCounts::usage = "ruleCounts[results] gives the number of issues per rule in a list of checkStyleFile results.";
summaryLines::usage = "summaryLines[checked, legacy] gives the lines of a table of issue counts per rule, for the checked files and \
for the legacy files.";
markdownText::usage = "markdownText[text] gives text with the characters that Markdown reads as markup escaped.";
ruleRow::usage = "ruleRow[name, rule] gives the Markdown table row of one style rule.";
styleRulesTable::usage = "styleRulesTable[] gives the Markdown table of $StyleRules.";
$styleRulesPage::usage = "$styleRulesPage is the path of the page that lists the style rules.";
resolveStyleFile::usage = "resolveStyleFile[path] gives the file a command-line path names: as given, or relative to the repository root.";

(* ::Section:: *)
(*Function Definitions*)

$allKinds = {"Kernel", "Script", "Program", "Test", "Data"};
$codeKinds = {"Kernel", "Script", "Program", "Test"};
$programKinds = {"Kernel", "Script", "Program"};
$packageKinds = {"Kernel", "Script"};
$allKinds::usage = "$allKinds lists every file kind.";
$codeKinds::usage = "$codeKinds lists the kinds of file that hold code: packages, standalone programs and tests.";
$programKinds::usage = "$programKinds lists the kinds of file that hold code other than tests.";
$packageKinds::usage = "$packageKinds lists the kinds of file that hold package code, where every function has a usage message.";

styleRule[name_String, guide_String, summary_String, kinds : (All | {__String}), allowQ : (True | False)] :=
	name -> <|"Guide" -> guide, "Summary" -> summary, "Kinds" -> Replace[kinds, All -> $allKinds], "Allow" -> allowQ|>

$StyleRules = Association[
	(* formatting *)
	styleRule["SyntaxError", "coding guide", "The file must parse.", All, False],
	styleRule["TabIndentation", "coding guide, Rule 13", "Indent with tabs, not spaces.", All, False],
	styleRule["LineWidth", "coding guide, Rule 13", "Keep lines within 200 characters; break near 150.", All, True],
	styleRule["NonASCIICharacter", "coding guide, non-negotiable rules",
		"Keep source ASCII: no em dashes, box-drawing characters or decorative arrows; write a character by its long name.", All, False],
	styleRule["DoubleHyphen", "coding guide, non-negotiable rules", "Use a hyphen, comma, colon or new sentence, not two hyphens as a dash.", All, False],
	styleRule["CommentSpacing", "coding guide, Rule 11", "Put a space inside each end of a comment: (* note *).", All, False],
	styleRule["NestedComment", "coding guide, Rule 11", "Keep comment delimiters out of a comment's text.", All, False],
	styleRule["OperatorSpacing", "coding guide, Rule 13", "Put one space on each side of an infix operator; keep ? and :: tight.", All, False],
	styleRule["CommaSpacing", "coding guide, Rule 13", "Put one space after a comma and none before it.", All, False],
	styleRule["CommaPlacement", "coding guide, Rules 7 and 13", "End the line with the comma; never start a line with one.", All, False],
	styleRule["SplitOperator", "coding guide, Rule 13",
		"Keep a binary operator and both operands on one line; name an intermediate value or use the head form, such as Or[...].", All, False],
	styleRule["StatementPerLine", "coding guide, Rule 13", "Write one statement per line: break after each semicolon.", All, False],
	styleRule["HangingSemicolon", "coding guide, Rule 13",
		"Drop the semicolon before a comma or before the closing bracket of a scoping construct; it gives Null.", $codeKinds, False],
	styleRule["TrailingSpan", "coding guide, Rule 13", "Do not end a line with ;;.", All, False],
	styleRule["BracketAlignment", "coding guide, Rule 13",
		"Put the closing bracket of a multi-line expression on its own line, indented like the line that opens it.", All, False],
	styleRule["StringLineBreak", "coding guide, Rule 2",
		"Do not break a string with a raw newline; end the line with \\n\\ for a new line of text, or with \\ to wrap.", $programKinds, False],
	(* syntax *)
	styleRule["PostfixApplication", "coding guide, Rule 10", "Use prefix or full application, not postfix //.", $codeKinds, False],
	styleRule["InfixApplication", "coding guide, Rule 10", "Write f[a, b], not a ~f~ b.", $codeKinds, False],
	styleRule["PrefixApplication", "coding guide, Rule 10", "Do not apply @ to a parenthesized expression.", $codeKinds, False],
	styleRule["NestedPureFunction", "coding guide, Rule 10",
		"Do not nest slot functions; write Function[variable, ...] or a named helper.", $codeKinds, False],
	styleRule["HeadComparison", "coding guide, Rule 7", "Use MatchQ[expr, _head], not a comparison with Head[expr].", $codeKinds, False],
	styleRule["ApplyAndOr", "coding guide, Rule 8", "Use And[...], Or[...], AllTrue, AnyTrue or NoneTrue, not And @@ or Or @@.", $codeKinds, True],
	(* constructs *)
	styleRule["ReturnCall", "coding guide, Rule 6", "Do not use Return; let the value fall out, or use Confirm with Enclose.", $codeKinds, False],
	styleRule["ProceduralLoop", "coding guide, Rule 7",
		"Do not write For, Do or While; use Table, Map, Scan, Fold, Nest or a relative.", $codeKinds, False],
	styleRule["AppendTo", "coding guide, Rule 9", "Build the list with Table, Map, Fold or Reap, not AppendTo or PrependTo.", $codeKinds, False],
	styleRule["ScopeConstruct", "coding guide, Rule 4", "Use Module, Block or With, not Scope or ModuleScope.", $codeKinds, False],
	styleRule["WithBindings", "coding guide, Rule 4",
		"Use Module for computation; With is for one or two short constants, or for values injected into held code.", $codeKinds, True],
	styleRule["NestedWith", "coding guide, Rule 4", "Write nested With as one flat With[{a = ...}, {b = ...}, body].", $codeKinds, False],
	styleRule["UnusedLocal", "coding guide, Rule 4", "Remove a local variable that is never used.", $codeKinds, False],
	styleRule["OptionalArgument", "coding guide, Rule 3",
		"Do not give a positional argument a default; add a downvalue for the shorter calling form.", $codeKinds, False],
	styleRule["OptionQPattern", "coding guide, Rule 3", "Take options with opts : OptionsPattern[], not ___?OptionQ.", $codeKinds, False],
	styleRule["UntaggedControl", "coding guide, Rule 8",
		"Give Quiet the messages it expects, and Catch, Throw, Sow and Reap a tag.", $codeKinds, False],
	styleRule["PartLiteral", "coding guide, Rule 13",
		"Do not reach into an expression by a fixed position; use a named pattern, First, Last, Rest or Most.", $codeKinds, True],
	styleRule["BareFailed", "coding guide, Rule 6", "Give a Failure object, not a bare $Failed.", $programKinds, True],
	styleRule["OptionValueTest", "coding guide, Rule 5",
		"Wrap a Boolean option in TrueQ, or validate it with ConfirmMatch, before testing it.", $codeKinds, False],
	styleRule["ClearAtLoad", "coding guide, things to avoid", "Do not Clear, ClearAll or Remove symbols when a file loads.", $packageKinds, False],
	styleRule["QualifiedSymbol", "coding guide, Rule 14",
		"Import the context and use the short name; do not use internal contexts.", $codeKinds, True],
	(* naming and documentation *)
	styleRule["ShortName", "coding guide, Rule 1",
		"Name arguments and local variables with full words of at least three letters that say what they hold.", $codeKinds, False],
	styleRule["LocalShadowsFunction", "coding guide, Rule 1",
		"Do not give an argument or local variable the name of a function in this codebase.", $packageKinds, False],
	styleRule["SystemNameCollision", "coding guide, Rule 1", "Do not define or export a name that System already has.", $packageKinds, False],
	styleRule["ParameterName", "coding guide, Rule 1", "Start the name of a file-level parameter with $.", $packageKinds, False],
	styleRule["MissingUsage", "coding guide, Rule 2", "Give every function and parameter a usage message, public or private.", $packageKinds, False],
	styleRule["UsageFormat", "coding guide, Rule 2",
		"Start a usage message with the calling template, then say what it gives.", $packageKinds, False],
	styleRule["OwnArgsMessage", "coding guide, Rule 3", "Do not define ::args; every symbol inherits the generic message.", $packageKinds, False],
	styleRule["MissingCatchAll", "coding guide, Rule 3",
		"End a public function with a catch-all that gives a Failure; a predicate ends with [___] := False.", $packageKinds, True],
	styleRule["BarePattern", "coding guide, Rule 3",
		"Give each argument a specific pattern, not a bare blank; only a helper's fallback definition may take any argument.", $packageKinds, True],
	(* visualization *)
	styleRule["HardCodedColor", "coding guide, non-negotiable rules; visualization guide, Color",
		"Use a Standard color for data and a LightDarkSwitched pair for other colors; never pin a white or black background.", {"Kernel"}, True],
	styleRule["CrossingAxes", "visualization guide, Frame Every Plot",
		"Frame the plot: use Frame, FrameLabel and FrameTicks, not Axes, AxesLabel and Ticks.", {"Kernel"}, True],
	styleRule["UnframedPlot", "visualization guide, Frame Every Plot",
		"Give a plot with quantitative axes Frame -> True and Axes -> False.", {"Kernel"}, True],
	(* tests *)
	styleRule["TestHeader", "coding guide, Rule 15",
		"Load the paclet with PacletDirectoryLoad[DirectoryName[$TestFileName, n]], then Needs, so that a test file runs on its own.", {"Test"}, False],
	styleRule["TestPrint", "coding guide, Rule 15", "Do not Print in a test file.", {"Test"}, False],
	styleRule["MissingTestID", "coding guide, Rule 15", "Give every VerificationTest a TestID.", {"Test"}, False],
	(* waivers *)
	styleRule["UnknownAllow", "coding guides page, Waiving a rule", "An allow comment names a rule that exists and can be waived, and gives a reason.", All, False],
	styleRule["UnusedAllow", "coding guides page, Waiving a rule", "Remove an allow comment that waives nothing.", All, False]
];

$patternExpression = _String | _Alternatives | _Pattern | _Blank | _PatternTest | _Condition;
$syntaxNode = Alternatives[
	_LeafNode, _CallNode, _BinaryNode, _InfixNode, _TernaryNode, _QuaternaryNode, _PrefixNode, _PostfixNode, _PrefixBinaryNode, _CompoundNode, _GroupNode
];

styleIssue[rule_String, {line_Integer, column_Integer}, detail_String] :=
	<|"Rule" -> rule, "Line" -> line, "Column" -> column, "Message" -> detail|>
styleIssue[rule_String, node : $syntaxNode, detail_String] := styleIssue[rule, nodeStart[node], detail]

symbolNode[name : $patternExpression] := LeafNode["Symbol", name, _]

callNode[name : $patternExpression] := CallNode[LeafNode["Symbol", name, _], _List, _]
callNode[name : $patternExpression, arguments : (_List | _Pattern)] := CallNode[LeafNode["Symbol", name, _], arguments, _]

nodeStart[_[___, {start : {_Integer, _Integer}, {_Integer, _Integer}}]] := start
nodeStart[_] := {0, 0}

nodeLine[node : $syntaxNode] := First @ nodeStart[node]

nodeEnd[_[___, {{_Integer, _Integer}, end : {_Integer, _Integer}}]] := end
nodeEnd[_] := {0, 0}

symbolTail[symbol_Symbol] := Last @ StringSplit[Context[symbol] <> SymbolName[symbol], "`"]

(* Replace works from the leaves up, so each node is rewritten after its children. *)
$operatorNodeHeads = BinaryNode | InfixNode | TernaryNode | QuaternaryNode | PrefixNode | PostfixNode | PrefixBinaryNode | CompoundNode | GroupNode;
$operatorNodeHeads::usage = "$operatorNodeHeads is the pattern of the heads of syntax nodes that carry an operator or group kind.";

plainTree[tree : (_ContainerNode | _List)] :=
	Replace[
		tree,
		{
			LeafNode[kind_Symbol, text_, data_Association] :> LeafNode[symbolTail[kind], text, Lookup[data, Source, None]],
			(head : $operatorNodeHeads)[kind_Symbol, children_List, data_Association] :> head[symbolTail[kind], children, Lookup[data, Source, None]],
			CallNode[head_, arguments_, data_Association] :> CallNode[head, arguments, Lookup[data, Source, None]],
			ContainerNode[_, children_List, _Association] :> children
		},
		{0, Infinity}
	]

(* A shebang line is not Wolfram Language; blank it so that line numbers stay the same. *)
withoutShebang[text_String] := StringReplace[text, StartOfString ~~ "#!" ~~ Except["\n"] ... -> ""]

abstractFacts[text_String] :=
	Module[{abstract},
		abstract = topLevelStatements @ plainTree @ CodeParse[withoutShebang[text]];
		<|"Abstract" -> abstract, "Definitions" -> DeleteMissing[definitionRecord /@ abstract]|>
	]

styleSource[text_String, kind_String] :=
	Module[{code},
		code = withoutShebang[text];
		Join[
			<|
				"Kind" -> kind,
				"Lines" -> StringSplit[code, "\n", All],
				"Tokens" -> plainTree @ CodeTokenize[code],
				"Concrete" -> plainTree @ CodeConcreteParse[code]
			|>,
			abstractFacts[text]
		]
	]

styleSourceKind[file_String] :=
	Module[{path},
		path = StringReplace[RepositoryPath[file], "\\" -> "/"];
		Which[
			StringEndsQ[path, ".wlt"],
				"Test",
			StringEndsQ[path, ".wls"],
				"Program",
			StringStartsQ[path, "PARILink/Kernel/"],
				"Kernel",
			StringStartsQ[path, "scripts/"],
				"Script",
			True,
				"Data"
		]
	]

styleIndex[sources : {___Association}] :=
	Module[{definitions, exported},
		definitions = Catenate[Lookup[sources, "Definitions", {}]];
		exported = Catenate[exportedNames /@ Lookup[sources, "Abstract", {}]];
		<|
			"Functions" -> Union @ Cases[definitions, KeyValuePattern[{"Kind" -> "Function" | "SubValue", "Symbol" -> name_String}] :> name],
			"Usages" -> Union @ Cases[definitions, KeyValuePattern[{"Kind" -> "Message", "Tag" -> "usage", "Symbol" -> name_String}] :> name],
			"Exported" -> Union[exported]
		|>
	]

readText[file_String] :=
	Enclose @ Module[{bytes},
		bytes = ConfirmMatch[ReadByteArray[file], _ByteArray | EndOfFile, "cannot read " <> file];
		If[MatchQ[bytes, _ByteArray], ByteArrayToString[bytes, "UTF-8"], ""]
	]

writeText[file_String, text_String] :=
	Module[{stream},
		stream = OpenWrite[file, BinaryFormat -> True];
		WithCleanup[BinaryWrite[stream, StringToByteArray[text, "UTF-8"]], Close[stream]];
		file
	]

$allowPattern = "(* allow " ~~ rules : (WordCharacter | "," | " ") .. ~~ ": " ~~ reason__ ~~ " *)";
$allowPattern::usage = "$allowPattern matches an allow comment, such as (* allow PartLiteral: fixed tuple from the parser *).";

allowTarget[tokens_List, line_Integer] :=
	Module[{codeLines},
		codeLines = Cases[tokens, LeafNode[Except["Whitespace" | "Newline" | "Comment"], _, {{codeLine_Integer, _}, _}] :> codeLine];
		Min[Select[codeLines, # >= line &], Infinity]
	]

allowanceRecord[tokens_List, text_String, line_Integer] :=
	<|
		"Line" -> line,
		"Target" -> allowTarget[tokens, line],
		"Rules" -> Flatten @ StringCases[text, $allowPattern :> StringSplit[rules, "," | " "]],
		"Text" -> text
	|>

allowances[source_Association] :=
	Cases[
		source["Tokens"],
		LeafNode["Comment", text_String /; StringStartsQ[text, "(* allow "], {{line_Integer, _}, _}] :> allowanceRecord[source["Tokens"], text, line]
	]

waivedQ[issue_Association, allowanceList : {___Association}] :=
	AnyTrue[allowanceList, #Target === issue["Line"] && MemberQ[#Rules, issue["Rule"]] &]

allowanceIssues[allowanceList : {___Association}, issues : {___Association}] :=
	Catenate @ Map[
		Function[allowance,
			Which[
				allowance["Rules"] === {},
					{styleIssue["UnknownAllow", {allowance["Line"], 1}, "write (* allow RuleName: reason *)"]},
				!AllTrue[allowance["Rules"], TrueQ[$StyleRules[#, "Allow"]] &],
					{styleIssue["UnknownAllow", {allowance["Line"], 1}, StringRiffle[allowance["Rules"], ", "] <> " cannot be waived"]},
				NoneTrue[issues, #Line === allowance["Target"] && MemberQ[allowance["Rules"], #Rule] &],
					{styleIssue["UnusedAllow", {allowance["Line"], 1}, allowance["Text"]]},
				True,
					{}
			]
		],
		allowanceList
	]

styleReport[text_String, kind_String, index_Association] :=
	Module[{source, found, applicable, allowanceList, kept},
		source = styleSource[text, kind];
		found = Join[styleTextIssues[source], styleSyntaxIssues[source], styleCodeIssues[source], styleDefinitionIssues[source, index]];
		applicable = Select[found, MemberQ[$StyleRules[#Rule, "Kinds"], kind] &];
		allowanceList = allowances[source];
		kept = Select[applicable, !(TrueQ[$StyleRules[#Rule, "Allow"]] && waivedQ[#, allowanceList]) &];
		<|
			"Issues" -> SortBy[DeleteDuplicates @ Join[kept, allowanceIssues[allowanceList, applicable]], {#Line, #Column, #Rule} &],
			"Waivers" -> Length[allowanceList]
		|>
	]

StyleIssues[text_String, kind_String, index_Association] := styleReport[text, kind, index]["Issues"]
StyleIssues[text_String, kind : ("Kernel" | "Script" | "Program" | "Test" | "Data")] :=
	StyleIssues[text, kind, styleIndex[{styleSource[text, kind]}]]
StyleIssues[file_String?FileExistsQ] :=
	Enclose @ Module[{text, kind},
		text = Confirm[readText[file]];
		kind = styleSourceKind[file];
		StyleIssues[text, kind, kindIndex[kind]]
	]
StyleIssues[___] := invalidArgumentsFailure[StyleIssues]

(* Build output and the files that tools download under .deps are not checked. *)
styleFiles[] :=
	Join[
		FileNames["*.wl", FileNameJoin[{$PacletDirectory, "Kernel"}], Infinity],
		FileNames[{"*.wl", "*.wlt"}, FileNameJoin[{$PacletDirectory, "Tests"}], Infinity],
		Select[{FileNameJoin[{$PacletDirectory, "PacletInfo.wl"}]}, FileExistsQ],
		FileNames[{"*.wl", "*.wls", "*.wlt"}, FileNameJoin[{$RepositoryRoot, "scripts"}], Infinity],
		FileNames[{"*.wl", "*.wls", "*.wlt"}, FileNameJoin[{$RepositoryRoot, "tests"}], Infinity]
	]

factsOfKind[kind_String] :=
	Module[{files, texts},
		files = Select[styleFiles[], styleSourceKind[#] === kind &];
		texts = Select[Map[readText, files], StringQ];
		Map[abstractFacts, texts]
	]

(* Tests and data files are checked on their own; kernel and script files share names across files. *)
kindIndex[kind : ("Kernel" | "Script")] := kindIndex[kind] = styleIndex[factsOfKind[kind]]
kindIndex[_String] := <|"Functions" -> {}, "Usages" -> {}, "Exported" -> {}, "Standalone" -> True|>

$styleLegacyFile := FileNameJoin[{$RepositoryRoot, "scripts", "style-legacy.txt"}]

(* An empty or missing list means that every file is converted. *)
styleLegacyFiles[] :=
	Module[{text},
		text = If[FileExistsQ[$styleLegacyFile], readText[$styleLegacyFile], ""];
		If[StringQ[text], Select[StringTrim /@ StringSplit[text, "\n"], # =!= "" && !StringStartsQ[#, "#"] &], {}]
	]

issueMessage[issue_Association] :=
	Module[{rule},
		rule = $StyleRules[issue["Rule"]];
		StringJoin[issue["Rule"], ": ", issue["Message"], ". ", rule["Summary"], " (", rule["Guide"], ")"]
	]

checkStyleFile[file_String, legacyPaths : {___String}] :=
	Module[{text, kind, fileReport, issues, path, legacyQ},
		text = readText[file];
		kind = styleSourceKind[file];
		fileReport = If[StringQ[text], styleReport[text, kind, kindIndex[kind]], <|"Issues" -> text, "Waivers" -> 0|>];
		issues = fileReport["Issues"];
		path = StringReplace[RepositoryPath[file], "\\" -> "/"];
		legacyQ = MemberQ[legacyPaths, path];
		Which[
			FailureQ[issues],
				LogError[<|"File" -> file|>, "style check failed: ", issues["Message"]],
			legacyQ && issues === {},
				LogError[<|"File" -> $styleLegacyFile|>, path, " has no style issues; remove it from the list, or run make style-fix"],
			!legacyQ,
				Scan[LogError[<|"File" -> file, "Line" -> #Line, "Column" -> #Column|>, issueMessage[#]] &, issues]
		];
		<|"File" -> path, "Legacy" -> legacyQ, "Issues" -> If[FailureQ[issues], {}, issues], "Waivers" -> fileReport["Waivers"]|>
	]

ruleCounts[results : {___Association}] := Counts[Lookup[Catenate[Lookup[results, "Issues", {}]], "Rule", {}]]

summaryLines[checked : {___Association}, legacy : {___Association}] :=
	Module[{checkedCounts, legacyCounts, rules},
		checkedCounts = ruleCounts[checked];
		legacyCounts = ruleCounts[legacy];
		rules = ReverseSortBy[Union[Keys[checkedCounts], Keys[legacyCounts]], Lookup[checkedCounts, #, 0] + Lookup[legacyCounts, #, 0] &];
		Map[
			Function[rule,
				StringJoin[
					"    ", StringPadRight[rule, 24],
					StringPadLeft[ToString @ Lookup[checkedCounts, rule, 0], 7],
					StringPadLeft[ToString @ Lookup[legacyCounts, rule, 0], 9]
				]
			],
			rules
		]
	]

resolveStyleFile[path_String] := SelectFirst[{ExpandFileName[path], FileNameJoin[{$RepositoryRoot, path}]}, FileExistsQ, path]

CheckStyle[files : {___String}] :=
	Module[{legacyPaths, results, checked, legacy},
		legacyPaths = styleLegacyFiles[];
		results = Map[checkStyleFile[#, legacyPaths] &, files];
		checked = Select[results, !#Legacy &];
		legacy = Select[results, #Legacy &];
		LogInfo["  ", Length[checked], " file(s) checked against the coding guides, ", Total[Length /@ Lookup[checked, "Issues", {}]], " issue(s)"];
		If[legacy =!= {},
			LogInfo["  ", Length[legacy], " legacy file(s) not yet converted, with ", Total[Length /@ Lookup[legacy, "Issues", {}]], " issue(s)"]
		];
		LogInfo["  ", Total[Lookup[checked, "Waivers", {}]], " rule waiver(s) in the checked files"];
		If[ruleCounts[results] =!= <||>,
			LogInfo["    ", StringPadRight["rule", 24], StringPadLeft["checked", 7], StringPadLeft["legacy", 9]];
			Scan[LogInfo, summaryLines[checked, legacy]]
		];
		results
	]
CheckStyle[] := CheckStyle[If[$ScriptArguments === {}, styleFiles[], resolveStyleFile /@ $ScriptArguments]]
markdownText[text_String] := StringReplace[text, {"*" -> "\\*", "_" -> "\\_", "|" -> "\\|", "<" -> "&lt;"}]

ruleRow[name_String, rule_Association] :=
	StringJoin[
		"| `", name, "` | ", markdownText[rule["Summary"]], " | ", rule["Guide"], " | ", StringRiffle[rule["Kinds"], ", "], " | ",
		If[rule["Allow"], "yes", "no"], " |"
	]

styleRulesTable[] :=
	StringRiffle[
		Join[
			{"| Rule | What to do | Source | Applies to | Can be waived |", "| --- | --- | --- | --- | --- |"},
			KeyValueMap[ruleRow, $StyleRules]
		],
		"\n"
	]

$styleRulesPage := FileNameJoin[{$RepositoryRoot, "docs", "coding-guides", "README.md"}]

writeStyleRules[] :=
	Enclose @ Module[{text, parts},
		text = Confirm[readText[$styleRulesPage]];
		parts = StringSplit[text, "<!-- style-rules:start -->" | "<!-- style-rules:end -->", All];
		ConfirmAssert[Length[parts] === 3, "the page needs one pair of style-rules markers."];
		writeText[
			$styleRulesPage,
			StringJoin[First[parts], "<!-- style-rules:start -->\n", styleRulesTable[], "\n<!-- style-rules:end -->", Last[parts]]
		]
	]
CheckStyle[___] := invalidArgumentsFailure[CheckStyle]
