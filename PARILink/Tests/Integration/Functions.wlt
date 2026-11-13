(* Integration tests of calls on values of many GP types: factorizations, finite fields, power series, p-adic and
   modular numbers, number fields, modular forms, L-functions, error objects and parallel workers. They need GP;
   set PARILINK_GP to choose one. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]
Needs["WolframInstitute`PARILink`"]

(* Gives body applied to the objects and releases them afterwards, in the order given. *)
withObjects[objects_List, body_Function] := WithCleanup[body @@ objects, Scan[DeleteObject, objects]]
withObject[object_, body_Function] := withObjects[{object}, body]

session = StartPARISession[];

VerificationTest[
	withObject[
		PARICall[session, "factor", 360, "ReturnType" -> "Object"],
		Function[factors, PARICall[session, "factorback", factors]]
	],
	360,
	TestID -> "reuse-factorization-as-a-gp-matrix"
]

VerificationTest[
	withObject[
		PARICall[session, "ffgen", 8],
		Function[field, {field["Type"], PARICall[session, "fforder", field]}]
	],
	{"t_FFELT", 7},
	TestID -> "finite-field-element-through-structured-calls"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "exp(x+O(x^6))"],
		Function[series, PARICall[session, "polcoef", series, 5]]
	],
	1 / 120,
	TestID -> "power-series-coefficient-through-structured-call"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "5+O(5^8)"],
		Function[number, {number["Type"], PARICall[session, "valuation", number, 5]}]
	],
	{"t_PADIC", 1},
	TestID -> "padic-value-through-structured-call"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "Mod(8,11)^2"],
		Function[number, PARICall[session, "lift", number]]
	],
	9,
	TestID -> "modular-value-through-structured-call"
]

VerificationTest[
	Module[{polynomial, field, element},
		polynomial = PARIEvaluate[session, "x^2-2"];
		field = PARICall[session, "nfinit", polynomial, "ReturnType" -> "Object"];
		element = PARIEvaluate[session, "x"];
		withObjects[
			{element, field, polynomial},
			Function[Null, PARICall[session, "nfeltnorm", field, element]]
		]
	],
	-2,
	TestID -> "number-field-structure-through-structured-calls"
]

VerificationTest[
	withObject[
		PARICall[session, "mfinit", {11, 2}, 0, "ReturnType" -> "Object"],
		Function[forms, PARICall[session, "mfdim", forms]]
	],
	1,
	TestID -> "modular-form-space-through-structured-calls"
]

VerificationTest[
	Module[{function, value},
		function = PARICall[session, "lfuncreate", 1, "ReturnType" -> "Object"];
		value = PARICall[session, "lfun", function, 2];
		withObjects[
			{value, function},
			Function[Null, PARICall[session, "floor", value]]
		]
	],
	1,
	TestID -> "l-function-through-structured-calls"
]

VerificationTest[
	withObject[
		PARIEvaluate[session, "iferr(1/0,e,e)"],
		Function[error, {error["Type"], PARICall[session, "errname", error]}]
	],
	{"t_ERROR", "e_INV"},
	TestID -> "retained-gp-error-object"
]

VerificationTest[
	PARICall[session, "default", "nbthreads", 2];
	PARIEvaluate[session, "parvector(2,i,vecsum(vector(10^6,j,j)))", "Output" -> "Discard"],
	{500000500000, 500000500000},
	TestID -> "parallel-workers-can-grow-their-stacks"
]

DeleteObject[session];

VerificationTest[
	withObject[
		StartPARISession["StackLimit" -> 1024 ^ 3],
		Function[large,
			{
				PARICall[large, "default", "parisizemax"],
				PARICall[large, "default", "threadsizemax"],
				PARIEvaluate[
					large, "if(factorback(factormodcyclo(15015,2^64+375361))!=polcyclo(15015),error())",
					TimeConstraint -> 120,
					"Output" -> "Discard"
				],
				large["Status"]
			}
		]
	],
	{1024 ^ 3, 1024 ^ 3, 0, "Ready"},
	TestID -> "large-cyclotomic-factorization-with-configured-stack-limit"
]
