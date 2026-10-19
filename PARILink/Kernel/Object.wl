(* Retained values are owned by one session, and are explicitly releasable. *)

PackageExported[PARIObject]
PackageScoped[pariCreateObject]
PackageScoped[pariObjectArgument]
PackageScoped[pariForgetObjects]

PARIObject::usage = "PARIObject[...] represents a value kept in PARI/GP. Normal[object] copies a supported value. DeleteObject[object] releases it."

$pariObjects = <||>

pariCreateObject[session_PARISession, id_Integer, type_String] := With[{key = CreateUUID[]},
	AssociateTo[$pariObjects, key -> <|"Session" -> session, "ID" -> id, "Type" -> type|>];
	PARIObject[key]
]

pariForgetObjects[session_PARISession] := (
	$pariObjects = Select[$pariObjects, #["Session"] =!= session &];
	Null
)

pariObjectData[PARIObject[key_String]] := pariEnclose @ With[{
	data = ConfirmBy[Lookup[$pariObjects, key, None], AssociationQ,
		pariFailure["PARIInvalidObject", "This PARI object has been released or its session has stopped."]]
}, {state = Confirm @ pariSessionData[data["Session"]]},
	If[state["Status"] === "Ready", data, pariFailure["PARIInvalidObject", "The object's PARI session is not ready."]]
]
pariObjectData[_] := pariFailure["PARIInvalidObject", "This PARI object is not valid."]

pariObjectArgument[session_, object_PARIObject] := pariEnclose @ With[{data = Confirm @ pariObjectData[object]},
	If[data["Session"] === session,
		"parilinkobjects[" <> IntegerString[data["ID"]] <> "]",
		pariFailure["PARIInvalidObject", "A PARI object can only be used in its own session."]
	]
]

pariObjectValue[object_PARIObject, mode_String] := pariEnclose @ With[{data = Confirm @ pariObjectData[object]},
	{code = Confirm @ pariObjectArgument[data["Session"], object]},
	pariOutput[pariRequest[data["Session"], code, mode, 30], "Discard"]
]

(object_PARIObject)["Properties"] := {"Type", "Session", "String", "Properties"}
(object_PARIObject)["String"] := pariObjectValue[object, "String"]
(object_PARIObject)[property : "Type" | "Session"] := pariEnclose @ With[{data = Confirm @ pariObjectData[object]}, data[property]]
(object_PARIObject)[property_String] := Missing["UnknownProperty", property]

PARIObject /: Normal[object_PARIObject] := pariObjectValue[object, "Copy"]

PARIObject /: DeleteObject[object : PARIObject[key_String]] := pariEnclose @ With[{data = Confirm @ pariObjectData[object]},
	{result = Confirm @ pariOutput[pariRequest[data["Session"],
		"parilinkrelease(" <> IntegerString[data["ID"]] <> ")", "Automatic", 30], "Discard"]},
	$pariObjects = KeyDrop[$pariObjects, key];
	Null
]

PARIObject /: MakeBoxes[object : PARIObject[key_String], form_] := With[{
	type = Lookup[Lookup[$pariObjects, key, <||>], "Type", "Unavailable"]
}, InterpretationBox[RowBox[{"PARIObject", "[", ToBoxes[type, form], "]"}], object]]
