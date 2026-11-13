(* Tests for Kernel/Evaluate.wl that need no GP: the options, what a call or an evaluation gives before it reaches a
   session, and the output modes. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`PARILink`"]

output = WolframInstitute`PARILink`PackageScope`pariOutput;

unknownSession = PARISession["unavailable"];

(* The tag of a Failure, or the value itself. *)
failureTag[Failure[tag_, _]] := tag
failureTag[value_] := value

VerificationTest[
	{Options[PARIEvaluate], Options[PARICall]},
	{
		{TimeConstraint -> 30, "ReturnType" -> Automatic, "Output" -> "Print"},
		{TimeConstraint -> 30, "ReturnType" -> Automatic, "Output" -> "Print"}
	},
	TestID -> "evaluation-defaults"
]

VerificationTest[
	Map[
		failureTag[PARIEvaluate[unknownSession, "1", #]] &,
		{"Typo" -> 1, "ReturnType" -> "Invalid", "Output" -> "Invalid", TimeConstraint -> 0}
	],
	ConstantArray["PARIInvalidOption", 4],
	TestID -> "evaluation-option-validation"
]

VerificationTest[
	failureTag[PARICall[unknownSession, "factor);quit(", 10]],
	"PARIInvalidFunction",
	TestID -> "function-name-cannot-inject-code"
]

VerificationTest[
	failureTag[PARIEvaluate[unknownSession, "1"]],
	"PARIInvalidSession",
	TestID -> "unknown-session"
]

VerificationTest[
	failureTag[PARIEvaluate[unknownSession, "1" <> FromCharacterCode[0]]],
	"PARIUnsupportedValue",
	TestID -> "source-cannot-contain-null"
]

VerificationTest[
	{failureTag[PARICall[unknownSession, "factor", 1.5]], failureTag[PARICall[unknownSession, "factor", {1, {2, Pi}}]]},
	{"PARIUnsupportedValue", "PARIUnsupportedValue"},
	TestID -> "unsupported-arguments-are-not-sent"
]

(* A session whose form is not that of a session gives a Failure, as its properties do. *)
VerificationTest[
	{PARIEvaluate[PARISession[1], "1"], failureTag[PARICall[PARISession[], "factor", 6]]},
	{Failure["PARIInvalidSession", <|"MessageTemplate" -> "This PARI session is not valid."|>], "PARIInvalidSession"},
	TestID -> "a-session-of-another-form-gives-a-failure"
]

(* A call that matches no form gives the Failure of the catch-all and the message of the function. *)
VerificationTest[
	{First[PARIEvaluate[]], First[PARIEvaluate[None, "1"]]},
	{"InvalidArguments", "InvalidArguments"},
	{PARIEvaluate::args, PARIEvaluate::args},
	TestID -> "reject-evaluations-of-another-form"
]

VerificationTest[
	{First[PARICall[unknownSession]], First[PARICall[unknownSession, 1]]},
	{"InvalidArguments", "InvalidArguments"},
	{PARICall::args, PARICall::args},
	TestID -> "reject-calls-of-another-form"
]

VerificationTest[
	Module[{response, failure},
		response = <|"Result" -> 5, "StandardOutput" -> "printed", "StandardError" -> ""|>;
		failure = Failure["PARIError", <|"MessageTemplate" -> "PARI/GP could not evaluate the expression."|>];
		{
			output[response, "Discard"],
			output[response, "Capture"],
			output[Append[response, "Result" -> failure], "Capture"],
			output[failure, "Capture"]
		}
	],
	{
		5,
		<|"Result" -> 5, "StandardOutput" -> "printed", "StandardError" -> ""|>,
		Failure["PARIError", <|"MessageTemplate" -> "PARI/GP could not evaluate the expression.", "StandardOutput" -> "printed", "StandardError" -> ""|>],
		Failure["PARIError", <|"MessageTemplate" -> "PARI/GP could not evaluate the expression."|>]
	},
	TestID -> "output-modes-discard-and-capture"
]
