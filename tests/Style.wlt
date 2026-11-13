(* Tests for scripts/style*.wl: each rule of the style check on a small piece of code that breaks it,
   code that follows the guides, the allow comments and the mechanical fixes. *)

Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "scripts", "run.wls"}]]["Load"]
Needs["PARILink`Scripts`"]

(* The names of the rules that a piece of code breaks. *)
brokenRules[text_String, kind_String] := Union[Lookup[StyleIssues[text, kind], "Rule", {}]]

(* A kernel file that follows the guides: usage messages, specific patterns, a catch-all and a predicate. *)
$goodKernelFile = "(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{StepTotal, StepListQ}];

(* ::Section:: *)
(*Usage Messages*)

StepTotal::usage = \"StepTotal[steps] gives the total of a list of step counts.\\n\\
StepTotal[steps, weight] multiplies each step count by weight.\";
StepListQ::usage = \"StepListQ[steps] gives True when steps is a list of nonnegative integers.\";
weightedSteps::usage = \"weightedSteps[steps, weight] gives each step count times weight.\";
$defaultWeight::usage = \"$defaultWeight is the weight used when none is given.\";

(* ::Section:: *)
(*Function Definitions*)

$defaultWeight = 1;

weightedSteps[steps : {___Integer}, weight_Integer] := weight * steps

StepListQ[steps : {___Integer?NonNegative}] := True
StepListQ[___] := False

StepTotal[steps_?StepListQ, weight_Integer] :=
	Enclose @ Module[{weighted},
		weighted = weightedSteps[steps, weight];
		ConfirmBy[Total[weighted], IntegerQ, \"the total is not an integer.\"]
	]
StepTotal[steps_?StepListQ] := StepTotal[steps, $defaultWeight]
StepTotal[args___] := (
	Message[StepTotal::args, StepTotal];
	Failure[\"InvalidArguments\", <|\"MessageTemplate\" -> StepTotal::args, \"MessageParameters\" -> {StepTotal}|>]
)
";

VerificationTest[
	StyleIssues[$goodKernelFile, "Kernel"],
	{},
	TestID -> "Style-GoodKernelFile-HasNoIssues"
]

VerificationTest[
	AllTrue[$StyleRules, Sort[Keys[#]] === {"Allow", "Guide", "Kinds", "Summary"} &],
	True,
	TestID -> "Style-Rules-HaveGuideSummaryKindsAllow"
]

(* The page of the coding guides lists every rule, as make style-rules writes them. *)
VerificationTest[
	StringContainsQ[
		PARILink`Scripts`PackageScope`readText[FileNameJoin[{$RepositoryRoot, "docs", "coding-guides", "README.md"}]],
		PARILink`Scripts`PackageScope`styleRulesTable[]
	],
	True,
	TestID -> "Style-RulesTable-IsCurrentInTheGuidesPage"
]

(* Formatting *)

VerificationTest[
	brokenRules["double[value_Integer] :=\n    2 * value\n", "Program"],
	{"TabIndentation"},
	TestID -> "Style-TabIndentation"
]

VerificationTest[
	brokenRules["total = " <> StringRepeat["1 + ", 60] <> "1\n", "Program"],
	{"LineWidth"},
	TestID -> "Style-LineWidth"
]

VerificationTest[
	{
		brokenRules["label = \"caf" <> FromCharacterCode[233] <> "\"\n", "Program"],
		brokenRules["(* first " <> FromCharacterCode[8212] <> " second *)\nvalue = 1\n", "Program"],
		brokenRules["(* the rate " <> FromCharacterCode[955] <> " *)\nvalue = 1\n", "Program"]
	},
	{{"NonASCIICharacter"}, {"NonASCIICharacter"}, {}},
	TestID -> "Style-NonASCIICharacter-CodeAndCommentDashes"
]

VerificationTest[
	brokenRules["(* first " <> "--" <> " second *)\nvalue = 1\n", "Program"],
	{"DoubleHyphen"},
	TestID -> "Style-DoubleHyphen"
]

VerificationTest[
	{brokenRules["(*note*)\nvalue = 1\n", "Program"], brokenRules["(* ::Section:: *)\n(*Title*)\nvalue = 1\n", "Program"]},
	{{"CommentSpacing"}, {}},
	TestID -> "Style-CommentSpacing-CellTitleExempt"
]

VerificationTest[
	brokenRules["(* outer (* inner *) text *)\nvalue = 1\n", "Program"],
	{"NestedComment"},
	TestID -> "Style-NestedComment"
]

VerificationTest[
	{
		brokenRules["total = first+second\n", "Program"],
		brokenRules["double[value_ ? IntegerQ] := 2 * value\n", "Program"],
		brokenRules["double[value_?IntegerQ] := 2 * value\n", "Program"]
	},
	{{"OperatorSpacing"}, {"OperatorSpacing"}, {}},
	TestID -> "Style-OperatorSpacing-SpacedAndTight"
]

VerificationTest[
	{brokenRules["pair = {1,2}\n", "Program"], brokenRules["pair = {1 , 2}\n", "Program"]},
	{{"CommaSpacing"}, {"CommaSpacing"}},
	TestID -> "Style-CommaSpacing"
]

VerificationTest[
	brokenRules["pair = {\n\t1\n\t, 2\n}\n", "Program"],
	{"CommaPlacement"},
	TestID -> "Style-CommaPlacement"
]

(* A comma after a string that wraps over lines does not start its line. *)
VerificationTest[
	brokenRules["pair = {\n\t\"a string \\\ncontinued\", 2\n}\n", "Program"],
	{},
	TestID -> "Style-CommaPlacement-AfterAWrappedString"
]

VerificationTest[
	{brokenRules["total = first +\n\tsecond\n", "Program"], brokenRules["total =\n\tfirst + second\n", "Program"]},
	{{"SplitOperator"}, {}},
	TestID -> "Style-SplitOperator-AssignmentMayBreak"
]

VerificationTest[
	brokenRules["first = 1; second = 2\n", "Program"],
	{"StatementPerLine"},
	TestID -> "Style-StatementPerLine"
]

VerificationTest[
	{
		brokenRules["increment[value_Integer] := Module[{total},\n\ttotal = value + 1;\n]\n", "Program"],
		brokenRules["If[test, first;, second]\n", "Program"]
	},
	{{"HangingSemicolon"}, {"HangingSemicolon"}},
	TestID -> "Style-HangingSemicolon"
]

VerificationTest[
	brokenRules["part = list[[first ;;\n\tlast]]\n", "Program"],
	{"TrailingSpan"},
	TestID -> "Style-TrailingSpan"
]

VerificationTest[
	{
		brokenRules["increment[value_Integer] := Module[{total},\n\ttotal = value + 1;\n\ttotal]\n", "Program"],
		brokenRules["values = {\n\t1,\n\t2\n\t}\n", "Program"],
		brokenRules["values = {\n\t1,\n\t2\n}\n", "Program"]
	},
	{{"BracketAlignment"}, {"BracketAlignment"}, {}},
	TestID -> "Style-BracketAlignment"
]

VerificationTest[
	brokenRules["text = \"first\nsecond\"\n", "Program"],
	{"StringLineBreak"},
	TestID -> "Style-StringLineBreak"
]

VerificationTest[
	MemberQ[brokenRules["double[value_ := 1\n", "Program"], "SyntaxError"],
	True,
	TestID -> "Style-SyntaxError"
]

(* Syntax *)

VerificationTest[
	{
		brokenRules["total = list // Total\n", "Program"],
		brokenRules["joined = first ~Join~ second\n", "Program"],
		brokenRules["total = Total @ (first + second)\n", "Program"]
	},
	{{"PostfixApplication"}, {"InfixApplication"}, {"PrefixApplication"}},
	TestID -> "Style-Application-PostfixInfixPrefix"
]

VerificationTest[
	{
		brokenRules["lists = Map[Select[#, # > 1 &] &, data]\n", "Program"],
		brokenRules["lists = Map[Function[list, Select[list, # > 1 &]], data]\n", "Program"]
	},
	{{"NestedPureFunction"}, {}},
	TestID -> "Style-NestedPureFunction"
]

VerificationTest[
	{brokenRules["test = Head[value] === List\n", "Program"], brokenRules["test = And @@ flags\n", "Program"]},
	{{"HeadComparison"}, {"ApplyAndOr"}},
	TestID -> "Style-HeadComparison-ApplyAndOr"
]

(* Constructs *)

VerificationTest[
	{
		brokenRules["increment[value_Integer] := Module[{total},\n\ttotal = value + 1;\n\tReturn[total]\n]\n", "Program"],
		brokenRules["Do[report[index], {index, 3}]\n", "Program"],
		brokenRules["AppendTo[results, 1]\n", "Program"],
		brokenRules["double[value_Integer] := Scope[2 * value]\n", "Program"]
	},
	{{"ReturnCall"}, {"ProceduralLoop"}, {"AppendTo"}, {"ScopeConstruct"}},
	TestID -> "Style-BannedConstructs"
]

VerificationTest[
	{
		brokenRules["sum[value_Integer] := With[{first = value + 1, second = value + 2, third = value + 3}, first + second + third]\n", "Program"],
		brokenRules["sum[value_Integer] := With[{first = value + 1}, first]\n", "Program"],
		brokenRules["With[{limit = 3, start = 1, step = 2}, sum[value_Integer] := value + limit + start + step]\n", "Program"],
		brokenRules["sum[value_Integer] := With[{first = value}, With[{second = first}, second]]\n", "Program"]
	},
	{{"WithBindings"}, {}, {}, {"NestedWith"}},
	TestID -> "Style-With-ComputationConstantHeldNested"
]

VerificationTest[
	brokenRules["double[value_Integer] := Module[{unused},\n\t2 * value\n]\n", "Program"],
	{"UnusedLocal"},
	TestID -> "Style-UnusedLocal"
]

VerificationTest[
	{
		brokenRules["shift[value_Integer, step_Integer : 1] := value + step\n", "Program"],
		brokenRules["shift[value_Integer, opts___?OptionQ] := value\n", "Program"]
	},
	{{"OptionalArgument"}, {"OptionQPattern"}},
	TestID -> "Style-ArgumentPatterns-OptionalAndOptionQ"
]

VerificationTest[
	{brokenRules["result = Quiet[1 / 0]\n", "Program"], brokenRules["result = Quiet[1 / 0, Power::infy]\n", "Program"]},
	{{"UntaggedControl"}, {}},
	TestID -> "Style-UntaggedControl"
]

VerificationTest[
	{
		brokenRules["first = list[[1]]\n", "Program"],
		brokenRules["rest = list[[2 ;;]]\n", "Program"],
		brokenRules["item = list[[index]]\n", "Program"]
	},
	{{"PartLiteral"}, {"PartLiteral"}, {}},
	TestID -> "Style-PartLiteral"
]

VerificationTest[
	{
		brokenRules["checked[value_Integer] := If[value > 0, value, $Failed]\n", "Program"],
		brokenRules["test = result === $Failed\n", "Program"]
	},
	{{"BareFailed"}, {}},
	TestID -> "Style-BareFailed-ComparisonAllowed"
]

VerificationTest[
	{
		brokenRules["flagged[opts : OptionsPattern[]] := If[OptionValue[\"Flag\"], 1, 2]\n", "Program"],
		brokenRules["flagged[opts : OptionsPattern[]] := If[TrueQ[OptionValue[\"Flag\"]], 1, 2]\n", "Program"]
	},
	{{"OptionValueTest"}, {}},
	TestID -> "Style-OptionValueTest"
]

VerificationTest[
	{brokenRules["ClearAll[helper]\n", "Kernel"], brokenRules["value = Internal`Bag[]\n", "Program"]},
	{{"ClearAtLoad"}, {"QualifiedSymbol"}},
	TestID -> "Style-ClearAtLoad-QualifiedSymbol"
]

(* Naming and documentation *)

VerificationTest[
	{
		brokenRules["double[n_Integer] := 2 * n\n", "Program"],
		brokenRules["double[count_Integer] := Module[{k},\n\tk = 2 * count;\n\tk\n]\n", "Program"]
	},
	{{"ShortName"}, {"ShortName"}},
	TestID -> "Style-ShortName-PatternAndLocal"
]

VerificationTest[
	brokenRules[
		"helper::usage = \"helper[value] gives value.\";\nother::usage = \"other[helper] gives helper.\";\nhelper[value_Integer] := value\nother[helper_Integer] := helper\n",
		"Kernel"
	],
	{"LocalShadowsFunction"},
	TestID -> "Style-LocalShadowsFunction"
]

VerificationTest[
	{
		brokenRules["PackageExported[Map];\n", "Kernel"],
		brokenRules["limit::usage = \"limit is the largest size.\";\nlimit = 10;\n", "Kernel"]
	},
	{{"SystemNameCollision"}, {"ParameterName"}},
	TestID -> "Style-SystemNameCollision-ParameterName"
]

VerificationTest[
	{
		brokenRules["helper[value_Integer] := value\n", "Kernel"],
		brokenRules["helper::usage = \"gives the value.\";\nhelper[value_Integer] := value\n", "Kernel"],
		brokenRules["helper::usage = \"helper[value] gives value.\";\nhelper::args = \"Bad arguments.\";\nhelper[value_Integer] := value\n", "Kernel"]
	},
	{{"MissingUsage"}, {"UsageFormat"}, {"OwnArgsMessage"}},
	TestID -> "Style-Usage-MissingFormatOwnArgs"
]

VerificationTest[
	{
		brokenRules["PackageExported[Twofold];\nTwofold::usage = \"Twofold[value] gives twice value.\";\nTwofold[value_Integer] := 2 * value\n", "Kernel"],
		brokenRules[
			"PackageExported[EvenValueQ];\nEvenValueQ::usage = \"EvenValueQ[value] gives True for an even value.\";\nEvenValueQ[value_Integer] := EvenQ[value]\nEvenValueQ[___] := False\n",
			"Kernel"
		]
	},
	{{"MissingCatchAll"}, {}},
	TestID -> "Style-MissingCatchAll-PredicateEndsWithFalse"
]

VerificationTest[
	brokenRules[
		StringJoin[
			"PackageExported[Twofold];\n",
			"Twofold::usage = \"Twofold[value] gives twice value.\";\n",
			"argumentsFailure::usage = \"argumentsFailure[function] gives a Failure.\";\n",
			"argumentsFailure[function_Symbol] := Failure[\"InvalidArguments\", <||>]\n",
			"Twofold[value_] := 2 * value\n",
			"Twofold[args___] := argumentsFailure[Twofold]\n"
		],
		"Kernel"
	],
	{"BarePattern"},
	TestID -> "Style-BarePattern"
]

VerificationTest[
	{
		brokenRules["helper::usage = \"helper[value] gives value.\";\nhelper[value_] := value\n", "Kernel"],
		brokenRules["helper::usage = \"helper[value] gives value.\";\nhelper[value_Integer] := value\nhelper[_] := 0\n", "Kernel"]
	},
	{{"BarePattern"}, {}},
	TestID -> "Style-BarePattern-HelperFallbackMayTakeAnything"
]

(* Visualization *)

VerificationTest[
	{
		brokenRules["$accent::usage = \"$accent is the accent color.\";\n$accent = Red;\n", "Kernel"],
		brokenRules["$accent::usage = \"$accent is the accent color.\";\n$accent = LightDarkSwitched[Red, Pink];\n", "Kernel"],
		brokenRules["$accent::usage = \"$accent is the accent color.\";\n$accent = StandardBlue;\n", "Kernel"],
		brokenRules["$labels::usage = \"$labels is the label option.\";\n$labels = AxesLabel -> {\"steps\", \"cells\"};\n", "Kernel"]
	},
	{{"HardCodedColor"}, {}, {}, {"CrossingAxes"}},
	TestID -> "Style-Colors-And-Axes"
]

VerificationTest[
	{
		brokenRules["curve::usage = \"curve[data] plots data.\";\ncurve[data_List] := ListLinePlot[data]\n", "Kernel"],
		brokenRules["curve::usage = \"curve[data] plots data.\";\ncurve[data_List] := ListLinePlot[data, Frame -> True, Axes -> False]\n", "Kernel"]
	},
	{{"UnframedPlot"}, {}},
	TestID -> "Style-UnframedPlot"
]

(* Tests *)

VerificationTest[
	{
		brokenRules["VerificationTest[1 + 1, 2, TestID -> \"sum\"]\n", "Test"],
		brokenRules["PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]\nNeeds[\"WolframInstitute`PARILink`\"]\n\nVerificationTest[1 + 1, 2, TestID -> \"sum\"]\n", "Test"],
		brokenRules["PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]\n\nVerificationTest[1 + 1, 2]\n", "Test"],
		brokenRules["PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]\n\nPrint[\"start\"]\n", "Test"],
		brokenRules[
			"PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]\n\nVerificationTest[WolframInstitute`PARILink`PackageScope`helper[1], 1, TestID -> \"scoped\"]\n",
			"Test"
		]
	},
	{{"TestHeader"}, {}, {"MissingTestID"}, {"TestPrint"}, {}},
	TestID -> "Style-TestFiles-HeaderIDPrintScopedNames"
]

(* Allow comments *)

VerificationTest[
	{
		brokenRules["(* allow PartLiteral: the parser gives a fixed pair *)\nfirst = pair[[1]]\n", "Program"],
		brokenRules["(* allow ReturnCall: wanted *)\nReturn[1]\n", "Program"],
		brokenRules["(* allow PartLiteral: nothing to waive *)\nvalue = 1\n", "Program"],
		brokenRules["(* allow NoSuchRule: reason *)\nvalue = 1\n", "Program"]
	},
	{{}, {"ReturnCall", "UnknownAllow"}, {"UnusedAllow"}, {"UnknownAllow"}},
	TestID -> "Style-AllowComments-WaiveOnlyWaivableRules"
]

VerificationTest[
	{First @ StyleIssues[1], First @ StyleIssues["missing file name"]},
	{"InvalidArguments", "InvalidArguments"},
	{StyleIssues::args, StyleIssues::args},
	TestID -> "Style-StyleIssues-InvalidArgumentsGiveFailure"
]

(* Mechanical fixes *)

VerificationTest[
	FixedStyleText["double[value_Integer] :=\n    2*value   \n", "Program"],
	"double[value_Integer] :=\n\t2 * value\n",
	TestID -> "Fix-TabsOperatorSpacingTrailingWhitespace"
]

VerificationTest[
	FixedStyleText["pair = {1,2 , 3}\n(*note*)\ntest[value_ ? IntegerQ] := value\n", "Program"],
	"pair = {1, 2, 3}\n(* note *)\ntest[value_?IntegerQ] := value\n",
	TestID -> "Fix-CommasCommentsTightOperators"
]

VerificationTest[
	FixedStyleText["increment[value_Integer] := Module[{total},\n\ttotal = value + 1; report[total];\n\ttotal]\n", "Program"],
	"increment[value_Integer] := Module[{total},\n\ttotal = value + 1;\n\treport[total];\n\ttotal\n]\n",
	TestID -> "Fix-StatementsAndClosingBracket"
]

VerificationTest[
	FixedStyleText["double::usage = \"double[value] gives twice value.\ndouble[value, count] repeats it.\";\n", "Program"],
	"double::usage = \"double[value] gives twice value.\\n\\\ndouble[value, count] repeats it.\";\n",
	TestID -> "Fix-MessageString-RawNewline"
]

VerificationTest[
	Module[{usageText, fixed},
		usageText = "double[value] " <> StringRepeat["gives twice the value and ", 12] <> "more.";
		fixed = FixedStyleText["double::usage = \"" <> usageText <> "\";\n", "Program"];
		{Max[StringLength /@ StringSplit[fixed, "\n"]] <= 150, ToExpression[StringDelete[fixed, "double::usage = " | ";\n"]] === usageText}
	],
	{True, True},
	TestID -> "Fix-MessageString-WrapKeepsTheText"
]

VerificationTest[
	FixedStyleText["Needs[\"WolframInstitute`PARILink`\"]\n\nVerificationTest[1 + 1, 2, TestID -> \"sum\"]\n", "Test", 3],
	"PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]\nNeeds[\"WolframInstitute`PARILink`\"]\n\nVerificationTest[1 + 1, 2, TestID -> \"sum\"]\n",
	TestID -> "Fix-TestHeader"
]

(* Running the fixes on their own output changes nothing, and text they do not own survives. *)
VerificationTest[
	Module[{once},
		once = FixedStyleText["(* a note *)\ndouble[value_Integer] :=\n    2*value\n\ntext = \"kept  as,is\"\n", "Program"];
		{FixedStyleText[once, "Program"] === once, StringContainsQ[once, "\"kept  as,is\""], FixedStyleText[$goodKernelFile, "Kernel"] === $goodKernelFile}
	],
	{True, True, True},
	TestID -> "Fix-RoundTrip-OwnOutputAndGoodFileUnchanged"
]

VerificationTest[
	First @ FixedStyleText[1, 2],
	"InvalidArguments",
	{FixedStyleText::args},
	TestID -> "Fix-FixedStyleText-InvalidArgumentsGiveFailure"
]
