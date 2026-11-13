(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[PARIObject];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{pariCreateObject, pariObjectArgument, pariForgetObjects}];

(* ::Section:: *)
(*Usage Messages*)

PARIObject::usage = "PARIObject[...] represents a value kept in a PARI/GP session. PARIEvaluate and PARICall create it, and it stays as it is: it \
is the handle of the value.\n\
object[\"property\"] gives a property of the value. object[\"Properties\"] lists the properties.\n\
Normal[object] copies a value that has an exact Wolfram Language form, and DeleteObject[object] releases the value.";
pariCreateObject::usage = "pariCreateObject[session, objectID, type] records the value that the GP of the session keeps under the number \
objectID, with its GP type, and gives its PARIObject.";
pariObjectArgument::usage = "pariObjectArgument[session, object] gives GP source that names the value of the PARIObject to the GP of the session, \
or a Failure with the tag \"PARIInvalidObject\" when the object is not a live object of that session.";
pariForgetObjects::usage = "pariForgetObjects[session] drops the record of every object of the session and gives Null.";
$pariObjects::usage = "$pariObjects holds, for the key of every PARIObject of this kernel, its \"Session\", its number \"ID\" in GP and its GP \
\"Type\".";
$pariObjectProperties::usage = "$pariObjectProperties lists the names of the properties of an object.";
$pariObjectTimeConstraint::usage = "$pariObjectTimeConstraint is the number of seconds that a request about an object may take.";
pariInvalidObject::usage = "pariInvalidObject[] gives the Failure for a PARIObject whose form is not that of an object.";
pariObjectData::usage = "pariObjectData[object] gives the record of a PARIObject, an association, or a Failure when the object was released, its \
session is not ready or its form is not that of an object.";
pariObjectValue::usage = "pariObjectValue[object, mode] asks GP for the value of a PARIObject. The mode \"Copy\" gives the value itself and the \
mode \"String\" its text in GP. It gives a Failure when the object is not live or the value cannot be copied.";
pariObjectProperty::usage = "pariObjectProperty[object, property] gives the value of a property of an object, a Failure for an object that is not \
live, or Missing[\"UnknownProperty\", property] for a name that is not a property.";
pariDeleteObject::usage = "pariDeleteObject[object] has GP release the value of a PARIObject, drops its record and gives Null. An object that is \
not live gives a Failure.";
pariObjectTypeBox::usage = "pariObjectTypeBox[key, form] gives the boxes of the GP type of the object with the given key, or of \"Unavailable\", \
in the given form.";

(* ::Section:: *)
(*Function Definitions*)

(* A value that GP keeps belongs to one session. Closing or losing the session drops the record of its objects. *)

$pariObjects = <||>;
$pariObjectProperties = {"Type", "Session", "String", "Properties"};
$pariObjectTimeConstraint = 30;

pariCreateObject[session_PARISession, objectID_Integer, type_String] :=
	Module[{key},
		key = CreateUUID[];
		AssociateTo[$pariObjects, key -> <|"Session" -> session, "ID" -> objectID, "Type" -> type|>];
		PARIObject[key]
	]

pariForgetObjects[session_PARISession] := (
	$pariObjects = Select[$pariObjects, #Session =!= session &];
	Null
)

pariInvalidObject[] := pariFailure["PARIInvalidObject", "This PARI object is not valid."]

pariObjectData[PARIObject[key_String]] :=
	Enclose[
		Module[{objectData, state},
			objectData = ConfirmBy[
				Lookup[$pariObjects, key, None],
				AssociationQ,
				pariFailure["PARIInvalidObject", "This PARI object has been released or its session has stopped."]
			];
			state = Confirm[pariSessionData[objectData["Session"]]];
			If[state["Status"] === "Ready", objectData, pariFailure["PARIInvalidObject", "The object's PARI session is not ready."]]
		],
		innerFailure
	]
pariObjectData[_PARIObject] := pariInvalidObject[]

pariObjectArgument[session_PARISession, object_PARIObject] :=
	Replace[
		pariObjectData[object],
		objectData_Association :> If[objectData["Session"] === session,
			"parilinkobjects[" <> IntegerString[objectData["ID"]] <> "]",
			pariFailure["PARIInvalidObject", "A PARI object can only be used in its own session."]
		]
	]

pariObjectValue[object_PARIObject, mode : ("Copy" | "String")] :=
	Enclose[
		Module[{objectData, session, code},
			objectData = Confirm[pariObjectData[object]];
			session = objectData["Session"];
			code = Confirm[pariObjectArgument[session, object]];
			pariOutput[pariRequest[session, code, mode, $pariObjectTimeConstraint], "Discard"]
		],
		innerFailure
	]

pariObjectProperty[_PARIObject, "Properties"] := $pariObjectProperties
pariObjectProperty[object_PARIObject, "String"] := pariObjectValue[object, "String"]
pariObjectProperty[object_PARIObject, property : ("Type" | "Session")] :=
	Replace[pariObjectData[object], objectData_Association :> objectData[property]]
pariObjectProperty[_PARIObject, property_String] := Missing["UnknownProperty", property]

(* PARIObject[...] itself has no definition, because it is the handle of a value. Only a property request evaluates. *)
PARIObject[objectData___][property_String] := pariObjectProperty[PARIObject[objectData], property]
PARIObject[___][___] := invalidArgumentsFailure[PARIObject]

PARIObject /: Normal[object_PARIObject] := pariObjectValue[object, "Copy"]

pariDeleteObject[object : PARIObject[key_String]] :=
	Enclose[
		Module[{objectData, releaseCode},
			objectData = Confirm[pariObjectData[object]];
			releaseCode = "parilinkrelease(" <> IntegerString[objectData["ID"]] <> ")";
			Confirm[pariOutput[pariRequest[objectData["Session"], releaseCode, "Automatic", $pariObjectTimeConstraint], "Discard"]];
			$pariObjects = KeyDrop[$pariObjects, key];
			Null
		],
		innerFailure
	]
pariDeleteObject[_PARIObject] := pariInvalidObject[]

PARIObject /: DeleteObject[object_PARIObject] := pariDeleteObject[object]

pariObjectTypeBox[key_String, form : (StandardForm | TraditionalForm)] :=
	ToBoxes[Lookup[Lookup[$pariObjects, key, <||>], "Type", "Unavailable"], form]

(* With puts the computed box into InterpretationBox, which holds its arguments. *)
PARIObject /: MakeBoxes[object : PARIObject[key_String], form : (StandardForm | TraditionalForm)] :=
	With[{typeBox = pariObjectTypeBox[key, form]},
		InterpretationBox[RowBox[{"PARIObject", "[", typeBox, "]"}], object]
	]
