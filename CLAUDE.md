# Version
2

# Coding Rules (Pointer)

This project's rules live in two files in the project root:

- `CODING_RULES.md` — code quality and conventions. BINDING for all code work in
  this repository, always.
- `IMPLEMENTATION_FLOW.md` — the end-to-end flow to follow when planning and
  implementing a change (checks, gates, Definition of Done).

MANDATORY: Before writing or editing ANY code, you MUST Read BOTH files in full
**in the current session**. Do not rely on memory of a previous session, a
summary, or partial reads.

If you are about to make a code change and have not read both files in this
session: STOP, read them, then continue.

An external tool may orchestrate the implementation itself. When a skill or run
states that the implementation is orchestrated, ignore `IMPLEMENTATION_FLOW.md`
entirely — the orchestrator runs those steps as its own phases. `CODING_RULES.md`
stays binding either way.

Do not inline rules back into this file and do not use `@import` for either file —
they are intentionally referenced, not imported.


# graphify
This project's code directory is `lib/`.

## Code Analysis

Two analysis modes — pick by situation:

**Changed-files run (default after implementing a feature, finishing a plan, or fixing a bug):**

```bash
powershell -Command "cd 'D:\GIT\BenjaminKobjolke\automated-application-screenshots-flutter-connector'; cmd /c '.\tools\analyze_changed_and_new_files.bat'"
```

Uses `--only-changed`: the report is filtered to files new or modified vs git `HEAD` (includes
untracked). Project-wide analyzers still run; only the report is filtered. This avoids findings
from unrelated pre-existing violations.

**Full run (whole-project audits):**

```bash
powershell -Command "cd 'D:\GIT\BenjaminKobjolke\automated-application-screenshots-flutter-connector'; cmd /c '.\tools\analyze_code.bat'"
```

Use the full run for an explicit audit request, exception maintenance, before a release or merge,
after refactors that touch shared code, or when the working tree is clean vs `HEAD`.

Results are written to `code_analysis_results/` as per-rule CSV files (for example,
`dart_analyze.csv`, `dart_code_linter.csv`, and `line_count_report.csv`). There is no Markdown
report; a missing CSV means that rule found nothing. Fix reported issues before committing.
