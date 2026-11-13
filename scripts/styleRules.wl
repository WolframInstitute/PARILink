(* ::Package:: *)

PackageImport["CodeParser`"]

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{
	firstTokens, lastTokens, lineStartTokens, lineIndentation, $triviaToken, continuedLines, commaWindowIssues, cellMarkerQ, cellTitleQ, spacedCommentQ,
	$rawNewline, operatorNodes, operatorWindows, spacingIssue, sameLinePairs, locatedSource, trailingCloserPairs, declaredSymbols,
	scopingDeclarations, issuesAt, namedIssues, topLevelStatements, definitionRecord, exportedNames
}];

(* ::Section:: *)
(*Usage Messages*)

$triviaToken::usage = "$triviaToken is the pattern of a whitespace, newline or comment token.";
firstTokens::usage = "firstTokens[tokens] gives an association from each line number to the first token on that line that is not whitespace.";
lastTokens::usage = "lastTokens[tokens] gives an association from each line number to the last token on that line that is not whitespace or a \
comment.";
lineIndentation::usage = "lineIndentation[lines, line] gives the leading whitespace of the numbered line of a list of lines.";
continuedLines::usage = "continuedLines[tokens] gives the numbers of the lines that start inside a string or a comment.";
lineStartTokens::usage = "lineStartTokens[tokens] gives an association from each line number to the first token on that line, for the lines that \
start outside a string or a comment.";
tabIndentationIssues::usage = "tabIndentationIssues[source] gives an issue for each line indented with a space.";
widthIssue::usage = "widthIssue[width, {line}] gives a list with a LineWidth issue when width is over 200, and an empty list otherwise.";
lineWidthIssues::usage = "lineWidthIssues[source] gives an issue for each line wider than 200 characters, counting a tab as four.";
$nonASCIICharacter::usage = "$nonASCIICharacter matches a character outside ASCII.";
$commentForbiddenCharacter::usage = "$commentForbiddenCharacter matches a dash, arrow or box-drawing character outside ASCII.";
$hyphenDash::usage = "$hyphenDash matches two hyphens with whitespace on both sides.";
$rawNewline::usage = "$rawNewline matches a newline that is not a line continuation.";
characterCode::usage = "characterCode[character] gives the code point of a one-character string in the form U+2014.";
forbiddenCharacters::usage = "forbiddenCharacters[kind, text] gives the code points of the characters a token of the given kind may not \
hold: any character outside ASCII, or only dashes, arrows and box-drawing characters in a comment.";
characterIssues::usage = "characterIssues[token] gives a list with a NonASCIICharacter issue when a token holds a forbidden character.";
nonASCIIIssues::usage = "nonASCIIIssues[source] gives an issue for each token with a forbidden character outside ASCII.";
doubleHyphenIssues::usage = "doubleHyphenIssues[source] gives an issue for each string or comment that uses two hyphens as a dash.";
cellMarkerQ::usage = "cellMarkerQ[text] gives True for a notebook cell marker comment such as (* ::Section:: *).";
cellTitleQ::usage = "cellTitleQ[previous, comment] gives True when comment is the cell text on the line after a cell marker.";
spacedCommentQ::usage = "spacedCommentQ[text] gives True when a comment has whitespace inside each delimiter.";
commentPairIssues::usage = "commentPairIssues[previous, comment] gives the spacing and nesting issues of one comment, given the comment before it.";
commentIssues::usage = "commentIssues[source] gives the spacing and nesting issues of every comment.";
commaWindowIssues::usage = "commaWindowIssues[{before, comma, after}, firstOnLine] gives the spacing and placement issues of a comma \
token, given its neighbors and the first token of each line.";
commaIssues::usage = "commaIssues[source] gives the spacing and placement issues of every comma.";
trailingSpanIssues::usage = "trailingSpanIssues[source] gives an issue for each line that ends with ;;.";
stringLineBreakIssues::usage = "stringLineBreakIssues[source] gives an issue for each string broken by a raw newline.";
$operatorNode::usage = "$operatorNode is the pattern of the heads of syntax nodes that join operands with operator tokens.";
$unspacedOperators::usage = "$unspacedOperators is the pattern of operators whose spacing is not checked.";
$tightOperators::usage = "$tightOperators is the pattern of operators written without spaces.";
$assignmentOperators::usage = "$assignmentOperators is the pattern of operators after which the right-hand side may start on the next line.";
$scopingCall::usage = "$scopingCall is the pattern of the head of a concrete call of Module, Block, With or DynamicModule.";
$ownLineCloserCall::usage = "$ownLineCloserCall is the pattern of the head of a concrete call whose closing bracket starts its own line \
when the call spans lines: the scoping constructs and If, Which and Switch.";
$impliedToken::usage = "$impliedToken is the pattern of the token kinds the parser adds for implied operands and operators.";
$oneSpace::usage = "$oneSpace is the pattern of a token that may sit next to a spaced operator: one space, a newline or a comment.";
$statementEnd::usage = "$statementEnd is the pattern of a token that is not the start of a statement: whitespace, a comment, a newline \
or the Null implied after a final semicolon.";
$errorNode::usage = "$errorNode is the pattern of a syntax node that marks code the parser could not read.";
operatorNodes::usage = "operatorNodes[tree] gives {operator, children} for each node of a syntax tree that joins operands with operator \
tokens and whose spacing is checked.";
operatorTokens::usage = "operatorTokens[children] gives the operator tokens among the children of an operator node: every second \
child that is not whitespace, a newline or a comment, without implied tokens.";
operatorWindows::usage = "operatorWindows[children] gives {left, token, right} for each operator token among the children of an operator node.";
spacingIssue::usage = "spacingIssue[operator, {left, token, right}] gives the spacing issues of one operator token in a node with \
the given operator.";
operatorSpacingIssues::usage = "operatorSpacingIssues[source] gives an issue for each infix operator without one space on each side, \
and for each ? or :: with a space.";
splitIssues::usage = "splitIssues[{operator, children}] gives an issue for each operator token next to a line break in a node with \
the given operator and children.";
splitOperatorIssues::usage = "splitOperatorIssues[source] gives an issue for each binary operator separated from an operand by a line break.";
sameLinePairs::usage = "sameLinePairs[children] gives {semicolon, statement} for each statement among the children of a compound \
expression that follows a semicolon on the same line.";
statementIssues::usage = "statementIssues[source] gives an issue for each statement that follows a semicolon on the same line.";
hangingQ::usage = "hangingQ[node] gives True when a node is a compound expression that ends with a semicolon.";
hangingBeforeComma::usage = "hangingBeforeComma[children] gives the arguments among the children of a comma node that end with a semicolon \
and are followed by a comma.";
lastArgument::usage = "lastArgument[inner] gives the last argument among the nodes inside a call's brackets, or None when there is none.";
hangingSemicolonIssues::usage = "hangingSemicolonIssues[source] gives an issue for each semicolon before a comma or before the closing \
bracket of Module, Block, With or DynamicModule.";
multilineGroups::usage = "multilineGroups[tree] gives {opener, closer} for each bracket pair of a syntax tree that spans lines.";
ownLineGroups::usage = "ownLineGroups[tree] gives {opener, closer} for the brackets of each multi-line call of a scoping construct, If, Which or \
Switch.";
bindingListOpeners::usage = "bindingListOpeners[tree] gives the opening brace of the variable list of each scoping construct in a syntax tree.";
locatedSource::usage = "locatedSource[source] adds to a parsed source the first and the last code token of each line, under \"FirstTokens\" \
and \"LastTokens\", and the opening braces of the variable lists of scoping constructs, under \"BindingOpeners\".";
closerFirstQ::usage = "closerFirstQ[located, closer] gives True when a closing bracket is the first token on its line.";
trailingCloserPairs::usage = "trailingCloserPairs[located] gives {opener, closer} for each multi-line bracket pair whose closing bracket \
should start a line and does not: the opener ends its line, or the call is a scoping construct, If, Which or Switch.";
misalignedCloserQ::usage = "misalignedCloserQ[located, {opener, closer}] gives True when a closing bracket starts its line with an \
indentation other than that of the line that opens it.";
closerText::usage = "closerText[{opener, closer}] gives the text of the closing bracket of a pair.";
bracketAlignmentIssues::usage = "bracketAlignmentIssues[source] gives the alignment issues of every multi-line bracket pair.";
applicationIssues::usage = "applicationIssues[source] gives an issue for each postfix //, infix ~f~ and @ applied to a parenthesized expression.";
syntaxErrorStart::usage = "syntaxErrorStart[node] gives the {line, column} of a syntax error node, or {1, 1} when it carries no position.";
syntaxErrorIssues::usage = "syntaxErrorIssues[source] gives an issue for each part of the file that does not parse.";
issuesAt::usage = "issuesAt[rule, nodes, detail] gives one issue of a rule, with the same detail, at each of a list of syntax nodes.";
namedIssues::usage = "namedIssues[rule, nodes, suffix] gives one issue of a rule at each of a list of symbol or call nodes, whose detail \
is the name of the symbol, or of the head of the call, followed by suffix.";
nodeName::usage = "nodeName[node] gives the name of a symbol node, or of the symbol at the head of a call node.";
$bindingList::usage = "$bindingList is the pattern of an abstract list node, as in the variables of a scoping construct.";
$slotFunction::usage = "$slotFunction is the pattern of a function written with slots and &; its head has no source span, unlike Function[x, ...] \
written out.";
$heldCodeHeads::usage = "$heldCodeHeads is the pattern of heads that hold code a With may need to inject values into.";
$comparisonHeads::usage = "$comparisonHeads is the pattern of heads whose arguments are compared or matched, not produced.";
$colorHeads::usage = "$colorHeads is the pattern of heads that build a literal color.";
$colorNames::usage = "$colorNames is the pattern of named colors that are not Standard colors.";
$framedPlotHeads::usage = "$framedPlotHeads is the pattern of plotting functions whose output has quantitative axes.";
bannedIssues::usage = "bannedIssues[source] gives an issue for each Return, Scope, ModuleScope, loop, AppendTo, PrependTo, comparison \
with Head, And @@ and Or @@, and for each Quiet, Catch, Throw, Sow and Reap with one argument.";
longBindingQ::usage = "longBindingQ[binding] gives True when the value of a With binding spans lines or is wider than 60 characters.";
withNodeIssues::usage = "withNodeIssues[node] gives the issues of one With node: a With directly inside it, and bindings that carry computation.";
withIssues::usage = "withIssues[source] gives the issues of every With.";
declaredSymbols::usage = "declaredSymbols[declarationLists] gives the symbol nodes declared in the variable lists of a scoping construct.";
scopingDeclarations::usage = "scopingDeclarations[statements, names] gives {node, symbols} for each call of a scoping construct whose name \
matches names: the call node and the symbol nodes it declares.";
unusedSymbols::usage = "unusedSymbols[{node, symbols}] gives the declared symbol nodes that appear only once in the scoping node.";
unusedLocalIssues::usage = "unusedLocalIssues[source] gives an issue for each variable of Module, With or DynamicModule that appears only \
in its declaration.";
literalIndexQ::usage = "literalIndexQ[node] gives True when a node is an integer literal.";
fixedSpanQ::usage = "fixedSpanQ[node] gives True when a node is the span 2 ;; or ;; -2, which Rest and Most replace.";
partIssues::usage = "partIssues[source] gives an issue for each Part whose indices are all integer literals, and for each Part that takes \
the rest or the most of a list.";
patternArgumentQ::usage = "patternArgumentQ[head, position] gives True when the argument at a position of a call with the given head \
is a pattern or a compared value.";
failedUses::usage = "failedUses[node, patternQ] gives the $Failed nodes in a syntax node that are produced as values; patternQ says \
whether the node is already inside a pattern or comparison.";
failedIssues::usage = "failedIssues[source] gives an issue for each $Failed produced as a value.";
optionValueQ::usage = "optionValueQ[node] gives True when a node is a call of OptionValue.";
conditionNodes::usage = "conditionNodes[statements] gives the nodes used directly as a condition: the test of each If, the arguments of \
And, Or and Not, and the tests of each Which.";
optionValueIssues::usage = "optionValueIssues[source] gives an issue for each OptionValue used directly as a condition.";
loadIssues::usage = "loadIssues[source] gives an issue for each top-level Clear, ClearAll or Remove.";
allowedQualifiedQ::usage = "allowedQualifiedQ[kind, name] gives True when a context-qualified name may appear in a file of the given \
kind: a test may name a package-scoped symbol in full.";
qualifiedSymbolIssues::usage = "qualifiedSymbolIssues[source] gives an issue for each context-qualified symbol.";
shortNameQ::usage = "shortNameQ[name] gives True for a name with fewer than three characters after any leading $.";
shortNameIssues::usage = "shortNameIssues[source] gives an issue for each pattern name and local variable shorter than three characters.";
pureFunctionIssues::usage = "pureFunctionIssues[source] gives an issue for each slot function nested in another slot function.";
colorUses::usage = "colorUses[node, switchedQ] gives the literal color nodes in a syntax node that are outside LightDarkSwitched; \
switchedQ says whether the node is already inside one.";
visualizationIssues::usage = "visualizationIssues[source] gives an issue for each literal color outside LightDarkSwitched, each pinned \
white or black background, each use of Axes, AxesLabel or Ticks, and each plot with quantitative axes that sets no Frame.";
loadsItselfQ::usage = "loadsItselfQ[statements] gives True when a test file loads what it tests from a path built from $TestFileName: \
the paclet with PacletDirectoryLoad[DirectoryName[$TestFileName, n]], or the scripts with Get.";
testIssues::usage = "testIssues[source] gives an issue for each Print and each VerificationTest without a TestID in a test file, and \
one when the file does not load what it tests from its own location.";
topLevelStatements::usage = "topLevelStatements[nodes] gives the statements of a file from its abstract syntax nodes: compound \
expressions at the top level are split, and the Null after a final semicolon is dropped.";
definitionPattern::usage = "definitionPattern[left] gives the left-hand side of a definition without a Condition or HoldPattern around it.";
innermostHeadName::usage = "innermostHeadName[node] gives the name of the symbol at the head of a call such as f[a][b], or None.";
definitionTarget::usage = "definitionTarget[pattern] gives the \"Symbol\" a definition is attached to and its \"Kind\": \"Function\", \
\"SubValue\", \"Parameter\", \"Message\" (with its \"Tag\"), \"System\" for a definition under a System head, or \"Other\".";
definitionRecord::usage = "definitionRecord[statement] gives an association that describes a top-level definition, with the keys \
\"Symbol\", \"Kind\", \"Left\", \"Right\", \"Line\" and \"Condition\", or Missing[\"NotADefinition\"] for any other statement.";
exportedSymbolNodes::usage = "exportedSymbolNodes[statements] gives the symbol nodes declared with PackageExported among the statements of a file.";
exportedNames::usage = "exportedNames[statements] gives the names declared with PackageExported among the statements of a file.";
definitionLeftSides::usage = "definitionLeftSides[statements] gives the left-hand side of every definition of a function, at any depth.";
argumentPatternIssues::usage = "argumentPatternIssues[source] gives an issue for each Optional argument and each ___?OptionQ in the \
left-hand side of a definition.";
definitionsOfKind::usage = "definitionsOfKind[source, kinds] gives the top-level definitions of a parsed source whose kind matches kinds.";
definitionIssue::usage = "definitionIssue[rule, definition, suffix] gives an issue of a rule at the line of a definition, whose detail is \
the name of the defined symbol followed by suffix.";
parameterNameIssues::usage = "parameterNameIssues[source] gives an issue for each file-level parameter whose name does not start with $.";
firstDefinitions::usage = "firstDefinitions[definitions] gives the first definition of each symbol in a list of definitions.";
missingUsageIssues::usage = "missingUsageIssues[source, index] gives an issue for each function and parameter defined in the file \
without a usage message in the index.";
usageText::usage = "usageText[node] gives the text of a usage message from the node of its string literal, or None for any other node.";
templateQ::usage = "templateQ[name, text] gives True when a usage message starts with the calling template of name, or with the name \
of a parameter, followed by a description.";
usageFormatIssues::usage = "usageFormatIssues[source] gives an issue for each usage message that is not a string literal or does not \
start with its calling template, and for each definition of ::args.";
$anySequence::usage = "$anySequence is the pattern of the argument list of a catch-all definition: one sequence of any arguments, named or not.";
catchAllQ::usage = "catchAllQ[definition] gives True when a definition is the catch-all of its function: one sequence of any arguments \
that gives a Failure, or False for a predicate.";
bareArgumentQ::usage = "bareArgumentQ[node] gives True when an argument pattern is a blank with no head, test or condition.";
argumentNodes::usage = "argumentNodes[left] gives the argument patterns of the left-hand side of a definition, at every call level.";
catchAllIssues::usage = "catchAllIssues[definitions] gives an issue for each function among the definitions whose last definition is not a catch-all.";
bareArguments::usage = "bareArguments[definition] gives the argument patterns of a definition that are bare blanks.";
alwaysBareArguments::usage = "alwaysBareArguments[definitions] gives, for the definitions of one function, the bare blanks at an argument \
position that is a bare blank in every definition with the same number of arguments.";
bareArgumentIssues::usage = "bareArgumentIssues[name, arguments] gives a BarePattern issue at each of the argument nodes of the function name.";
argumentIssues::usage = "argumentIssues[source, index] gives an issue for each bare blank among the arguments of an exported function, and \
for each argument of a helper that no definition of the helper gives a pattern. Definitions with a condition are not checked.";
publicFunctionIssues::usage = "publicFunctionIssues[source, index] gives an issue for each exported function of the file without a final catch-all.";
shadowingNodes::usage = "shadowingNodes[source, functionNames] gives the pattern names and local variables of a parsed source that are \
named like one of the given functions.";
collisionIssues::usage = "collisionIssues[source, index] gives an issue for each exported name and each parameter that System already \
has, and for each argument or local variable named like a function of the codebase.";

(* ::Section:: *)
(*Function Definitions*)

(* ::Subsection:: *)
(*Lines and tokens*)

$triviaToken = LeafNode["Whitespace" | "Newline" | "Comment", __];

firstTokens[tokens_List] := Map[First, GroupBy[DeleteCases[tokens, LeafNode["Whitespace" | "Newline", __]], nodeLine]]

lastTokens[tokens_List] := Map[Last, GroupBy[DeleteCases[tokens, $triviaToken], nodeLine]]

lineIndentation[lines : {___String}, line_Integer] :=
	StringJoin @ StringCases[Extract[lines, {line}], StartOfString ~~ leading : (" " | "\t") ... :> leading]

continuedLines[tokens_List] :=
	Module[{spans},
		spans = Cases[tokens, LeafNode["String" | "Comment", _, {{startLine_Integer, _}, {endLine_Integer, _}}] :> {startLine, endLine}];
		Union @ Catenate @ Map[Function[span, Range[First[span] + 1, Last[span]]], spans]
	]

lineStartTokens[tokens_List] := KeyDrop[firstTokens[tokens], continuedLines[tokens]]

tabIndentationIssues[source_Association] :=
	Module[{exemptLines, indentations, spacedLines},
		exemptLines = continuedLines[source["Tokens"]];
		indentations = StringCases[source["Lines"], StartOfString ~~ leading : (" " | "\t") ... :> leading];
		spacedLines = Flatten @ Position[indentations, {leading_String /; StringContainsQ[leading, " "]}, {1}, Heads -> False];
		Map[styleIssue["TabIndentation", {#, 1}, "the indentation has spaces"] &, Complement[spacedLines, exemptLines]]
	]

widthIssue[width_Integer, {line_Integer}] :=
	If[width > 200, {styleIssue["LineWidth", {line, 201}, "the line is " <> ToString[width] <> " characters wide"]}, {}]

lineWidthIssues[source_Association] := Catenate @ MapIndexed[widthIssue, StringLength[StringReplace[source["Lines"], "\t" -> "    "]]]

$nonASCIICharacter = RegularExpression["[^\\x00-\\x7F]"];
$commentForbiddenCharacter = RegularExpression["[\\x{2013}-\\x{2015}\\x{2190}-\\x{21FF}\\x{2500}-\\x{257F}\\x{27F0}-\\x{27FF}\\x{2900}-\\x{297F}]"];
$hyphenDash = RegularExpression["\\s--\\s"];
$rawNewline = RegularExpression["(?<!\\\\)\\n"];

characterCode[character_String] := "U+" <> ToUpperCase @ IntegerString[First @ ToCharacterCode[character], 16, 4]

forbiddenCharacters[kind_String, text_String] :=
	Map[characterCode, DeleteDuplicates @ StringCases[text, If[kind === "Comment", $commentForbiddenCharacter, $nonASCIICharacter]]]

characterIssues[token : LeafNode[kind_String, text_String, _]] :=
	Module[{codes},
		codes = forbiddenCharacters[kind, text];
		If[codes === {}, {}, {styleIssue["NonASCIICharacter", token, StringRiffle[codes, ", "]]}]
	]

nonASCIIIssues[source_Association] := Catenate[characterIssues /@ source["Tokens"]]

doubleHyphenIssues[source_Association] :=
	Map[
		Function[token, styleIssue["DoubleHyphen", token, "two hyphens used as a dash"]],
		Cases[source["Tokens"], LeafNode["String" | "Comment", text_String /; StringContainsQ[text, $hyphenDash], _]]
	]

cellMarkerQ[text_String] := StringMatchQ[text, "(* ::" ~~ __ ~~ ":: *)"]

cellTitleQ[LeafNode["Comment", previousText_String, {{previousLine_Integer, _}, _}], LeafNode["Comment", _, {{line_Integer, _}, _}]] :=
	cellMarkerQ[previousText] && line === previousLine + 1
cellTitleQ[_, _] := False

spacedCommentQ[text_String] := text === "(* *)" || StringMatchQ[text, "(*" ~~ WhitespaceCharacter ~~ ___ ~~ WhitespaceCharacter ~~ "*)"]

commentPairIssues[previous : (None | _LeafNode), comment : LeafNode["Comment", text_String, _]] :=
	If[cellMarkerQ[text] || cellTitleQ[previous, comment],
		{},

		Join[
			If[spacedCommentQ[text], {}, {styleIssue["CommentSpacing", comment, StringTake[text, UpTo[40]]]}],
			If[StringContainsQ[StringTake[text, {3, -3}], "(*"], {styleIssue["NestedComment", comment, StringTake[text, UpTo[40]]]}, {}]
		]
	]

commentIssues[source_Association] :=
	Module[{comments},
		comments = Cases[source["Tokens"], LeafNode["Comment", __]];
		Catenate[commentPairIssues @@@ Partition[Prepend[comments, None], 2, 1]]
	]

commaWindowIssues[{before_LeafNode, comma_LeafNode, after_LeafNode}, firstOnLine_Association] :=
	Module[{firstQ},
		firstQ = Lookup[firstOnLine, nodeLine[comma]] === comma;
		Join[
			If[firstQ, {styleIssue["CommaPlacement", comma, "a comma starts the line"]}, {}],
			If[!firstQ && MatchQ[before, LeafNode["Whitespace", __]], {styleIssue["CommaSpacing", comma, "space before a comma"]}, {}],
			If[MatchQ[after, LeafNode["Whitespace", " ", _] | LeafNode["Newline", __]],
				{},
				{styleIssue["CommaSpacing", comma, "a comma is not followed by one space"]}
			]
		]
	]

commaIssues[source_Association] :=
	Module[{firstOnLine, windows},
		firstOnLine = lineStartTokens[source["Tokens"]];
		windows = Cases[Partition[source["Tokens"], 3, 1], {_LeafNode, LeafNode["Comma", __], _LeafNode}];
		Catenate @ Map[Function[window, commaWindowIssues[window, firstOnLine]], windows]
	]

trailingSpanIssues[source_Association] :=
	Map[
		Function[token, styleIssue["TrailingSpan", token, "a line ends with ;;"]],
		Cases[Values @ lastTokens[source["Tokens"]], LeafNode["SemiSemi", __]]
	]

stringLineBreakIssues[source_Association] :=
	Map[
		Function[token, styleIssue["StringLineBreak", token, "a string has a raw newline"]],
		Cases[source["Tokens"], LeafNode["String", text_String /; StringContainsQ[text, $rawNewline], _]]
	]

styleTextIssues[source_Association] :=
	Join[
		tabIndentationIssues[source],
		lineWidthIssues[source],
		nonASCIIIssues[source],
		doubleHyphenIssues[source],
		commentIssues[source],
		commaIssues[source],
		trailingSpanIssues[source],
		stringLineBreakIssues[source]
	]

(* ::Subsection:: *)
(*Syntax tree with whitespace*)

$operatorNode = BinaryNode | InfixNode | TernaryNode | QuaternaryNode;
$unspacedOperators = "CompoundExpression" | "Comma" | "Span" | "TernaryTilde" | "Unset";
$tightOperators = "PatternTest" | "MessageName";
$assignmentOperators = Alternatives["Set", "SetDelayed", "UpSet", "UpSetDelayed", "TagSet", "TagSetDelayed", "AddTo", "SubtractFrom", "TimesBy", "DivideBy"];
$scopingCall = {LeafNode["Symbol", "Module" | "Block" | "With" | "DynamicModule", _]};
$ownLineCloserCall = {LeafNode["Symbol", "Module" | "Block" | "With" | "DynamicModule" | "If" | "Which" | "Switch", _]};
$impliedToken = "ImplicitTimes" | "ImplicitNull" | "ImplicitOne" | "ImplicitAll";
$oneSpace = LeafNode["Whitespace", " ", _] | LeafNode["Newline" | "Comment", __];
$statementEnd = LeafNode["Whitespace" | "Comment" | "Newline" | "ImplicitNull", __];
$errorNode = Alternatives[
	_ErrorNode,
	_SyntaxErrorNode,
	_GroupMissingCloserNode,
	_GroupMissingOpenerNode,
	_CallMissingCloserNode,
	_UnterminatedGroupNeedsReparseNode,
	_UnterminatedTokenErrorNeedsReparseNode
];

operatorNodes[tree_List] :=
	Cases[tree, $operatorNode[operator : Except[$unspacedOperators, _String], children_List, _] :> {operator, children}, Infinity]

operatorTokens[children_List] :=
	Cases[Downsample[Drop[DeleteCases[children, $triviaToken], UpTo[1]], 2], LeafNode[Except[$impliedToken], __]]

operatorWindows[children_List] :=
	Module[{tokens},
		tokens = operatorTokens[children];
		Cases[Partition[children, 3, 1], {_, token_, _} /; MemberQ[tokens, token]]
	]

spacingIssue[operator_String, {left_, token : LeafNode[_, text_String, _], right_}] :=
	Module[{tightQ, spacedQ},
		tightQ = MatchQ[operator, $tightOperators];
		spacedQ = MatchQ[left, $oneSpace] && MatchQ[right, $oneSpace];
		Which[
			tightQ && (MatchQ[left, LeafNode["Whitespace", __]] || MatchQ[right, LeafNode["Whitespace", __]]),
				{styleIssue["OperatorSpacing", token, "space around " <> text]},
			!tightQ && !spacedQ,
				{styleIssue["OperatorSpacing", token, "no single space on each side of " <> text]},
			True,
				{}
		]
	]

operatorSpacingIssues[source_Association] :=
	Catenate @ Map[
		Function[node, Catenate[Map[Function[window, spacingIssue[First[node], window]], operatorWindows[Last[node]]]]],
		operatorNodes[source["Concrete"]]
	]

splitIssues[{operator_String, children_List}] :=
	Module[{tokens, afterAllowedQ, runs, splitRuns},
		tokens = operatorTokens[children];
		afterAllowedQ = MatchQ[operator, $assignmentOperators];
		runs = SequenceCases[children, {before : $triviaToken ..., token_LeafNode /; MemberQ[tokens, token], after : $triviaToken ...} :> {token, {before}, {after}}];
		splitRuns = Cases[
			runs,
			{_, before_List, after_List} /; MemberQ[before, LeafNode["Newline", __]] || (!afterAllowedQ && MemberQ[after, LeafNode["Newline", __]])
		];
		Map[Function[run, styleIssue["SplitOperator", First[run], "a line break next to an operator"]], splitRuns]
	]

splitOperatorIssues[source_Association] := Catenate[splitIssues /@ operatorNodes[source["Concrete"]]]

sameLinePairs[children_List] :=
	Module[{pairs},
		pairs = SequenceCases[children, {semicolon : LeafNode["Semi", __], LeafNode["Whitespace" | "Comment", __] ..., next : Except[$statementEnd]} :> {semicolon, next}];
		Select[pairs, nodeLine[First[#]] === nodeLine[Last[#]] &]
	]

statementIssues[source_Association] :=
	Module[{compounds},
		compounds = Cases[source["Concrete"], InfixNode["CompoundExpression", children_List, _] :> children, Infinity];
		Map[
			Function[pair, styleIssue["StatementPerLine", nodeStart[Last[pair]], "a statement follows a semicolon on the same line"]],
			Catenate[sameLinePairs /@ compounds]
		]
	]

hangingQ[InfixNode["CompoundExpression", {___, LeafNode["ImplicitNull", __]}, _]] := True
hangingQ[_] := False

hangingBeforeComma[children_List] := SequenceCases[children, {statement_?hangingQ, $triviaToken ..., LeafNode["Comma", __]} :> statement]

lastArgument[inner_List] :=
	Replace[
		DeleteCases[inner, $triviaToken],
		{
			{InfixNode["Comma", commaChildren_List, _]} :> Last[DeleteCases[commaChildren, $triviaToken]],
			{single_} :> single,
			_ -> None
		}
	]

hangingSemicolonIssues[source_Association] :=
	Module[{commaLists, scopingBodies},
		commaLists = Cases[source["Concrete"], InfixNode["Comma", children_List, _] :> children, Infinity];
		scopingBodies = Cases[source["Concrete"], CallNode[$scopingCall, GroupNode["GroupSquare", {_, inner___, _}, _], _] :> lastArgument[{inner}], Infinity];
		Join[
			Map[
				Function[statement, styleIssue["HangingSemicolon", nodeEnd[statement], "a semicolon before a comma"]],
				Catenate[hangingBeforeComma /@ commaLists]
			],
			Map[
				Function[statement, styleIssue["HangingSemicolon", nodeEnd[statement], "a semicolon before the closing bracket of a scoping construct"]],
				Select[scopingBodies, hangingQ]
			]
		]
	]

multilineGroups[tree_List] :=
	Select[
		Cases[tree, GroupNode[_, {opener_LeafNode, ___, closer_LeafNode}, _] :> {opener, closer}, Infinity],
		nodeLine[Last[#]] > nodeLine[First[#]] &
	]

ownLineGroups[tree_List] :=
	Select[
		Cases[tree, CallNode[$ownLineCloserCall, GroupNode["GroupSquare", {opener_LeafNode, ___, closer_LeafNode}, _], _] :> {opener, closer}, Infinity],
		nodeLine[Last[#]] > nodeLine[First[#]] &
	]

bindingListOpeners[tree_List] :=
	Module[{firstArguments},
		firstArguments = Cases[
			tree,
			CallNode[$scopingCall, GroupNode["GroupSquare", {_, InfixNode["Comma", {first_, ___}, _], _}, _], _] :> first,
			Infinity
		];
		Cases[firstArguments, GroupNode["List", {opener_LeafNode, ___}, _] :> opener]
	]

locatedSource[source_Association] :=
	Join[
		source,
		<|
			"FirstTokens" -> firstTokens[source["Tokens"]],
			"LastTokens" -> lastTokens[source["Tokens"]],
			"BindingOpeners" -> bindingListOpeners[source["Concrete"]]
		|>
	]

closerFirstQ[located_Association, closer_LeafNode] := Lookup[located["FirstTokens"], nodeLine[closer]] === closer

trailingCloserPairs[located_Association] :=
	Union[
		Select[multilineGroups[located["Concrete"]], !closerFirstQ[located, Last[#]] && Lookup[located["LastTokens"], nodeLine[First[#]]] === First[#] &],
		Select[ownLineGroups[located["Concrete"]], !closerFirstQ[located, Last[#]] &]
	]

(* The list of bindings of a scoping construct may close one level deeper, as in With[{ ... }, body]. *)
misalignedCloserQ[located_Association, {opener_LeafNode, closer_LeafNode}] :=
	Module[{openIndentation, closeIndentation, deeperBindingsQ},
		openIndentation = lineIndentation[located["Lines"], nodeLine[opener]];
		closeIndentation = lineIndentation[located["Lines"], nodeLine[closer]];
		deeperBindingsQ = MemberQ[located["BindingOpeners"], opener] && closeIndentation === openIndentation <> "\t";
		closerFirstQ[located, closer] && closeIndentation =!= openIndentation && !deeperBindingsQ
	]

closerText[{_LeafNode, LeafNode[_, text_String, _]}] := text

bracketAlignmentIssues[source_Association] :=
	Module[{located},
		located = locatedSource[source];
		Join[
			Map[
				Function[pair, styleIssue["BracketAlignment", Last[pair], closerText[pair] <> " does not start its line"]],
				trailingCloserPairs[located]
			],
			Map[
				Function[pair, styleIssue["BracketAlignment", Last[pair], closerText[pair] <> " is not indented like the line that opens it"]],
				Select[multilineGroups[source["Concrete"]], misalignedCloserQ[located, #] &]
			]
		]
	]

applicationIssues[source_Association] :=
	Join[
		Map[
			Function[token, styleIssue["PostfixApplication", token, "postfix //"]],
			Cases[source["Concrete"], BinaryNode["BinarySlashSlash", {___, token : LeafNode["SlashSlash", __], ___}, _] :> token, Infinity]
		],
		Map[
			Function[node, styleIssue["InfixApplication", node, "infix ~f~"]],
			Cases[source["Concrete"], TernaryNode["TernaryTilde", __], Infinity]
		],
		Map[
			Function[operand, styleIssue["PrefixApplication", operand, "@ applied to a parenthesized expression"]],
			Cases[source["Concrete"], BinaryNode["BinaryAt", {___, operand : GroupNode["GroupParen", __]}, _] :> operand, Infinity]
		]
	]

syntaxErrorStart[_[___, data_Association]] := Replace[Lookup[data, Source, None], {{start : {_Integer, _Integer}, _} :> start, _ -> {1, 1}}]
syntaxErrorStart[node_] := Replace[nodeStart[node], {0, 0} -> {1, 1}]

syntaxErrorIssues[source_Association] :=
	Map[
		Function[node, styleIssue["SyntaxError", syntaxErrorStart[node], "the code does not parse here"]],
		Cases[source["Concrete"], $errorNode, Infinity]
	]

styleSyntaxIssues[source_Association] :=
	Join[
		syntaxErrorIssues[source],
		operatorSpacingIssues[source],
		splitOperatorIssues[source],
		statementIssues[source],
		hangingSemicolonIssues[source],
		bracketAlignmentIssues[source],
		applicationIssues[source]
	]

(* ::Subsection:: *)
(*Statements*)

$bindingList = callNode["List"];
$slotFunction = CallNode[LeafNode["Symbol", "Function", None], {_}, _];
$heldCodeHeads = Alternatives[
	"SetDelayed", "UpSetDelayed", "TagSetDelayed", "Dynamic", "DynamicModule", "Manipulate", "Hold", "HoldForm", "HoldComplete", "HoldPattern", "Compile",
	"FunctionCompile"
];
$comparisonHeads = Alternatives[
	"SameQ", "UnsameQ", "Equal", "Unequal", "MatchQ", "FreeQ", "MemberQ", "Alternatives", "Except", "Verbatim", "HoldPattern", "FailureQ"
];
$colorHeads = "RGBColor" | "Hue" | "GrayLevel" | "CMYKColor" | "XYZColor" | "LABColor" | "LCHColor" | "LUVColor";
$colorNames = Alternatives[
	"Red", "Green", "Blue", "Black", "White", "Gray", "Cyan", "Magenta", "Yellow", "Brown", "Orange", "Pink", "Purple",
	"LightRed", "LightGreen", "LightBlue", "LightGray", "LightCyan", "LightMagenta", "LightYellow", "LightBrown", "LightOrange", "LightPink", "LightPurple"
];
$framedPlotHeads = Alternatives[
	"Plot", "LogPlot", "LogLinearPlot", "LogLogPlot", "ListPlot", "ListLinePlot", "ListLogPlot", "ListLogLinearPlot", "ListLogLogPlot",
	"ListStepPlot", "DateListPlot", "DateListStepPlot", "DiscretePlot", "ParametricPlot", "Histogram", "SmoothHistogram", "BarChart", "BoxWhiskerChart"
];

issuesAt[rule_String, nodes_List, detail_String] := Map[Function[node, styleIssue[rule, node, detail]], nodes]

nodeName[LeafNode["Symbol", name_String, _]] := name
nodeName[CallNode[LeafNode["Symbol", name_String, _], _List, _]] := name

namedIssues[rule_String, nodes_List, suffix_String] := Map[Function[node, styleIssue[rule, node, nodeName[node] <> suffix]], nodes]

bannedIssues[source_Association] :=
	Module[{statements},
		statements = source["Abstract"];
		Join[
			namedIssues["ReturnCall", Cases[statements, symbolNode["Return"], Infinity], ""],
			namedIssues["ScopeConstruct", Cases[statements, symbolNode["Scope" | "ModuleScope"], Infinity], ""],
			namedIssues["ProceduralLoop", Cases[statements, callNode["For" | "Do" | "While"], Infinity], " loop"],
			namedIssues["AppendTo", Cases[statements, callNode["AppendTo" | "PrependTo"], Infinity], ""],
			issuesAt[
				"HeadComparison",
				Cases[statements, callNode["SameQ" | "UnsameQ" | "Equal" | "Unequal", {___, callNode["Head", {_}], ___}], Infinity],
				"a comparison with Head[...]"
			],
			issuesAt["ApplyAndOr", Cases[statements, callNode["Apply", {symbolNode["And" | "Or"], _}], Infinity], "And @@ or Or @@"],
			namedIssues["UntaggedControl", Cases[statements, callNode["Quiet" | "Catch" | "Throw" | "Sow" | "Reap", {_}], Infinity], " with one argument"]
		]
	]

longBindingQ[callNode["Set" | "SetDelayed", {_, _[___, {{startLine_Integer, startColumn_Integer}, {endLine_Integer, endColumn_Integer}}]}]] :=
	endLine > startLine || endColumn - startColumn > 60
longBindingQ[_] := False

withNodeIssues[node : callNode["With", {bindingLists : $bindingList .., body_}]] :=
	Module[{bindings, heldQ, computationQ},
		bindings = Catenate[Cases[{bindingLists}, CallNode[_, elements_List, _] :> elements]];
		heldQ = !FreeQ[body, callNode[$heldCodeHeads]];
		computationQ = Length[{bindingLists}] > 1 || Length[bindings] > 2 || AnyTrue[bindings, longBindingQ];
		Join[
			If[MatchQ[body, callNode["With"]], {styleIssue["NestedWith", node, "a With directly inside a With"]}, {}],
			If[!heldQ && computationQ, {styleIssue["WithBindings", node, "a With that carries computation"]}, {}]
		]
	]

withIssues[source_Association] := Catenate[withNodeIssues /@ Cases[source["Abstract"], callNode["With", {$bindingList .., _}], Infinity]]

declaredSymbols[declarationLists : {___CallNode}] :=
	Cases[
		Catenate[Cases[declarationLists, CallNode[_, elements_List, _] :> elements]],
		(symbol : symbolNode[_String]) | callNode["Set" | "SetDelayed", {symbol : symbolNode[_String], _}] :> symbol
	]

scopingDeclarations[statements_List, names : (_String | _Alternatives)] :=
	Cases[statements, node : callNode[names, {declarationLists : $bindingList .., _}] :> {node, declaredSymbols[{declarationLists}]}, Infinity]

unusedSymbols[{node_CallNode, symbols_List}] := Select[symbols, Count[node, symbolNode[nodeName[#]], Infinity] === 1 &]

unusedLocalIssues[source_Association] :=
	namedIssues[
		"UnusedLocal",
		Catenate[unusedSymbols /@ scopingDeclarations[source["Abstract"], "Module" | "With" | "DynamicModule"]],
		" is declared but never used"
	]

literalIndexQ[LeafNode["Integer", __]] := True
literalIndexQ[_] := False

fixedSpanQ[callNode["Span", {LeafNode["Integer", "2", _], symbolNode["All"]}]] := True
fixedSpanQ[callNode["Span", {LeafNode["Integer", "1", _], LeafNode["Integer", "-2", _]}]] := True
fixedSpanQ[_] := False

partIssues[source_Association] :=
	Join[
		issuesAt["PartLiteral", Cases[source["Abstract"], callNode["Part", {_, __?literalIndexQ}], Infinity], "Part with a fixed position"],
		issuesAt["PartLiteral", Cases[source["Abstract"], callNode["Part", {_, _?fixedSpanQ}], Infinity], "Part in place of Rest or Most"]
	]

patternArgumentQ[$comparisonHeads, _Integer] := True
patternArgumentQ["Rule" | "RuleDelayed" | "Set" | "SetDelayed", 1] := True
patternArgumentQ["Switch", position_Integer] := EvenQ[position]
patternArgumentQ[_String, _Integer] := False

failedUses[node : symbolNode["$Failed"], False] := {node}
failedUses[CallNode[LeafNode["Symbol", head_String, _], arguments_List, _], patternQ : (True | False)] :=
	Catenate @ MapIndexed[
		Function[{argument, position}, failedUses[argument, patternQ || patternArgumentQ[head, First[position]]]],
		arguments
	]
failedUses[CallNode[head_CallNode, arguments_List, _], patternQ : (True | False)] :=
	Catenate[Map[Function[part, failedUses[part, patternQ]], Prepend[arguments, head]]]
failedUses[_, _] := {}

failedIssues[source_Association] :=
	issuesAt["BareFailed", Catenate[Map[Function[statement, failedUses[statement, False]], source["Abstract"]]], "$Failed is produced as a value"]

optionValueQ[callNode["OptionValue"]] := True
optionValueQ[_] := False

conditionNodes[statements_List] :=
	Join[
		Cases[statements, callNode["If", {test_, ___}] :> test, Infinity],
		Catenate @ Cases[statements, callNode["And" | "Or" | "Not", arguments_List] :> arguments, Infinity],
		Catenate @ Cases[statements, callNode["Which", arguments_List] :> Downsample[arguments, 2], Infinity]
	]

optionValueIssues[source_Association] :=
	issuesAt["OptionValueTest", Select[conditionNodes[source["Abstract"]], optionValueQ], "OptionValue is tested directly"]

loadIssues[source_Association] := namedIssues["ClearAtLoad", Cases[source["Abstract"], callNode["Clear" | "ClearAll" | "Remove"], {1}], " at load time"]

allowedQualifiedQ["Test", name_String] := StringContainsQ[name, "`PackageScope`"]
allowedQualifiedQ[_String, _String] := False

qualifiedSymbolIssues[source_Association] :=
	Module[{qualified},
		qualified = Cases[source["Abstract"], symbolNode[name_String /; StringContainsQ[name, "`"]], Infinity];
		namedIssues["QualifiedSymbol", Select[qualified, !allowedQualifiedQ[source["Kind"], nodeName[#]] &], ""]
	]

shortNameQ[name_String] := StringLength[StringDelete[name, StartOfString ~~ "$"]] < 3

shortNameIssues[source_Association] :=
	Module[{patternNames, localNames},
		patternNames = Cases[source["Abstract"], callNode["Pattern", {symbol : symbolNode[_String?shortNameQ], _}] :> symbol, Infinity];
		localNames = Catenate[Last /@ scopingDeclarations[source["Abstract"], "Module" | "With" | "Block" | "DynamicModule"]];
		Join[
			namedIssues["ShortName", patternNames, " is a pattern name"],
			namedIssues["ShortName", Select[localNames, shortNameQ[nodeName[#]] &], " is a local variable"]
		]
	]

pureFunctionIssues[source_Association] :=
	Module[{bodies},
		bodies = Cases[source["Abstract"], CallNode[LeafNode["Symbol", "Function", None], {body_}, _] :> body, Infinity];
		issuesAt["NestedPureFunction", Catenate[Map[Function[body, Cases[body, $slotFunction, {0, Infinity}]], bodies]], "a slot function inside a slot function"]
	]

colorUses[node : symbolNode[$colorNames], False] := {node}
colorUses[node : callNode[$colorHeads], False] := {node}
colorUses[callNode["LightDarkSwitched"], _] := {}
colorUses[CallNode[head_, arguments_List, _], switchedQ : (True | False)] :=
	Catenate[Map[Function[part, colorUses[part, switchedQ]], Prepend[arguments, head]]]
colorUses[_, _] := {}

visualizationIssues[source_Association] :=
	Module[{statements, unframedPlots},
		statements = source["Abstract"];
		unframedPlots = Select[Cases[statements, callNode[$framedPlotHeads], Infinity], FreeQ[#, symbolNode["Frame"]] &];
		Join[
			issuesAt[
				"HardCodedColor",
				Catenate[Map[Function[statement, colorUses[statement, False]], statements]],
				"a literal color outside LightDarkSwitched"
			],
			issuesAt[
				"HardCodedColor",
				Cases[statements, callNode["Rule", {symbolNode["Background"], symbolNode["White" | "Black"]}], Infinity],
				"a pinned white or black background"
			],
			namedIssues["CrossingAxes", Cases[statements, symbolNode["AxesLabel" | "Ticks"], Infinity], ""],
			issuesAt["CrossingAxes", Cases[statements, callNode["Rule", {symbolNode["Axes"], symbolNode["True"]}], Infinity], "Axes -> True"],
			namedIssues["UnframedPlot", unframedPlots, " without Frame"]
		]
	]

loadsItselfQ[statements_List] :=
	Or[
		!FreeQ[statements, callNode["PacletDirectoryLoad", {callNode["DirectoryName", {symbolNode["$TestFileName"], _}]}]],
		AnyTrue[Cases[statements, callNode["Get"], Infinity], !FreeQ[#, symbolNode["$TestFileName"]] &]
	]

testIssues[source_Association] :=
	Module[{statements, tests},
		statements = source["Abstract"];
		tests = Cases[statements, callNode["VerificationTest"], Infinity];
		Join[
			namedIssues["TestPrint", Cases[statements, symbolNode["Print"], Infinity], ""],
			issuesAt[
				"MissingTestID",
				Select[tests, FreeQ[#, callNode["Rule", {symbolNode["TestID"], _}]] &],
				"VerificationTest without a TestID"
			],
			If[loadsItselfQ[statements], {}, {styleIssue["TestHeader", {1, 1}, "the file does not load what it tests from its own location"]}]
		]
	]

styleCodeIssues[source_Association] :=
	Join[
		bannedIssues[source],
		withIssues[source],
		unusedLocalIssues[source],
		partIssues[source],
		failedIssues[source],
		optionValueIssues[source],
		loadIssues[source],
		qualifiedSymbolIssues[source],
		shortNameIssues[source],
		pureFunctionIssues[source],
		visualizationIssues[source],
		testIssues[source]
	]

(* ::Subsection:: *)
(*Definitions*)

topLevelStatements[nodes_List] :=
	DeleteCases[Flatten[Replace[nodes, callNode["CompoundExpression", statements_List] :> statements, {1}], 1], symbolNode["Null"]]

definitionPattern[callNode["Condition" | "HoldPattern", {inner_, ___}]] := definitionPattern[inner]
definitionPattern[left_] := left

innermostHeadName[CallNode[head_CallNode, _List, _]] := innermostHeadName[head]
innermostHeadName[CallNode[LeafNode["Symbol", name_String, _], _List, _]] := name
innermostHeadName[_] := None

definitionTarget[LeafNode["Symbol", name_String, _]] := <|"Symbol" -> name, "Kind" -> "Parameter"|>
definitionTarget[callNode["MessageName", {LeafNode["Symbol", name_String, _], LeafNode["String", tag_String, _], ___}]] :=
	<|"Symbol" -> name, "Kind" -> "Message", "Tag" -> StringDelete[tag, "\""]|>
definitionTarget[CallNode[LeafNode["Symbol", name_String, _], _List, _]] :=
	<|"Symbol" -> name, "Kind" -> If[NameQ["System`" <> name], "System", "Function"]|>
definitionTarget[node : CallNode[_CallNode, _List, _]] := <|"Symbol" -> innermostHeadName[node], "Kind" -> "SubValue"|>
definitionTarget[_] := <|"Symbol" -> None, "Kind" -> "Other"|>

definitionRecord[statement : callNode["Set" | "SetDelayed" | "UpSet" | "UpSetDelayed", {left_, right_}]] :=
	Module[{pattern, conditionQ},
		pattern = definitionPattern[left];
		conditionQ = MatchQ[left, callNode["Condition"]] || MatchQ[right, callNode["Condition"]];
		Join[definitionTarget[pattern], <|"Left" -> pattern, "Right" -> right, "Line" -> nodeLine[statement], "Condition" -> conditionQ|>]
	]
definitionRecord[_] := Missing["NotADefinition"]

(* A name written in the source has a source span; the List head of the braces does not. *)
exportedSymbolNodes[statements_List] :=
	Module[{declarations},
		declarations = Cases[statements, callNode["PackageExported", {argument_}] :> argument, {1}];
		Cases[declarations, LeafNode["Symbol", _String, {__}], {1, Infinity}]
	]

exportedNames[statements_List] := Cases[exportedSymbolNodes[statements], LeafNode["Symbol", name_String, _] :> name]

definitionLeftSides[statements_List] :=
	Module[{leftSides},
		leftSides = Cases[statements, callNode["SetDelayed" | "Set" | "UpSetDelayed" | "TagSetDelayed", {___, left_, _}] :> definitionPattern[left], {0, Infinity}];
		Cases[leftSides, _CallNode]
	]

argumentPatternIssues[source_Association] :=
	Module[{leftSides},
		leftSides = definitionLeftSides[source["Abstract"]];
		Join[
			issuesAt["OptionalArgument", Cases[leftSides, callNode["Optional"], Infinity], "an argument with a default value"],
			issuesAt["OptionQPattern", Cases[leftSides, callNode["PatternTest", {_, symbolNode["OptionQ"]}], Infinity], "options taken with ?OptionQ"]
		]
	]

definitionsOfKind[source_Association, kinds : (_String | _Alternatives)] := Select[source["Definitions"], MatchQ[#Kind, kinds] &]

definitionIssue[rule_String, definition_Association, suffix_String] := styleIssue[rule, {definition["Line"], 1}, definition["Symbol"] <> suffix]

parameterNameIssues[source_Association] :=
	Map[
		Function[definition, definitionIssue["ParameterName", definition, " is a file-level value"]],
		Select[definitionsOfKind[source, "Parameter"], !StringStartsQ[#Symbol, "$"] &]
	]

firstDefinitions[definitions : {___Association}] := Values @ Map[First, GroupBy[definitions, #Symbol &]]

missingUsageIssues[source_Association, index_Association] :=
	Map[
		Function[definition, definitionIssue["MissingUsage", definition, " has no usage message"]],
		Select[firstDefinitions @ definitionsOfKind[source, "Function" | "SubValue" | "Parameter"], !MemberQ[index["Usages"], #Symbol] &]
	]

(* The node holds a string literal, so ToExpression only reads the string, with its escapes and line continuations. *)
usageText[LeafNode["String", literal_String, _]] := ToExpression[literal]
usageText[_] := None

templateQ[name_String, text_String] :=
	StringMatchQ[First @ StringSplit[text, "\n"], (name ~~ "[" ~~ ___ ~~ "]" ~~ " " ~~ __) | (name ~~ " " ~~ __)]
templateQ[_String, None] := False

usageFormatIssues[source_Association] :=
	Module[{messages},
		messages = definitionsOfKind[source, "Message"];
		Join[
			Map[
				Function[definition, definitionIssue["UsageFormat", definition, " has a usage message without its calling template"]],
				Select[messages, #Tag === "usage" && !templateQ[#Symbol, usageText[#Right]] &]
			],
			Map[Function[definition, definitionIssue["OwnArgsMessage", definition, "::args is defined"]], Select[messages, #Tag === "args" &]]
		]
	]

$anySequence = {callNode["Pattern", {_, callNode["BlankNullSequence", {}]}] | callNode["BlankNullSequence", {}]};

catchAllQ[definition_Association] :=
	And[
		MatchQ[definition["Left"], callNode[definition["Symbol"], $anySequence]],
		If[StringEndsQ[definition["Symbol"], "Q"],
			MatchQ[definition["Right"], symbolNode["False"]],
			!FreeQ[definition["Right"], symbolNode[name_String /; StringEndsQ[name, "Failure"]]]
		]
	]

bareArgumentQ[callNode["Pattern", {_, callNode["Blank", {}]}]] := True
bareArgumentQ[callNode["Blank", {}]] := True
bareArgumentQ[_] := False

argumentNodes[CallNode[head_CallNode, arguments_List, _]] := Join[argumentNodes[head], arguments]
argumentNodes[CallNode[_LeafNode, arguments_List, _]] := arguments
argumentNodes[_] := {}

catchAllIssues[definitions : {___Association}] :=
	Map[
		Function[group, definitionIssue["MissingCatchAll", First[group], " has no final catch-all definition"]],
		Select[Values @ GroupBy[definitions, #Symbol &], !catchAllQ[Last[#]] &]
	]

(* A helper may end with a definition that takes any argument, after definitions with specific patterns. Such a
   fallback is not reported: an argument of a helper is reported only when no definition of the helper with the
   same number of arguments gives that argument a pattern. A public function has the catch-all for that, so each
   of its bare blanks is reported. *)
bareArguments[definition_Association] := Select[argumentNodes[definition["Left"]], bareArgumentQ]

alwaysBareArguments[definitions : {__Association}] :=
	Module[{argumentLists, bareTables},
		argumentLists = Map[Function[definition, argumentNodes[definition["Left"]]], definitions];
		bareTables = Map[Function[arguments, Map[bareArgumentQ, arguments]], argumentLists];
		Catenate @ MapThread[
			Function[{arguments, bareTable},
				Pick[arguments, MapThread[And, Cases[bareTables, otherTable_ /; Length[otherTable] === Length[bareTable]]]]
			],
			{argumentLists, bareTables}
		]
	]

bareArgumentIssues[name_String, arguments_List] := issuesAt["BarePattern", arguments, "an argument of " <> name <> " is a bare blank"]

argumentIssues[source_Association, index_Association] :=
	Module[{definitions, publicDefinitions, helperGroups},
		definitions = Select[definitionsOfKind[source, "Function" | "SubValue"], !#Condition &];
		publicDefinitions = Select[definitions, MemberQ[index["Exported"], #Symbol] &];
		helperGroups = GroupBy[Complement[definitions, publicDefinitions], #Symbol &];
		Join[
			Catenate @ Map[Function[definition, bareArgumentIssues[definition["Symbol"], bareArguments[definition]]], publicDefinitions],
			Catenate @ KeyValueMap[Function[{name, group}, bareArgumentIssues[name, alwaysBareArguments[group]]], helperGroups]
		]
	]

publicFunctionIssues[source_Association, index_Association] :=
	catchAllIssues[Select[definitionsOfKind[source, "Function"], MemberQ[index["Exported"], #Symbol] &]]

shadowingNodes[source_Association, functionNames : {___String}] :=
	Module[{patternNames, localNames},
		patternNames = Cases[source["Abstract"], callNode["Pattern", {symbol : symbolNode[_String], _}] :> symbol, Infinity];
		localNames = Catenate[Last /@ scopingDeclarations[source["Abstract"], "Module" | "With" | "Block" | "DynamicModule"]];
		Cases[Join[patternNames, localNames], symbolNode[name_String /; MemberQ[functionNames, name]]]
	]

collisionIssues[source_Association, index_Association] :=
	Join[
		namedIssues[
			"SystemNameCollision",
			Cases[exportedSymbolNodes[source["Abstract"]], symbolNode[name_String /; NameQ["System`" <> name]]],
			" is a System symbol"
		],
		Map[
			Function[definition, definitionIssue["SystemNameCollision", definition, " is a System symbol"]],
			Select[definitionsOfKind[source, "Parameter"], NameQ["System`" <> #Symbol] &]
		],
		namedIssues["LocalShadowsFunction", shadowingNodes[source, index["Functions"]], " is also the name of a function"]
	]

styleDefinitionIssues[source_Association, index_Association] :=
	Join[
		argumentPatternIssues[source],
		parameterNameIssues[source],
		missingUsageIssues[source, index],
		usageFormatIssues[source],
		publicFunctionIssues[source, index],
		argumentIssues[source, index],
		collisionIssues[source, index]
	]
