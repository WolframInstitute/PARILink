Needs["WolframInstitute`PARILink`"];

session = StartPARISession[];

VerificationTest[
	Module[{factors = PARICall[session, "factor", 360, "ReturnType" -> "Object"]}, WithCleanup[
		PARICall[session, "factorback", factors], DeleteObject[factors]
	]], 360, TestID -> "reuse-factorization-as-a-gp-matrix"
]

VerificationTest[
	Module[{field = PARICall[session, "ffgen", 8]}, WithCleanup[
		{field["Type"], PARICall[session, "fforder", field]}, DeleteObject[field]
	]], {"t_FFELT", 7}, TestID -> "finite-field-element-through-structured-calls"
]

VerificationTest[
	Module[{series = PARIEvaluate[session, "exp(x+O(x^6))"]}, WithCleanup[
		PARICall[session, "polcoef", series, 5], DeleteObject[series]
	]], 1/120, TestID -> "power-series-coefficient-through-structured-call"
]

VerificationTest[
	Module[{number = PARIEvaluate[session, "5+O(5^8)"]}, WithCleanup[
		{number["Type"], PARICall[session, "valuation", number, 5]}, DeleteObject[number]
	]], {"t_PADIC", 1}, TestID -> "padic-value-through-structured-call"
]

VerificationTest[
	Module[{number = PARIEvaluate[session, "Mod(8,11)^2"]}, WithCleanup[
		PARICall[session, "lift", number], DeleteObject[number]
	]], 9, TestID -> "modular-value-through-structured-call"
]

VerificationTest[
	Module[{polynomial, field, element},
		polynomial = PARIEvaluate[session, "x^2-2"];
		field = PARICall[session, "nfinit", polynomial, "ReturnType" -> "Object"];
		element = PARIEvaluate[session, "x"];
		WithCleanup[
			PARICall[session, "nfeltnorm", field, element],
			Scan[DeleteObject, {element, field, polynomial}]
		]
	], -2, TestID -> "number-field-structure-through-structured-calls"
]

VerificationTest[
	Module[{forms = PARICall[session, "mfinit", {11, 2}, 0, "ReturnType" -> "Object"]}, WithCleanup[
		PARICall[session, "mfdim", forms], DeleteObject[forms]
	]], 1, TestID -> "modular-form-space-through-structured-calls"
]

VerificationTest[
	Module[{function, value},
		function = PARICall[session, "lfuncreate", 1, "ReturnType" -> "Object"];
		value = PARICall[session, "lfun", function, 2];
		WithCleanup[
			PARICall[session, "floor", value], Scan[DeleteObject, {value, function}]
		]
	], 1, TestID -> "l-function-through-structured-calls"
]

VerificationTest[
	Module[{error = PARIEvaluate[session, "iferr(1/0,e,e)"]}, WithCleanup[
		{error["Type"], PARICall[session, "errname", error]}, DeleteObject[error]
	]], {"t_ERROR", "e_INV"}, TestID -> "retained-gp-error-object"
]

VerificationTest[
	PARICall[session, "default", "nbthreads", 2];
	PARIEvaluate[session, "parvector(2,i,vecsum(vector(10^6,j,j)))", "Output" -> "Discard"],
	{500000500000, 500000500000}, TestID -> "parallel-workers-can-grow-their-stacks"
]

DeleteObject[session];

VerificationTest[
	Module[{large = StartPARISession["StackLimit" -> 1024^3]}, WithCleanup[
		{PARICall[large, "default", "parisizemax"], PARICall[large, "default", "threadsizemax"],
			PARIEvaluate[large, "if(factorback(factormodcyclo(15015,2^64+375361))!=polcyclo(15015),error())",
				TimeConstraint -> 120, "Output" -> "Discard"], large["Status"]},
		DeleteObject[large]
	]], {1024^3, 1024^3, 0, "Ready"}, TestID -> "large-cyclotomic-factorization-with-configured-stack-limit"
]
