(* Tests for Kernel/Session.wl that need no GP: the options, what a start gives before GP runs, the properties and a
   session that is closed. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`PARILink`"]


(* A session of this kernel that is closed, as DeleteObject leaves it. Its state names no process. The state is
   added to the record of sessions itself, not to a copy. *)
closedSession[] :=
	Module[{sessionID},
		sessionID = CreateUUID[];
		AssociateTo[WolframInstitute`PARILink`PackageScope`$pariSessions, sessionID -> <|"Executable" -> "/test/gp", "Version" -> "2.19.0", "Status" -> "Closed"|>];
		PARISession[sessionID]
	]

(* The tag of a Failure, or the value itself. *)
failureTag[Failure[tag_, _]] := tag
failureTag[value_] := value

VerificationTest[
	Options[StartPARISession],
	{"Executable" -> Automatic, "StackLimit" -> 256 * 1024 ^ 2, TimeConstraint -> 30},
	TestID -> "session-defaults"
]

VerificationTest[
	Map[
		failureTag[StartPARISession[#]] &,
		{
			{"Typo" -> 1}, {"Executable" -> 42}, {"StackLimit" -> 0}, {"StackLimit" -> 8 * 1024 ^ 2 - 1},
			{"StackLimit" -> 1024. ^ 3}, {"StackLimit" -> Infinity}, {TimeConstraint -> -1}, {TimeConstraint -> 1 + I}
		}
	],
	ConstantArray["PARIInvalidOption", 8],
	TestID -> "start-option-validation"
]

VerificationTest[
	failureTag[StartPARISession["Executable" -> FileNameJoin[{$TemporaryDirectory, CreateUUID[]}]]],
	"PARIExecutableNotFound",
	TestID -> "missing-executable"
]

VerificationTest[
	failureTag[StartPARISession["Executable" -> ""]],
	"PARIExecutableNotFound",
	TestID -> "empty-executable-gives-a-failure-without-messages"
]

(* A call that matches no form gives the Failure of the catch-all and the message StartPARISession::args. *)
VerificationTest[
	Module[{failure},
		failure = StartPARISession[1];
		{First[failure], failure["MessageParameters"]}
	],
	{"InvalidArguments", {StartPARISession}},
	{StartPARISession::args},
	TestID -> "reject-session-arguments"
]

VerificationTest[
	Module[{session},
		session = closedSession[];
		{session["Status"], session["Version"], session["Executable"], session["Properties"], session["Process"], session["Other"]}
	],
	{"Closed", "2.19.0", "/test/gp", {"Status", "Version", "Executable", "Properties"}, Missing["UnknownProperty", "Process"], Missing["UnknownProperty", "Other"]},
	TestID -> "properties-of-a-closed-session"
]

VerificationTest[
	Module[{session},
		session = closedSession[];
		{DeleteObject[session], DeleteObject[session], session["Status"]}
	],
	{Null, Null, "Closed"},
	TestID -> "deleting-a-closed-session-again-gives-null"
]

VerificationTest[
	{
		PARISession["unavailable"]["Status"],
		PARISession[1]["Status"],
		DeleteObject[PARISession[1]],
		PARISession["unavailable"]["Properties"]
	},
	{
		Failure["PARIInvalidSession", <|"MessageTemplate" -> "This PARI session is not available in this kernel."|>],
		Failure["PARIInvalidSession", <|"MessageTemplate" -> "This PARI session is not valid."|>],
		Failure["PARIInvalidSession", <|"MessageTemplate" -> "This PARI session is not valid."|>],
		{"Status", "Version", "Executable", "Properties"}
	},
	TestID -> "a-session-that-is-not-known"
]

(* A property request that is not one name matches no form. *)
VerificationTest[
	{First[PARISession["unavailable"][1]], First[PARISession["unavailable"]["Status", "Version"]]},
	{"InvalidArguments", "InvalidArguments"},
	{PARISession::args, PARISession::args},
	TestID -> "reject-property-requests-of-another-form"
]

(* The boxes show the stored status. Showing a session asks GP nothing. *)
VerificationTest[
	{ToBoxes[closedSession[], StandardForm], ToBoxes[PARISession["unavailable"], StandardForm]},
	{
		InterpretationBox[RowBox[{"PARISession", "[", "\"Closed\"", "]"}], PARISession[_String]],
		InterpretationBox[RowBox[{"PARISession", "[", "\"Unavailable\"", "]"}], PARISession["unavailable"]]
	},
	SameTest -> MatchQ,
	TestID -> "a-session-shows-its-status"
]
