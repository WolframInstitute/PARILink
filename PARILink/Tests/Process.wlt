(* Tests for the reading of responses in Kernel/Internal/Process.wl: a response is found after the output of GP, also
   when its marker arrives in two pieces. They need no GP. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`PARILink`"]

emptyPoll = WolframInstitute`PARILink`PackageScope`pariEmptyPoll;
receivedText = WolframInstitute`PARILink`PackageScope`pariReceivedText;
framedText = WolframInstitute`PARILink`PackageScope`pariFramedText;

marker = "PARILINK:0123456789abcdef0123456789abcdef:";
prefix = "\n" <> marker;

(* The state of a wait after the readings, a list of what GP wrote on its output each time. *)
readings[outputs : {___String}] := Fold[Function[{poll, newOutput}, framedText[receivedText[poll, newOutput, ""], newOutput, prefix]], emptyPoll[], outputs]

(* The parts of a state that say what was read. *)
readingSummary[poll_Association] := Lookup[poll, {"OutputLength", "PayloadText", "TrailingText"}]

VerificationTest[
	readingSummary @ readings[{"printed text" <> prefix <> "[\"ok\",[\"i\",\"5\"]]\n"}],
	{12, "[\"ok\",[\"i\",\"5\"]]", ""},
	TestID -> "response-after-printed-output"
]

VerificationTest[
	readingSummary @ readings[{"printed text\nPARILI", "NK:0123456789abcdef0123456789abcdef:[\"ok\",", "[\"i\",\"5\"]]\n"}],
	{12, "[\"ok\",[\"i\",\"5\"]]", ""},
	TestID -> "marker-split-between-readings"
]

VerificationTest[
	readingSummary @ readings[{"no response yet", "\nstill none"}],
	{None, None, None},
	TestID -> "output-without-a-marker-is-not-a-response"
]

VerificationTest[
	readingSummary @ readings[{prefix <> "[\"ok\",[\"u\"]]\nmore"}],
	{0, "[\"ok\",[\"u\"]]", "more"},
	TestID -> "text-after-the-response-is-kept-apart"
]

VerificationTest[
	Lookup[receivedText[receivedText[emptyPoll[], "ab", ""], "c", "error"], {"Output", "Error", "OutputSize", "ErrorSize"}],
	{{"ab", "c"}, {"error"}, 3, 5},
	TestID -> "readings-are-collected-with-their-sizes"
]
