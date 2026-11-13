(* Tests for Kernel/Object.wl that need no GP: objects that are not known, objects of a session that is closed, and
   property requests of another form. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`PARILink`"]

createObject = WolframInstitute`PARILink`PackageScope`pariCreateObject;
forgetObjects = WolframInstitute`PARILink`PackageScope`pariForgetObjects;

(* A session of this kernel that is closed, as DeleteObject leaves it. Its state names no process. The state is
   added to the record of sessions itself, not to a copy. *)
closedSession[] :=
	Module[{sessionID},
		sessionID = CreateUUID[];
		AssociateTo[WolframInstitute`PARILink`PackageScope`$pariSessions, sessionID -> <|"Executable" -> "/test/gp", "Version" -> "2.19.0", "Status" -> "Closed"|>];
		PARISession[sessionID]
	]

VerificationTest[
	Normal[PARIObject["unavailable"]],
	Failure["PARIInvalidObject", <|"MessageTemplate" -> "This PARI object has been released or its session has stopped."|>],
	TestID -> "unknown-object"
]

VerificationTest[
	Module[{object},
		object = PARIObject["unavailable"];
		{object["Properties"], First[object["Type"]], First[object["String"]], object["Other"]}
	],
	{{"Type", "Session", "String", "Properties"}, "PARIInvalidObject", "PARIInvalidObject", Missing["UnknownProperty", "Other"]},
	TestID -> "properties-of-an-unknown-object"
]

(* An object whose form is not that of an object gives a Failure, also when it is deleted. *)
VerificationTest[
	{DeleteObject[PARIObject[1]], Normal[PARIObject[]]},
	{
		Failure["PARIInvalidObject", <|"MessageTemplate" -> "This PARI object is not valid."|>],
		Failure["PARIInvalidObject", <|"MessageTemplate" -> "This PARI object is not valid."|>]
	},
	TestID -> "an-object-of-another-form-gives-a-failure"
]

VerificationTest[
	Module[{session, object, beforeForgetting},
		session = closedSession[];
		object = createObject[session, 3, "t_POL"];
		beforeForgetting = {object["Type"], ToBoxes[object, StandardForm]};
		forgetObjects[session];
		Join[beforeForgetting, {object["Type"]}]
	],
	{
		Failure["PARIInvalidObject", <|"MessageTemplate" -> "The object's PARI session is not ready."|>],
		InterpretationBox[RowBox[{"PARIObject", "[", "\"t_POL\"", "]"}], PARIObject[_String]],
		Failure["PARIInvalidObject", <|"MessageTemplate" -> "This PARI object has been released or its session has stopped."|>]
	},
	SameTest -> MatchQ,
	TestID -> "objects-of-a-closed-session"
]

(* A property request that is not one name matches no form. *)
VerificationTest[
	{First[PARIObject["unavailable"][1]], First[PARIObject["unavailable"]["Type", "String"]]},
	{"InvalidArguments", "InvalidArguments"},
	{PARIObject::args, PARIObject::args},
	TestID -> "reject-property-requests-of-another-form"
]
