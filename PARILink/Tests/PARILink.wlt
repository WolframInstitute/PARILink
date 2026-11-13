(* Tests of the paclet as a whole: its public symbols, and that loading it starts nothing. They need no GP. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`PARILink`"]

VerificationTest[
	Names["WolframInstitute`PARILink`*"],
	{"PARICall", "PARIEvaluate", "PARIObject", "PARISession", "StartPARISession"},
	TestID -> "public-api"
]

(* Other test files record sessions without a process, so the test looks for a process, not for an empty record. *)
VerificationTest[
	FreeQ[WolframInstitute`PARILink`PackageScope`$pariSessions, _ProcessObject],
	True,
	TestID -> "loading-does-not-start-a-session"
]

VerificationTest[
	AllTrue[{PARICall, PARIEvaluate, PARIObject, PARISession, StartPARISession}, StringQ[MessageName[#, "usage"]] &],
	True,
	TestID -> "every-public-symbol-has-a-usage-message"
]
