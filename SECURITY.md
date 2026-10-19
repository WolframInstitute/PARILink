# Security policy

Report security issues through a private GitHub security advisory for this
repository. Do not open a public issue with vulnerability details.
Include:

- PARILink, Wolfram Language, PARI/GP, and operating-system versions
- a small example that reproduces the issue
- the expected and actual result

## Running GP code

GP runs with the permissions of the user running Wolfram Language.
`PARIEvaluate` executes GP source code. `PARICall` transfers arguments as data,
but the called GP function can still read files, write files, or start programs.
Use a trusted GP executable and run code you intend to execute.

Loading PARILink starts no process and installs nothing. Requests have a time
limit by default. A timeout, interruption, malformed response, or excessive
output stops the session and invalidates its retained objects. Returned values
are decoded as data rather than evaluated as Wolfram Language code.
