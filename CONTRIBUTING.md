# Contributing

Contributions are welcome.

Before changing the Core, explain which decision or failure mode the new rule improves. Generic advice and duplicated wording should not be added merely to make the file longer.

Requirements:
- preserve user/project instruction precedence;
- no hidden credential access;
- no remote shell installer;
- no claim of model switching unless it is verifiable;
- add/update tests for runtime logic changes;
- keep routing fail-open;
- do not advertise unmeasured savings.

Run on Windows PowerShell:

```powershell
.\PRECHECK.ps1
.\tests\Run-All.ps1
```
