(* ::Package:: *)

PackageImport["PacletTools`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[CheckPaclet];

(* ::Section:: *)
(*Usage Messages*)

CheckPaclet::usage = "CheckPaclet[] checks the paclet metadata and the license files, lints the source and checks it against the coding guides, \
loads the paclet, and checks that every public symbol has a usage message and a reference page.";
$requiredFields::usage = "$requiredFields lists the fields that PacletInfo.wl must give, each a non-empty string.";
$versionPattern::usage = "$versionPattern is the pattern of a paclet version, MAJOR.MINOR.PATCH.";
$licenseFiles::usage = "$licenseFiles lists the license files of the repository that the paclet carries a copy of, under Resources.";
missingFieldQ::usage = "missingFieldQ[paclet, field] gives True when a field of the paclet is missing or empty.";
checkMetadata::usage = "checkMetadata[] checks PacletInfo.wl: that it validates, its required fields, its name and the form of its version. It \
gives the paclet object.";
sameContentQ::usage = "sameContentQ[first, second] gives True when both files exist and hold the same bytes.";
checkLicenseFiles::usage = "checkLicenseFiles[paclet] checks that the copies of the license files under the paclet's Resources are the files of \
the repository, and that the resource definition names the license of PacletInfo.wl.";
symbolName::usage = "symbolName[name] gives the last part of the full name of a symbol.";
usageQ::usage = "usageQ[name] gives True when the symbol with the full name has a usage message.";
checkSymbols::usage = "checkSymbols[paclet] checks that each public symbol of the loaded paclet has a usage message, and gives their full names.";
referencePages::usage = "referencePages[] lists the reference pages of the public symbols, the files of docs/en/Symbols.";
checkReferencePages::usage = "checkReferencePages[paclet, names] checks that the paclet has one Documentation extension, that the symbols with \
the full names and the reference pages are the same, and that each page is written from the Symbol template.";

(* ::Section:: *)
(*Function Definitions*)

$requiredFields = {"Name", "Version", "WolframVersion", "Description", "Creator", "License", "PublisherID", "PrimaryContext"};
$versionPattern = DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter..;
$licenseFiles = {"LICENSE", "COPYRIGHT"};

missingFieldQ[paclet_PacletObject, field_String] := !StringQ[paclet[field]] || StringTrim[paclet[field]] === ""

checkMetadata[] :=
	Module[{paclet, missingFields},
		paclet = quietCheck[PacletObject[File[$PacletDirectory]]];
		RequireOrLog[paclet, PacletObjectQ, "Cannot read PacletInfo.wl"];
		RequireOrLog[PacletValidate[$PacletDirectory], TrueQ, "PacletValidate failed"];
		missingFields = Select[$requiredFields, missingFieldQ[paclet, #] &];
		RequireOrLog[missingFields, # === {} &, "Missing metadata: ", missingFields];
		RequireOrLog[paclet["Name"], # === $PacletName &, "Unexpected paclet name"];
		RequireOrLog[paclet["Version"], StringMatchQ[#, $versionPattern] &, "Version must use MAJOR.MINOR.PATCH"];
		paclet
	]

sameContentQ[first_String, second_String] := AllTrue[{first, second}, FileExistsQ] && FileHash[first, "SHA256"] === FileHash[second, "SHA256"]

checkLicenseFiles[paclet_PacletObject] :=
	Module[{changedCopies, definition},
		changedCopies = Select[$licenseFiles, !sameContentQ[FileNameJoin[{$RepositoryRoot, #}], FileNameJoin[{$PacletDirectory, "Resources", #}]] &];
		RequireOrLog[changedCopies, # === {} &, "PARILink/Resources does not hold a copy of ", changedCopies];
		definition = Import[FileNameJoin[{$RepositoryRoot, "docs", "ResourceDefinition.md"}], "Text"];
		RequireOrLog[definition, StringContainsQ[#, "License: " <> paclet["License"] <> "\n"] &, "docs/ResourceDefinition.md names a different license"]
	]

symbolName[name_String] := Last @ StringSplit[name, "`"]

usageQ[name_String] := StringQ[Quiet[ToExpression[name <> "::usage"], All]]

(* Names gives short names for a context on $ContextPath, so each name is rebuilt from its last part. *)
checkSymbols[paclet_PacletObject] :=
	Module[{context, publicSymbols, missingUsage},
		context = paclet["PrimaryContext"];
		publicSymbols = Map[context <> symbolName[#] &, Names[context <> "*"]];
		RequireOrLog[publicSymbols, # =!= {} &, "The paclet has no public symbol"];
		missingUsage = Select[publicSymbols, !usageQ[#] &];
		RequireOrLog[missingUsage, # === {} &, "Missing usage messages: ", missingUsage];
		publicSymbols
	]

referencePages[] := FileNames["*.md", FileNameJoin[{$DocumentationDirectory, "Symbols"}]]

(* A symbol without a page is an export that was not meant, or a page that is still to write. *)
checkReferencePages[paclet_PacletObject, names : {___String}] :=
	Module[{pages, invalidPages},
		RequireOrLog[PacletExtensions[paclet, "Documentation"], Length[#] === 1 &, "PacletInfo.wl must have one Documentation extension"];
		pages = referencePages[];
		RequireOrLog[
			Sort[FileBaseName /@ pages],
			# === Sort[symbolName /@ names] &,
			"The public symbols and the reference pages under docs/en/Symbols differ: ", Sort[symbolName /@ names]
		];
		invalidPages = Select[pages, !StringContainsQ[ReadString[#], "Template: Symbol"] &];
		RequireOrLog[invalidPages, # === {} &, "Invalid reference pages: ", invalidPages]
	]

CheckPaclet[] :=
	Module[{paclet, publicSymbols},
		checkLicenseFiles[checkMetadata[]];
		LintFiles[styleFiles[]];
		requireNoErrors[];
		paclet = LoadPaclet[];
		publicSymbols = checkSymbols[paclet];
		checkReferencePages[paclet, publicSymbols];
		LogInfo["OK: ", paclet["Name"], " ", paclet["Version"]]
	]
CheckPaclet[___] := invalidArgumentsFailure[CheckPaclet]
