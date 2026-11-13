(* Tests for Kernel/Internal/Failures.wl: the Failure of a call that matches no form, and the helpers that build
   PARILink's own failures and pass them up. They need no GP. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`PARILink`"]

invalidArgumentsFailure = WolframInstitute`PARILink`PackageScope`invalidArgumentsFailure;
innerFailure = WolframInstitute`PARILink`PackageScope`innerFailure;
pariFailure = WolframInstitute`PARILink`PackageScope`pariFailure;

(* A function of this test file that ends with the catch-all, as every public function does. *)
doubleCount[count_Integer?NonNegative] := 2 * count
doubleCount[___] := invalidArgumentsFailure[doubleCount]

VerificationTest[
	doubleCount[3],
	6,
	TestID -> "catch-all-leaves-valid-calls-alone"
]

VerificationTest[
	Module[{failure},
		failure = doubleCount["three"];
		{FailureQ[failure], First[failure], failure["MessageParameters"]}
	],
	{True, "InvalidArguments", {doubleCount}},
	{doubleCount::args},
	TestID -> "catch-all-gives-invalid-arguments-failure"
]

VerificationTest[
	StringContainsQ[doubleCount[]["Message"], "called with invalid parameters."],
	True,
	{doubleCount::args},
	TestID -> "catch-all-carries-the-generic-message"
]

VerificationTest[
	{
		pariFailure["PARIError", "PARI/GP could not evaluate the expression."],
		pariFailure["PARIExecutableNotFound", "The GP executable could not be found.", <|"Path" -> "gp"|>]
	},
	{
		Failure["PARIError", <|"MessageTemplate" -> "PARI/GP could not evaluate the expression."|>],
		Failure["PARIExecutableNotFound", <|"MessageTemplate" -> "The GP executable could not be found.", "Path" -> "gp"|>]
	},
	TestID -> "failure-has-the-message-then-the-data"
]

(* A helper's own Failure comes back from Enclose with its tag and its data, and the code after it does not run. *)
VerificationTest[
	Enclose[
		Confirm[pariFailure["PARIInvalidSession", "This PARI session is not valid."]];
		"reached",
		innerFailure
	],
	Failure["PARIInvalidSession", <|"MessageTemplate" -> "This PARI session is not valid."|>],
	TestID -> "inner-failure-keeps-a-confirmed-failure"
]

(* A Failure given as the last argument of a confirmation is the result when the confirmation fails. *)
VerificationTest[
	Enclose[
		ConfirmBy[-1, Positive, pariFailure["PARIInvalidOption", "TimeConstraint must be positive or Infinity."]];
		"reached",
		innerFailure
	],
	Failure["PARIInvalidOption", <|"MessageTemplate" -> "TimeConstraint must be positive or Infinity."|>],
	TestID -> "inner-failure-keeps-the-failure-of-a-confirmation"
]

VerificationTest[
	First @ Enclose[ConfirmAssert[1 === 2, "The numbers differ."], innerFailure],
	"ConfirmationFailed",
	TestID -> "inner-failure-keeps-a-failed-assertion"
]

VerificationTest[
	Enclose[Confirm[5], innerFailure],
	5,
	TestID -> "a-value-passes-the-confirmation"
]
