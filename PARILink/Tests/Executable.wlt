Needs["WolframInstitute`PARILink`"];

findGP = WolframInstitute`PARILink`PackageScope`pariFindExecutable;
bundledGP = WolframInstitute`PARILink`PackageScope`pariBundledExecutable;

VerificationTest[
	Table[FileNameTake[bundledGP["/runtime", system]], {system,
		{"MacOSX-ARM64", "MacOSX-x86-64", "Linux-ARM64", "Linux-x86-64", "Windows-x86-64"}}],
	{"gp", "gp", "gp", "gp", "gp.exe"},
	TestID -> "bundle-executable-for-each-platform"
]

VerificationTest[
	Module[{directory = CreateDirectory[], bundled, override, path, common, missing, result},
		WithCleanup[
			{bundled, override, common, missing} = FileNameJoin[{directory, #}] & /@ {"bundled", "override", "common", "missing"};
			path = FileNameJoin[{directory, "gp"}];
			Scan[Export[#, "test", "Text"] &, {bundled, override, path, common}],
			result = {
				findGP[override],
				findGP[Automatic, override, bundled, directory, {common}, "Unix"],
				findGP[Automatic, "", bundled, directory, {common}, "Unix"],
				findGP[Automatic, "", missing, directory, {common}, "Unix"],
				findGP[Automatic, "", missing, "", {common}, "Unix"],
				MatchQ[findGP[Automatic, missing, bundled, directory, {common}, "Unix"], Failure["PARIExecutableNotFound", _]],
				MatchQ[findGP[Automatic, "", missing, $Failed, {}, "Unix"], Failure["PARIExecutableNotFound", _]]
			};
			result === {override, override, bundled, path, common, True, True},
			DeleteDirectory[directory, DeleteContents -> True]
		]
	], True,
	TestID -> "explicit-and-environment-overrides-then-bundle-then-path-with-no-silent-override-fallback"
]

VerificationTest[
	Module[{directory = CreateDirectory[], program},
		program = FileNameJoin[{directory, "gp.exe"}];
		WithCleanup[Export[program, "test", "Text"],
			findGP[Automatic, "", None, "\"" <> directory <> "\";", {}, "Windows"] === program,
			DeleteDirectory[directory, DeleteContents -> True]
		]
	], True,
	TestID -> "windows-path-with-quotes-and-empty-entries"
]
