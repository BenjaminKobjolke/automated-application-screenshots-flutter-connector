<!-- Managed by /coding-rules:apply — do not edit rule blocks by hand -->
<!-- codex: enabled -->
<!-- deepseek: disabled -->

# Version
3

Increase this version number whenever this rule file changes.

# Common Rules (All Languages)

These rules apply to all projects, regardless of language. Language-specific rules live in the
corresponding `*_RULES.md` files.

---

## Keep CODING_RULES.md in Sync

When working on a project, copy all relevant rules into the project's `CODING_RULES.md` file
(project root). The project's `CLAUDE.md` carries only a small versioned pointer block that
mandates reading `CODING_RULES.md` before code work — never the full rules, and never an
`@import` of `CODING_RULES.md` (imports auto-expand into context every turn).

- Always include all rules from `COMMON_RULES.md` and `AI_RULES.md`
- Also include applicable language-specific, project-type, and supplemental rule files
  (see `PROJECT_TYPES.md` for the project-type overview)
- Include optional addon rule files only when the user has opted in to that addon
- If applicability is unclear, ask the user which rules to include
- Include each source file's `# Version` block with its copied rules
- If `CODING_RULES.md` already exists, compare each source file's version with the corresponding
  copied rule block and update only stale or unversioned blocks, keeping the result deduplicated
- If `CLAUDE.md` contains inlined rule blocks or coding-rule `@import` lines from an earlier run,
  migrate that content into `CODING_RULES.md` and leave only the pointer block in `CLAUDE.md`

---

## Use Objects for Related Values

When multiple related values must be passed between classes or methods, bundle them into a
dedicated object (e.g., DTO/Settings/Config) instead of passing many parameters. This improves
readability, reduces call-site churn, and makes changes safer.

---

## No Bag-of-Keys Returns at Module Boundaries

When a public method on a manager/repository/service returns data that crosses a module
boundary, the return type must be a typed object (DTO, value object, or domain model) — never
a raw associative array indexed by string keys. Plain `array` returns silently swallow shape
bugs: a missing key reads as `null`, a list-vs-single mix-up reads as "no data", and renames
go undetected by static analysis.

- **Anti-pattern.** `getSettingsValue(...)` returns `array|null`; callers do `$result['value']`,
  `$result['type']`. A consumer mis-indexes `$result[0]['value']` after a refactor; nothing
  flags the change. The function silently returns `null` and downstream defaults take over.
- **Correct pattern.** Return a class — `getSettingsElement(...): ?SettingsElement`. The class
  exposes `getValue()`, `getType()`, `exists()`. Typed, autocompleted, statically checked;
  renames propagate via the IDE.
- **Lists vs single must be obvious from the type and the name.** `getThing(): ?Thing`
  (zero or one) vs `getThings(): ThingList` or `iterable<Thing>`. Never overload the same
  return type to mean both.
- **Distinguish absent from empty.** `null` from a lookup means "not found"; an empty
  collection means "found, but had nothing". A typed return makes this contract explicit;
  a bag-of-keys array hides it.
- **JSON-decoded blobs are arrays too.** The rule applies equally to `json_decode($column, true)`
  results that cross a module boundary — wrap them in a value object before they leave the
  layer that owns the schema.
- **Internal helpers may stay arrays.** This rule targets *public* API on managers and the
  boundary where a domain abstraction starts. Pure-private array juggling inside a single
  method is fine.

---

## Reuse Existing Models Before Inventing Array Shapes

Before designing a new return type or DTO, search the codebase for an existing domain class
that already owns the same data. Most "should this be a DTO?" decisions are actually
"is there already a `Contest` / `User` / `Order` class that should absorb this method?"

- Grep for the table name, the primary key, and the most distinctive column.
- If a model already exists with a constructor that accepts the row shape, use it — don't
  invent a parallel array shape that mirrors the same columns.
- Adding a `getXxxObject()` alongside a legacy `getXxxData()` is acceptable as a migration
  step; keep both only until consumers are migrated, then delete the array-returning version.

---

## Tests Pin the Shape Before the Refactor

When converting a bag-of-keys return to a typed object, write a **characterization test
first** that locks the current behavior using the existing API, run it green against the
unrefactored code, and then refactor. The same test (or a renamed-but-equivalent one) must
remain green afterward.

This converts "I think the new object preserves behavior" into "the test proves it." Pair
with the "Test-Driven Development" rule below — characterization tests are TDD applied to
refactors instead of new features.

---

## Test-Driven Development for Features and Bug Fixes

Follow TDD when implementing features or fixing bugs:

1. Write tests first
2. Run the tests and confirm they fail
3. Implement the change or fix
4. Run the tests again and confirm they pass

---

## Integration Tests

Every project must include integration tests in addition to unit tests. Integration tests verify that
components work correctly together and catch issues that unit tests alone cannot detect.

---

## Test Runner Scripts

Every project must provide the following batch files in the `tools/` directory:

- `tools/run_tests.bat` — runs unit tests
- `tools/run_integration_tests.bat` — runs integration tests

These scripts ensure a consistent way to execute tests across environments.

---

## Prefer Type-Safe Values

Use strong, explicit types instead of loosely typed or stringly typed values (e.g., typed DTOs,
enums, generics, typed settings). This ensures mistakes are caught at compile time or by tests
early in development.

---

## String Constants

Centralize string constants in a dedicated module/class. Do not scatter raw strings across
the codebase. Use language-appropriate patterns for constants and reuse them consistently.

---

## Reusable Tooling

Before building project-specific infrastructure scripts (audits, codemods,
build helpers, lint checks, etc.) for a project, check the matching
language's `*_setup_files/` folder under this `coding-rules` repo for an
existing equivalent. If found, copy or reference it. If not:

1. Build the script in the project and prove it on real data.
2. Copy the script into the right `*_setup_files/tools/` folder.
3. Document it in that language's `*_RULES.md` so the next project picks
   it up automatically.

This keeps cross-project tooling consistent and prevents the same script
from being re-invented in every new project.

---

## README.md is Mandatory

Every project must have a `README.md` file in the root directory. It should include:

- Project name and description
- Installation/setup instructions
- Usage examples
- Dependencies and requirements

---

## Don't Repeat Yourself (DRY)

Avoid code duplication. If the same logic appears in multiple places, extract it into a
reusable function, class, module, or utility.

- Duplicate code is harder to maintain and leads to bugs
- Extract shared logic into helpers or base abstractions
- Use constants for repeated values

---

## Derive, Don't Duplicate — One Value Owns the Derivation

When one value strictly determines another, pass only the determinant and derive the rest —
never thread both side-by-side through call sites, constructors, and events. Two co-varying
parameters are a functional dependency in disguise; passing both lets them drift into illegal
combinations.

- **Anti-pattern.** `createLog(ActionCategory $cat, ActionType $type)` threaded through ~10
  sites. Nothing stops a caller passing `category: email, type: lead.created`.
- **Correct pattern.** The richer type owns the relationship: `ActionType::category()` returns
  its `ActionCategory` via a single exhaustive `match`. Call sites pass only `ActionType`;
  category is always derived, so a mismatch is unconstructable.
- **Apply when** one value *determines* the other (a true functional dependency).
- **Don't apply when** the relationship is many-to-many or genuinely independent — forcing a
  derivation that doesn't exist couples things that should stay separate.
- **Keep derivation cheap and pure** — a getter/match, no DB or IO behind a call that looks free.
- **Keep the mapping exhaustive** (enum + exhaustive match) so a new case cannot silently skip
  its derived value.

This is Single Source of Truth applied to parameters, and a form of "make illegal states
unrepresentable." Pairs with "Prefer Type-Safe Values" and "Self-Describing Classes".

---

## Keep It Simple (KISS)

Prefer the simplest solution that actually works. Complicated logic for a simple result must be
kept to a minimum — a future maintainer (or you, at 3am) has to understand it.

- **YAGNI.** Don't build for a need that isn't here yet: no interface with a single
  implementation, no factory for one product, no config for a value that never changes.
- **Boring over clever.** Clever is what someone decodes later. The obvious solution wins.
- **Deletion over addition.** The shortest working change is usually the right one.
- Pairs with "Don't Repeat Yourself" and "No God Classes" — simplicity is what those rules
  are protecting.

---

## Confirm Dependency Versions

Before adding any new package or library, confirm the version with the user to ensure we use
up-to-date dependencies.

- Do not assume which version to use
- Ask the user to verify the latest stable version
- Avoid outdated packages that may have security vulnerabilities or missing features

---

## Error Handling & Logging Strategy

Every project must have a centralized error handler rather than ad-hoc try/catch blocks scattered
throughout the codebase.

- Use structured logging (not `print`/`console.log`/`echo`)
- Log at appropriate levels: debug, info, warning, error
- Include context in log messages (module name, operation, relevant IDs)

---

## Centralized Logger — Single Off Switch

Route all logging through one dedicated logger class/module. Never call the language's
built-in output directly for logging (`print`, `console.log`, `echo`, `Debug.Log`,
`System.out`). Code calls the project logger; the project logger wraps the underlying sink.

- **One toggle.** Because every log goes through one place, logging can be turned off,
  level-filtered, or redirected (file, console, remote) from a single config flag — without
  touching call sites. Example: a `logEnabled` / `logLevel` setting the logger checks once.
- **Levels live in the logger.** Callers pass a level (debug/info/warning/error); the logger
  decides what is emitted based on central config. Callers never branch on "should I log?".
- **Wrap, don't scatter.** Built-in calls (`print`, framework loggers, `Debug.Log`) appear
  in exactly one file — the logger implementation. Everywhere else imports the logger.
- **Language specifics** still apply (e.g. Unity `[Conditional]` stripping, Flutter `logger`
  package, Python `logging`) — but they are configured inside the central logger, not at
  call sites.

The logger's name is fixed per language so it is the same known type in every project (see each
`*_RULES.md` for details):

| Language      | Class / export     | File                |
|---------------|--------------------|---------------------|
| Python        | `AppLogger`        | `app_logger.py`     |
| PHP           | `Logger`           | `Logger.php`        |
| Dart/Flutter  | `AppLogger`        | `app_logger.dart`   |
| Kotlin        | `AppLogger`        | `AppLogger.kt`      |
| C# (plain)    | `AppLogger`        | `AppLogger.cs`      |
| Unity C#      | `GameLog` (static) | `GameLog.cs`        |
| Svelte/JS/TS  | `logger` (export)  | `logger.ts`         |
| Arduino       | `Log`              | `Log.h` / `Log.cpp` |

---

## Input Validation at Boundaries

Always validate data at system boundaries — API inputs, user input, file uploads, external service
responses.

- Never trust external data; validate before processing
- Use language-appropriate validation libraries (e.g., Pydantic, Zod, FluentValidation)
- Fail fast with clear error messages when validation fails

---

## Maximum File Length — 300 Lines

Split files when they exceed 300 lines to keep code navigable during fast iteration.

- Extract classes, functions, or components into separate modules
- Group related extractions logically (by domain, not by type)
- Exceptions: generated files, configuration files, test files with many similar cases

---

## Naming Conventions

Be consistent within a project. Follow these defaults unless the language or framework dictates
otherwise:

- Files: `snake_case` (or language convention, e.g., `PascalCase` for C# classes)
- Classes: `PascalCase`
- Functions/methods: language convention (`snake_case` for Python/PHP, `camelCase` for Dart/JS/C#)
- Constants: `UPPER_SNAKE_CASE`
- Variables: language convention (`snake_case` for Python/PHP, `camelCase` for Dart/JS/C#)

---

## Comments Explain Why, Not What

Comment intent and non-obvious reasoning — not a restatement of the code. Good names carry the
*what*; comments carry the *why*.

- **Anti-pattern.** `i++ // increment i`. Redundant comments add noise and rot the moment the
  code changes.
- **Correct pattern.** Document *why* a workaround exists, why a non-obvious algorithm was
  chosen, or a constraint that isn't visible locally (`// API rejects batches > 500`).
- Prefer self-documenting code (clear names, small functions) over a comment that compensates
  for unclear code — see "Naming Conventions" and "Keep It Simple".
- Document the purpose of each module/class at its top.
- Keep comments in sync with the code; delete stale ones rather than letting them mislead.

---

## Security Baseline

Every project must follow these minimum security practices:

- Never commit secrets (`.env`, API keys, credentials, private keys)
- Escape output to prevent XSS/injection attacks
- Use parameterized queries or ORM-provided methods — never concatenate user input into queries
- Validate and sanitize all user input at system boundaries
- Keep dependencies updated to avoid known vulnerabilities

---

## No Hardcoded Environment Values

Never hardcode environment-specific values in code — filesystem paths, hostnames, IP addresses,
ports, base URLs. They differ across machines and environments and make code non-portable.

- **Anti-pattern.** `connect("192.168.1.50:5432")`, `open("C:\\Users\\bob\\data\\out.json")`.
- **Correct pattern.** Read them from the project's central config (the config class each
  `*_RULES.md` already mandates), with a committed `.example` template documenting every key.
- Distinct from the secrets rule above: this is about **portability** (runs anywhere), not
  secrecy. A non-secret hostname still belongs in config, not in code.

---

## No God Classes

A class that handles too many responsibilities becomes fragile, hard to test, and impossible to
reuse. Keep each class focused on a single purpose.

- **Warning signs**: more than 5 public methods, more than 4 constructor dependencies, or methods that span unrelated domains (e.g., a class that validates input, queries the database, and sends emails)
- Split by responsibility: extract collaborators (e.g., a `Validator`, a `Repository`, a `Notifier`) rather than piling logic into one class
- If you struggle to name the class without using "Manager", "Handler", "Service", or "Helper" as a catch-all, it likely does too much
- This complements the 300-line file rule — a short class can still be a god class if it owns too many concerns

---

## Self-Describing Classes

When behavior depends on which fields or properties a class has — such as search, serialization,
display, validation, or auditing — the class itself must declare those fields through a contract
(interface, abstract method, attribute/annotation, or introspection pattern). Never hardcode field
lists in consuming code.

- **Anti-pattern**: A search service contains a hardcoded list of fields to index for each entity;
  adding a new field requires updating every consumer manually
- **Correct pattern**: Each class implements a contract (e.g., `GetSearchableFields()`,
  `GetDisplayColumns()`) that returns its own relevant fields, so adding a field in one place
  automatically propagates everywhere
- This applies to any cross-cutting concern that operates over class fields: search, filtering,
  export, form generation, diffing, logging, etc.
- Combine with compile-time checks where the language supports them (e.g., sealed interfaces,
  exhaustive matching) to ensure new fields cannot be silently ignored

---

## Inject Collaborators, Don't Fold Dependencies In

Composition reuse comes in two shapes, and they differ sharply in how much coupling they add to
the reusing class. **Folding** a helper into a class (mixin, trait, multiple inheritance, copy-in
include) merges *all of the helper's own dependencies* into that class — reuse five such helpers
and every one of their imports is now the host's coupling. **Injecting** a collaborator adds a
single dependency: the collaborator, which is built once and shared as a hub.

Prefer injected collaborators. Reserve fold-in reuse for helpers that are stateless and carry no
dependencies of their own.

- **Anti-pattern**: A controller reuses five behavior mixins/traits; each brings its own service,
  DTO, and constant imports, so the controller transitively depends on a few dozen things and is
  hard to test in isolation.
- **Correct pattern**: Extract that behavior into a collaborator object injected via the
  constructor. The controller depends on the collaborator; the collaborator is reused across many
  controllers as a shared, well-tested hub.

### Inject services; never instantiate one inside a method

Constructing a service with `new` (or the language equivalent) inside a method hides the
dependency from the class's public contract and makes it impossible to substitute in a test. Pass
collaborators in through the constructor.

- **Anti-pattern**: A method does `helper = new EmailPreparer(); helper.prepare(...)`. Nothing in
  the class signature reveals the dependency, and no test can replace it.
- **Correct pattern**: Inject `EmailPreparer` once; the method calls the injected instance.

### Collapse config-callback swarms into one value object

When a base class pulls its configuration from the subclass through many small overridable getters
that the subclass fills in one-line-each, each getter is a separate touch-point and the wiring is
spread across dozens of methods. Bundle the related values into a single config object built once
and handed to the base (see **Use Objects for Related Values**). This also keeps such classes off
the wrong side of **No God Classes**.

- **Anti-pattern**: A subclass implements `getSendEndpoint()`, `getSendSuccessKey()`,
  `getSendFailureRedirect()`, and a dozen more one-line getters, each naming one constant.
- **Correct pattern**: The subclass builds one `SendConfig` value object once; the base reads its
  fields.

# Version
18

Increase this version number whenever this rule file changes.

# AI Workflow Rules (All Languages)

See `COMMON_RULES.md` for rules that apply to all languages.

Unlike the per-language `*_RULES.md` files, these rules are **language-independent** and
**always apply**. They are not subject to the "some rules may not apply to this project"
filtering — include them in every project's `CODING_RULES.md`.

These rules define the end-to-end workflow an AI agent must follow when planning and
implementing changes. Each step is an existing skill referenced by its slash name; run the
skill rather than reimplementing its behavior.

---

## Delegation backends (Codex / DeepSeek)

Some of the workflow steps below can be delegated to an external CLI instead
of being performed by the agent itself. Two backends are supported, and they
are **mutually exclusive** — at most one is enabled at a time:

- `<!-- codex: enabled -->` — delegate to Codex, running:
  `codex exec --dangerously-bypass-approvals-and-sandbox "<PROMPT>"`
- `<!-- deepseek: enabled -->` — delegate to DeepSeek, running:
  `reasonix run --auto "<PROMPT>"`
- Neither marker `enabled` (or no marker) — do NOT delegate; perform the same
  checks yourself via the listed fallback skills.

Read precedence if both markers somehow end up `enabled`: Codex wins, then
DeepSeek, then the self-fallback.

**Self-fallback in a subagent.** When neither backend is enabled, prefer
running each fallback skill in a subagent (Agent/Task tool, `general-purpose`
type) rather than inline — the skill's file reads and reasoning stay out of
the main context window. The subagent runs the skill and returns **only**
its summary (and the list of files it changed). Any file edits the skill
makes (plan file, code) persist, so the main agent picks them up.

Exceptions that MUST stay in the main context: `/plan:dry-checked` (it
reloads the adjusted plan INTO context) and restating the
Definition-of-Done / DRY gate aloud.

**Graphify preamble (optional).** If this project's `CODING_RULES.md` includes
the graphify addon, prepend its graphify delegate preamble to every `<PROMPT>`
below before invoking the backend CLI (see the graphify addon's "Delegated
checks" section). If the addon is not present, send `<PROMPT>` unchanged.

The markers are managed by `/coding-rules:codex on|off|status|test` and
`/coding-rules:deepseek on|off|status|test` (or set during
`/coding-rules:apply`). Do not flip them yourself without the user asking.

### Delegation contract (never let a delegate hang)

Applies to EVERY delegated `<PROMPT>` below, both backends. A delegate that
stops to ask a question blocks forever on stdin nobody can answer — these four
rules make that impossible and leave a debug trail when it happens anyway.

- **No questions.** Append this suffix to every `<PROMPT>` before sending it:

  > "Run fully non-interactively. NEVER ask a question and NEVER wait for
  > input. If anything is ambiguous, blocked, or you cannot complete the task,
  > do NOT stop to ask — write your questions and what blocked you into your
  > output file (the plan file, or the check file for steps that write one)
  > under a heading `## DELEGATE QUESTIONS`, then exit immediately. Always
  > write the required SUMMARY block, even on failure."

- **Timeout.** Run every delegate call with `timeout: 600000` (10 min, the
  Bash tool maximum). Never make an untimed delegate call.

- **Log.** Capture stdout+stderr to a log next to the plan file, named
  `<plan-file-path-without-.md>-<step>-delegate.log` where `<step>` is
  `plan-dry`, `convention`, `post-impl` or `graphify`; close stdin so a
  delegate that ignores the contract dies instead of blocking:

  ```
  codex exec --dangerously-bypass-approvals-and-sandbox "<PROMPT>" > "<log>" 2>&1 < /dev/null
  ```

  Overwrite the log per run. On any failure, report the log path to the user
  in one line — that is the debug handle.

- **Success check + fallback.** A delegated step counts as done only if its
  required SUMMARY block is present (`SUMMARY DRY`, `SUMMARY CONVENTION
  CHECK`, `SUMMARY GRAPHIFY`, or the post-implementation check file). Timeout,
  non-zero exit, missing SUMMARY, or a `## DELEGATE QUESTIONS` heading all
  count as failure. On failure: do NOT retry — report one line plus the log
  path, then run that step's `delegate disabled` branch (subagent). If the
  delegate wrote `## DELEGATE QUESTIONS`, answer those questions yourself in
  the fallback run, or surface them to the user if they need a decision.

## Feature / Change Workflow

After a plan is proposed and the user approves it, follow this chain. The DRY
gate is a precondition for implementing — not just an earlier step.

The approved plan must first exist as an explicit Markdown file. Pass that same
path to both plan-DRY commands.

```
plan approved

plan DRY check
  delegate enabled (codex or deepseek — run <PROMPT> via that backend's CLI, see Delegation backends above; prepend graphify preamble if applicable; obey the Delegation contract — no-questions suffix, timeout, log, SUMMARY check):
    <PROMPT> = "FULL PATH TO PLAN - Can you check the plan for DRY opportunities and if you find any, apply them to the original plan file. Only edit the plan file — do NOT modify any source code or implement the plan. Always add a summary at the end called SUMMARY DRY — if you made changes, describe what and why; if you found nothing, write 'No DRY opportunities found.'"
  delegate disabled:
    run /plan:dry <plan-file> in a subagent (see "Self-fallback in a
    subagent"); inline only if a subagent isn't available.

plan convention check
  delegate enabled (codex or deepseek — run <PROMPT> via that backend's CLI, see Delegation backends above; prepend graphify preamble if applicable; obey the Delegation contract — no-questions suffix, timeout, log, SUMMARY check):
    <PROMPT> = "FULL PATH TO PLAN $convention-check - If you want to make any changes, apply them to the original plan file. Only edit the plan file — do NOT modify any source code or implement the plan. Always add a summary at the end called SUMMARY CONVENTION CHECK — if you made changes, describe what and why; if you found nothing, write 'No convention issues found.'"
  delegate disabled:
    run /convention:check in a subagent (see note) — apply findings to the
    plan file

/plan:dry-checked    reload the DRY and convention adjusted plan

restate Definition-of-Done aloud

implement
  While implementing, keep the list of every file you created or modified in THIS
  session — you know it from your own edits; do NOT derive it from git (other
  sessions may have concurrent uncommitted changes). After implementing, write the
  list (one path per line) to a changed-files file next to the plan, named after it:
  <plan-file-path-without-.md>-changed-files.md
  (e.g. claude-plans/my-feature-changed-files.md). The plan file is unique per
  session, so concurrent sessions never collide.
  Include only source-code files. Exclude documentation and other non-code
  files (`.md`, plain-text docs, the plan file itself) — the DRY audit only
  looks at code.

post-implementation DRY audit — scope is ONLY the changed-files file above
  delegate enabled (codex or deepseek — run <PROMPT> via that backend's CLI, see Delegation backends above; prepend graphify preamble if applicable; obey the Delegation contract — no-questions suffix, timeout, log, SUMMARY check):
    <PROMPT> = "Read FULL PATH TO CHANGED-FILES FILE and check ONLY the files listed there for DRY opportunities. Do not use git status or git diff to widen the scope — other sessions may have concurrent uncommitted changes. Do NOT modify any code. Write your suggestions to <plan-file-path-without-.md>-post-implementation-check.md (next to the plan, same naming as the changed-files file), overwriting the file if it already exists. Include for each finding the affected files and a short rationale. Always write the file, even if you found nothing — in that case write a SUMMARY block stating 'No DRY opportunities found.'"
    then read that post-implementation-check file, validate each finding, and apply the valid ones. Bring a finding to the user only if a question arises — otherwise apply silently.
  delegate disabled:
    run /dry:check <files from the changed-files file, as pathspec> in a
    subagent (see note)

Post-Feature Verification + Post-Implementation Code Analysis (project-specific, below)

refresh graphify graph — only if the graphify addon is present in this project's CODING_RULES.md
  NEVER run this rebuild yourself in the main context: the graphify skill loads a
  large instruction file and its build output into the window. Delegate it — the
  rules it must follow live in the graphify addon's "Refreshing after a code
  change" section, already copied into this project's CODING_RULES.md.
  delegate enabled (codex or deepseek — run <PROMPT> via that backend's CLI, see Delegation backends above; prepend graphify preamble if applicable; obey the Delegation contract — no-questions suffix, timeout, log, SUMMARY check):
    <PROMPT> = "Rebuild this project's graphify knowledge graph. Read the graphify section of CODING_RULES.md and follow its 'Refreshing after a code change' rules exactly, including the scope rules — rebuild at the scope the existing graph already has, never narrower. Run the graphify skill's directed rebuild from the repo root (/graphify <code-dir> --directed), writing to the root graphify-out/. Do NOT run a bare `graphify update`. If the graphify skill is not available to you, change nothing and reply exactly GRAPHIFY SKILL UNAVAILABLE. Otherwise end with a summary called SUMMARY GRAPHIFY stating the scan root built, whether graph.json has directed: true, and the node count before and after."
  delegate disabled:
    run the same rebuild in a subagent (see "Self-fallback in a subagent") with the
    same instructions; it returns only the SUMMARY GRAPHIFY block.
  then verify yourself — cheap, no skill load: root `graphify-out/graph.json` has
  `directed: true`, and `graphify-out/.graphify_root` matches the scope that was
  built. If the delegate replied GRAPHIFY SKILL UNAVAILABLE, or either check fails,
  redo the rebuild via the subagent branch.
```

### DRY gate (precondition for implementing)

Do not write a single line until ALL are true. Restate this gate aloud at the
moment you start implementing — if you cannot, the gate is not cleared:

- [ ] `/plan:dry <plan-file>` adjusted that file and completed its Ponytail pass.
- [ ] `/plan:dry-checked <plan-file>` reloaded the same adjusted plan.
- [ ] `/convention:check` found the existing utilities/patterns to reuse.

The gate survives the `implement` step: if mid-implementation you add a new
helper, type, or pattern the gate would have caught, stop and re-clear it
before continuing.

### Definition of Done — restate aloud before implementing

Before the first edit, state in chat what "done" means for THIS change:

- [ ] Scope: <one line — what changes, what does not>
- [ ] Reuse: <existing function/component this builds on, with path>
- [ ] DRY gate cleared (above)
- [ ] `/dry:check <session changed-files>` clean (scoped to the changed-files file, never bare; may run via subagent)
- [ ] `/verify:after-change` green (tests + analysis; may run via subagent)

### Post-implementation DRY audit — paste-in template

Run `/dry:check` scoped to the session's changed-files file, then paste and fill:

```
DRY audit — <change name>
Changed files:     <list from the changed-files file, not git>
Duplication found: <none | describe>
Consolidated into: <shared fn/module + path | n/a>
Convention reused: <name + path>
Verdict:           <clean | needs rework>
```

---

## Bug-Fix Workflow

Bug fixes use a shorter variant (no plan-DRY phase):

```
bugs:fix
  → /verify:after-change  (run in a subagent — see "Self-fallback in a
    subagent")
```

---

## Optional Addons

These live in `ai_rules_addons/` and are **not** always-on. Each is opt-in per project — ASK
the user whether they want it before wiring it into that project's `CODING_RULES.md`.

- [`ai_rules_addons/graphify.md`](ai_rules_addons/graphify.md) — graphify knowledge graph:
  scoped + directed AST build, folder layout, gitignore, and the query/refresh rules to paste
  into a project's `CODING_RULES.md`.

# Version
6

Increase this version number whenever this rule file changes.

# Flutter Rules (FVM + Mobile)

See `COMMON_RULES.md` for rules that apply to all languages.

## Core principles

1. Flutter's core principle: Composition over inheritance - small, focused widgets
2. Testability: Each widget can be tested in isolation
3. Single Responsibility: One widget = one job
4. Reusability: Components can be used elsewhere
5. Readability: Smaller files (~100-200 lines) are easier to maintain
6. Follow SOLID principles (Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion)

## Documentation Comments

Use `///` doc comments on all public classes, methods, and properties:

```dart
/// Service responsible for user authentication.
class AuthService {
  /// Attempts to log in with the given [email] and [password].
  ///
  /// Returns the authenticated [User] on success.
  /// Throws [AuthException] if credentials are invalid.
  Future<User> login(String email, String password) async {
    // ...
  }
}
```

Rules:
- Every public class, method, and property must have a `///` comment
- Use `[paramName]` to reference parameters in doc comments
- Keep descriptions concise; one sentence for simple members
- Do not use `//` block comments for documentation

---

## When to Use `part` / `part of`

Prefer normal `import` / `export` for all hand-written code. Do **not** use `part`
to split large classes, organize features into folders, or share utilities — it
hides dependencies, weakens encapsulation (all `part` files share one private
scope), and makes refactoring harder.

Use `part` only when:

1. **Code generation requires it** — the common modern case. Generators emit into
   `*.g.dart` / `*.freezed.dart` files included via `part`:

   ```dart
   import 'package:json_annotation/json_annotation.dart';

   part 'user.g.dart';

   @JsonSerializable()
   class User {
     final String name;
     User(this.name);
     factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
     Map<String, dynamic> toJson() => _$UserToJson(this);
   }
   ```

   Applies to `freezed`, `json_serializable`, `objectbox` (`objectbox.g.dart`), and
   similar — see the JSON Serialization and Database (ObjectBox) sections.

2. **One tightly-coupled library** (rare) — several files that genuinely form a
   single library and must share library-private (`_`) members.

| Scenario                                   | Use `part`? |
| ------------------------------------------ | ----------- |
| Application / widget code                  | No          |
| Splitting a large class across files       | No          |
| Organizing features or modules             | No          |
| Generated files (`freezed`, `*.g.dart`)    | Yes         |
| One tightly-coupled library impl           | Sometimes   |

Rule of thumb: **if you write the code, use imports/exports; if a generator
requires it, use `part`.**

---

## Mixins

Mixins share behavior across classes that do **not** share an inheritance chain.
Reach for a mixin only when composition (a plain helper class injected via `GetIt`,
or a field) does not fit — Flutter favors composition over inheritance, and a
mixin is a form of inheritance.

### Rules

1. **Use the `mixin` keyword, never a `class` as a mixin.** A `mixin` cannot be
   instantiated or extended, which documents intent and prevents misuse. Use
   `mixin class` only in the rare case a type must serve as both — never by default.

2. **Constrain with `on` whenever the mixin depends on a host type.** This both
   restricts where the mixin can be applied and grants typed access to the host's
   members. Prefer `mixin AnalyticsLogging on State` over an unconstrained mixin
   that assumes a `context`.

3. **Keep mixins stateless.** All `part`/mixin members live in the host's scope, so
   a mutable field in a mixin silently couples to — and can collide with — the
   host's fields. If state is unavoidable, prefix fields with `_`, document the
   ownership, and keep it to one field.

4. **One capability per mixin (single responsibility).** A mixin named for a
   behavior (`Disposable`, `Validatable`) is good; a `UtilsMixin` grab-bag is not.

5. **Name by capability**, ending in `-able` or with a `Mixin` suffix, matching the
   existing `SearchableMixin` convention. Be consistent within a project.

6. **Only call `super.method()` when the `on` constraint guarantees it exists.**
   Mixins are linearized left-to-right; later mixins override earlier ones. Know the
   apply order when overriding lifecycle methods (e.g. `initState`/`dispose`).

7. **Mark host-only members `@protected`** and give every public member a `///`
   doc comment, per the Documentation Comments rules.

8. **Do not use a mixin to share code that could be a standalone service.** If the
   behavior owns state or has dependencies, make it a class and inject it with
   `GetIt` — see Dependency Injection.

Legit Flutter framework mixins — `TickerProviderStateMixin`,
`AutomaticKeepAliveClientMixin`, `WidgetsBindingObserver` — model all of the above:
host-constrained, behavior-focused, named by capability.

### When to use a mixin vs. the alternative

| Need                                                    | Use                          |
| ------------------------------------------------------- | ---------------------------- |
| Share stateless behavior across unrelated classes       | `mixin`                      |
| Add behavior that needs a specific host (`State`, etc.) | `mixin ... on HostType`      |
| Share behavior that owns state or dependencies          | Class + `GetIt` (composition)|
| Define a contract only (no implementation)              | `abstract interface class`   |
| Reuse one widget's look/structure                       | Compose widgets, not a mixin |

Rule of thumb: **a mixin adds behavior, not state.** If you find yourself storing
data in a mixin, it should probably be a class you inject instead.

---

## Flutter Version Management

Use FVM (Flutter Version Manager) for all projects. Create `.fvmrc` in the project root:

```json
{
  "flutter": "3.44.0"
}
```

Latest verified stable as of 2026-05-26. Confirm with `fvm releases --channel stable` for new projects.

All Flutter commands should be prefixed with `fvm`:

```bash
fvm flutter pub get
fvm flutter run
fvm flutter build apk
```

---

## Localization

Use the `flutter_i18n_translations` library for multi-language support:
https://github.com/BenjaminKobjolke/flutter-i18n-translations

### Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_i18n_translations:
    git:
      url: https://github.com/BenjaminKobjolke/flutter-i18n-translations.git
```

Then run:

```bash
fvm flutter pub get
```

### Directory Structure

```
project/
├── assets/
│   └── i18n/
│       ├── en.json         # English (default)
│       ├── de.json         # German
│       └── languages.json  # Language metadata
├── lib/
│   ├── config/
│   │   ├── constants.dart
│   │   └── translation_keys.dart
│   └── main.dart
└── pubspec.yaml
```

### Configure Assets

In `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/i18n/
```

### Translation File Format

Create `assets/i18n/en.json`:

```json
{
  "app": {
    "name": "My Application",
    "welcome": "Welcome, {name}!"
  },
  "nav": {
    "dashboard": "Dashboard",
    "settings": "Settings",
    "logout": "Logout"
  },
  "auth": {
    "login_title": "Login",
    "signin_subtitle": "Sign in to access your dashboard",
    "error": {
      "auth_failed": "Authentication failed. Please try again.",
      "rate_limited": "Too many attempts. Please try again later."
    }
  },
  "common": {
    "cancel": "Cancel",
    "save": "Save",
    "delete": "Delete",
    "edit": "Edit"
  }
}
```

Create `assets/i18n/languages.json`:

```json
{
  "en": "English",
  "de": "Deutsch"
}
```

### Initialization

In `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_i18n_translations/flutter_i18n_translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize localization
  final localizationService = LocalizationService();
  final languageCode = await determineSystemLanguage();
  await localizationService.load(languageCode);
  AppLocalizations.init(localizationService);

  runApp(const MyApp());
}
```

### Usage in Widgets

```dart
import 'package:flutter_i18n_translations/flutter_i18n_translations.dart';
import 'package:myapp/config/translation_keys.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Simple translation
        Text(AppLocalizations.tr(TK.appName)),

        // With parameters
        Text(AppLocalizations.tr(TK.appWelcome,
          params: {'name': 'John'}
        )),

        // Get current language
        Text('Current: ${AppLocalizations.currentLanguage}'),
      ],
    );
  }
}
```

---

## Translation Key Naming Convention

Use dot notation with logical grouping:

```
section.subsection.key

app.name               - Application info
nav.dashboard          - Navigation items
auth.login_title       - Authentication related
auth.error.auth_failed - Nested error messages
common.save            - Reusable UI elements
```

---

## Translation Keys as Constants

Using raw strings like `AppLocalizations.tr('nav.dashboard')` is error-prone. Create a `TK` class with all keys as constants for IDE autocomplete and compile-time checking.

Create `lib/config/translation_keys.dart`:

```dart
// lib/config/translation_keys.dart
class TK {
  TK._();

  // App
  static const String appName = 'app.name';
  static const String appWelcome = 'app.welcome';

  // Navigation
  static const String navDashboard = 'nav.dashboard';
  static const String navSettings = 'nav.settings';
  static const String navLogout = 'nav.logout';

  // Auth
  static const String authLoginTitle = 'auth.login_title';
  static const String authSigninSubtitle = 'auth.signin_subtitle';
  static const String authErrorAuthFailed = 'auth.error.auth_failed';
  static const String authErrorRateLimited = 'auth.error.rate_limited';

  // Common
  static const String commonCancel = 'common.cancel';
  static const String commonSave = 'common.save';
  static const String commonDelete = 'common.delete';
  static const String commonEdit = 'common.edit';
}
```

Usage:

```dart
import 'package:myapp/config/translation_keys.dart';

// Instead of:
AppLocalizations.tr('nav.dashboard');

// Use:
AppLocalizations.tr(TK.navDashboard);
```

### Benefits

- IDE autocomplete for all translation keys
- Compile-time error if constant doesn't exist
- Easy to find all usages of a key
- Refactoring support

### Detecting unused or missing keys

Every Flutter project that uses the `TK` pattern **must** ship tooling that
detects all of the following:

1. TK constants whose i18n path does not exist (broken at runtime).
2. TK constants with no callers (dead Dart code).
3. i18n leaves with no TK constant pointing at them (orphan translations).
4. Raw `AppLocalizations.tr('literal')` calls that bypass the TK class.

Reference implementation: `tools/check_translation_keys.dart` +
`tools/check_translation_keys.bat`, shipped in `flutter_setup_files/tools/`.
Run the audit whenever a TK constant or i18n key is added or removed, and
do not consider the change complete while the audit reports any issue. The
`--fix` flag auto-substitutes matchable raw literals **and** auto-creates
TK constants for raw literals that already have a matching i18n leaf;
remaining "broken" entries (raw literal whose i18n leaf is missing too)
must be resolved by hand.

Copy the whole set — the three scripts below plus `translation_key_audit.dart`
and the `.bat` wrappers. Only two constants in `check_translation_keys.dart`
are per-project: `_topKeyToClass` (top-level i18n key → owning `TK*` class)
and `_packageName`.

Companion tooling lives next to the audit script:

- `translation_key_audit.dart` — the shared detector every script imports.
  Layout, TK parsing, and the caller scan live here so a pruner can never
  drift from the audit and delete keys the audit considers live.
- `prune_unused_translation_keys.dart` — deletes dead TK constants from
  `lib/config/translation_keys/tk_*.dart`. Safe because the audit
  guarantees zero references. Drops only the declaration lines, leaving the
  rest of the file byte-identical.
- `prune_orphan_i18n_leaves.dart` — removes i18n leaves no caller
  references (TK or raw literal). When `tools/attributes_to_remove.json`
  exists, removed paths are merged into it so a translator batch can strip
  them from locale files the script does not own; projects without that
  batch never create the file.
- `split_translation_keys.dart` — when the project's `TK` class grows past
  ~500 lines, split it into one `TKModule` class per top-level i18n key
  group with a barrel re-export. The split keeps every existing
  `TK.foo`-style call site valid after a one-shot codemod.

Two detection rules exist because a naive audit reports false positives on
both, and a pruner acting on them destroys working code:

- **`...Prefix` constants.** A constant whose name ends in `Prefix` holds a
  partial path completed at runtime — `tr('${TKStats.weekStatusPrefix}$s')`.
  It is treated as matching any leaf below its value, so it is not "missing"
  and the leaves it reaches are not orphans.
- **The `_tr` wrapper.** Widgets commonly define
  `String _tr(String key) => AppLocalizations.tr(key);` and call `_tr(...)`.
  The raw-literal scan matches both spellings; matching only
  `AppLocalizations.tr` makes category 4 blind to most of the codebase.

Both i18n layouts are auto-detected at startup — modular
(`assets/i18n/modules.json` + `assets/i18n/<module>/<locale>.json`) and
single-file (`assets/i18n/<locale>.json`). Locales come from
`assets/i18n/languages.json`.

---

## Language Switching

```dart
// Get available languages
final languages = AppLocalizations.getAvailableLanguages(); // ['de', 'en']

// Get language display name
final displayName = AppLocalizations.getLanguageName('de'); // "Deutsch"

// Switch language
await localizationService.load('de');
// Rebuild UI (e.g., restart app or use state management)
```

### Persisting Language Choice

```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> changeLanguage(String languageCode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', languageCode);
  await localizationService.load(languageCode);
}

// On app start
final prefs = await SharedPreferences.getInstance();
final savedLanguage = prefs.getString('language');
final languageCode = savedLanguage ?? await determineSystemLanguage();
```

---

## Adding New Languages

1. Copy `assets/i18n/en.json` to `assets/i18n/de.json`
2. Translate all values (keep keys identical)
3. Update `assets/i18n/languages.json`:

```json
{
  "en": "English",
  "de": "Deutsch"
}
```

---

## Project Structure

Standard Flutter mobile project structure:

```
project/
├── android/                    # Android platform files
├── ios/                        # iOS platform files
├── assets/
│   ├── i18n/                   # Translation files
│   └── images/                 # Image assets
├── lib/
│   ├── config/
│   │   ├── app_config.dart     # API URLs, timeouts
│   │   ├── constants.dart      # App constants
│   │   └── translation_keys.dart
│   ├── models/                 # Data models & ObjectBox entities
│   ├── repositories/           # Data access (ObjectBox CRUD)
│   ├── services/
│   │   ├── api_client.dart     # Dio HTTP client singleton
│   │   └── objectbox_service.dart  # ObjectBox initialization
│   ├── screens/                # Full-screen widgets
│   ├── widgets/                # Reusable widgets
│   ├── objectbox.g.dart        # Generated ObjectBox code
│   ├── objectbox-model.json    # Generated ObjectBox model
│   └── main.dart
├── test/                       # Unit and widget tests
├── tools/                      # Build scripts
│   ├── run_tests.bat
│   ├── build_debug.bat
│   └── build_release.bat
├── .fvmrc                      # FVM Flutter version
├── pubspec.yaml
├── install.bat
├── update.bat
└── README.md
```

---

## Project Setup Scripts

Copy the setup batch files from the `flutter_setup_files/` folder bundled with the
coding-rules plugin (next to this rules file).

### install.bat

Initial project setup:

- Checks if FVM is installed
- Runs `fvm install` to install Flutter version
- Runs `fvm flutter pub get` to install dependencies
- Runs tests to verify setup

### update.bat

Update all dependencies:

- Updates dependencies with `fvm flutter pub upgrade`
- Runs `fvm flutter analyze` for linting
- Runs tests to verify compatibility

### tools/run_tests.bat

Run the test suite:

- Runs `fvm flutter test`, redirected to a temp file so the script captures
  flutter test's own exit code before anything else touches it
- Shows pass/fail summary based on that captured exit code, then `exit /b`s
  with it
- If you add noise filtering for third-party log spam, filter the temp file
  with PowerShell `Select-String -NotMatch` (see comment in the bat) - never
  pipe `fvm flutter test` straight into `findstr`. The pipe's exit code
  becomes the filter's exit code, not flutter test's, so a real failure can
  silently read as a pass (or vice versa). `findstr` also has a ~8191-char
  line-length limit and errors on long compact-reporter lines, tripping the
  same bug even harder.

### tools/build_debug.bat

Build debug APK:

- Runs `fvm flutter build apk --debug`
- Shows output location

### tools/build_release.bat

Build release APK:

- Runs `fvm flutter build apk --release`
- Shows output location

### Usage

```bash
# First time setup
install.bat

# Run tests
tools\run_tests.bat

# Build debug APK
tools\build_debug.bat

# Build release APK
tools\build_release.bat

# Update dependencies
update.bat
```

---

## Approved Libraries

Before implementing any new feature, **check
[`flutter_setup_files/LIBRARIES.md`](flutter_setup_files/LIBRARIES.md)** — it lists the approved
third-party libraries, their confirmed versions, and a reference implementation for each.

- If a listed library already covers the job, use it. Do not hand-roll an equivalent and do not
  introduce a competing package for the same concern.
- If nothing listed covers it, confirm the version with the user (see `COMMON_RULES.md` →
  "Confirm Dependency Versions"), then add the library to `LIBRARIES.md` with a pointer to the
  first real implementation, so the next project picks it up automatically.

This is the same "check before you build" rule as `COMMON_RULES.md` → "Reusable Tooling",
applied to dependencies instead of scripts.

---

## App Icons

Whenever icons are involved — setting up a new project's launcher icon, replacing
existing art, adding a notification icon, or debugging one that renders wrong —
**read [`flutter_setup_files/ICONS.md`](flutter_setup_files/ICONS.md) first.**

House style is a **solid black background with simple white line art**. The guide
covers why (an adaptive icon's background layer must be opaque, so transparent is
not an option), the source-art layout, the `flutter_launcher_icons` config, and
the separate white-on-transparent notification icon Android needs — pointing a
notification at the launcher icon renders a featureless white blob in the status
bar.

Each project records its own paths and wiring in `docs/ICONS.md`.

---

# Essential Rules

## 1) Use `pubspec.yaml` as the single source of truth

Keep all dependencies and configuration in `pubspec.yaml`.

Recommended baseline:

- Flutter/Dart SDK version constraints
- Dependencies managed via `fvm flutter pub add ...`
- Lock file committed: `pubspec.lock`

### Standard Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Localization
  flutter_i18n_translations:
    git:
      url: https://github.com/BenjaminKobjolke/flutter-i18n-translations.git

  # HTTP
  dio: ^5.9.0

  # Database
  objectbox: ^5.1.0

  # Utilities
  path_provider: ^2.1.0
  path: ^1.9.0
  shared_preferences: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

  # ObjectBox code generation
  objectbox_generator: ^5.1.0
  build_runner: ^2.4.0
```

---

## 2) Enforce linting and formatting

Use the standard Flutter analyzer:

```bash
fvm flutter analyze
fvm dart format lib/
```

Configure `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
```

---

## 3) Centralize configuration

No "magic values" in code. Use a config class:

```dart
// lib/config/app_config.dart
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = 'https://api.example.com';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const bool debugMode = true;
}
```

### Sensitive Data

Never commit API keys, secrets, or credentials to version control. Use `.env` files for sensitive values:

1. Add `flutter_dotenv` to `pubspec.yaml`:

```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

2. Create a `.env` file in the project root:

```
API_KEY=your_secret_key_here
API_SECRET=your_secret_here
```

3. Add `.env` to `.gitignore`:

```
.env
```

4. Load in `main.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  // Access values: dotenv.env['API_KEY']
  runApp(const MyApp());
}
```

5. Provide a `.env.example` file (committed) with placeholder values so other developers know which keys are required.

---

## 4) Logging & Error Handling

### Logging

Never use `print()` for logging. Use `dart:developer` or the `logger` package:

```dart
import 'dart:developer' as developer;

// Simple log
developer.log('User loaded successfully', name: 'UserService');

// Log with error
developer.log('Failed to load user', name: 'UserService', error: e, stackTrace: stackTrace);
```

Or with the `logger` package:

```yaml
dependencies:
  logger: ^2.0.0
```

```dart
import 'package:logger/logger.dart';

final logger = Logger();

logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message', error: e, stackTrace: stackTrace);
```

#### Central Logger Class

Route all logging through one class named **`AppLogger`** (`app_logger.dart`). Never call
`print()`, `developer.log`, or the `logger` package directly from feature code — only
`AppLogger` wraps them. This gives a single enable/level toggle (e.g. `AppConfig.logLevel`)
without touching call sites.

```dart
AppLogger.d('Debug message');
AppLogger.i('User loaded', name: 'UserService');
AppLogger.e('Failed to load user', error: e, stackTrace: stackTrace);
```

### Error Handling

- Use try-catch for all async and critical operations
- Display user-friendly error messages in the UI (never show raw exceptions)
- Log errors with context (class name, method name, relevant parameters)

```dart
Future<void> loadUser(int userId) async {
  try {
    final user = await _userService.getUser(userId);
    emit(state.copyWith(user: user));
  } on DioException catch (e) {
    developer.log('Failed to load user $userId', name: 'UserCubit', error: e);
    emit(state.copyWith(errorMessage: AppLocalizations.tr(TK.errorLoadFailed)));
  }
}
```

---

## 5) Tests are mandatory

Use Flutter test framework:

```bash
fvm flutter test
```

Rules:

- Unit tests for services and business logic
- Widget tests for UI components
- No network in unit tests (use mocks)
- Run tests in CI on every push

---

## 6) Required Batch Files

Every project must include these batch files:

- `install.bat` - In the root directory, initial project setup
- `update.bat` - In the root directory, update dependencies
- `tools/run_tests.bat` - Runs the test suite
- `tools/build_debug.bat` - Builds debug APK
- `tools/build_release.bat` - Builds release APK

---

## 7) State Management (Cubit)

Use **Cubit** from the `flutter_bloc` package for state management. Cubit is the recommended approach for all Flutter projects.

### Why Cubit?

- **Simpler than BLoC**: No events, just methods that emit states
- **Predictable**: Clear separation between UI and business logic
- **Testable**: Easy to unit test state changes
- **Scalable**: Works for simple screens and complex apps alike
- **Less boilerplate**: Compared to full BLoC pattern

### Installation

```yaml
dependencies:
  flutter_bloc: ^8.1.0
  equatable: ^2.0.5  # For state comparison
```

```bash
fvm flutter pub get
```

### Basic Example

**State class** (`lib/cubits/counter_state.dart`):

```dart
import 'package:equatable/equatable.dart';

class CounterState extends Equatable {
  final int count;
  final bool isLoading;

  const CounterState({
    this.count = 0,
    this.isLoading = false,
  });

  CounterState copyWith({int? count, bool? isLoading}) {
    return CounterState(
      count: count ?? this.count,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [count, isLoading];
}
```

**Cubit class** (`lib/cubits/counter_cubit.dart`):

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'counter_state.dart';

class CounterCubit extends Cubit<CounterState> {
  CounterCubit() : super(const CounterState());

  void increment() {
    emit(state.copyWith(count: state.count + 1));
  }

  void decrement() {
    emit(state.copyWith(count: state.count - 1));
  }

  Future<void> loadFromApi() async {
    emit(state.copyWith(isLoading: true));
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    emit(state.copyWith(count: 42, isLoading: false));
  }
}
```

**Usage in Widget**:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/counter_cubit.dart';
import '../cubits/counter_state.dart';

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: const CounterView(),
    );
  }
}

class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: BlocBuilder<CounterCubit, CounterState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Text('Count: ${state.count}'),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => context.read<CounterCubit>().increment(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => context.read<CounterCubit>().decrement(),
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
```

### Project Structure

```
lib/
├── cubits/
│   ├── counter_cubit.dart
│   ├── counter_state.dart
│   ├── auth_cubit.dart
│   └── auth_state.dart
├── screens/
│   └── counter_screen.dart
└── main.dart
```

### Key Patterns

- **One Cubit per feature/screen**: Keep cubits focused
- **Immutable states**: Always use `copyWith` pattern
- **Equatable**: Use for efficient state comparison
- **BlocProvider**: Provide cubits at the widget level
- **BlocBuilder**: Rebuild UI when state changes
- **BlocListener**: Handle side effects (navigation, snackbars)

---

## 8) HTTP Communication (Dio)

Use Dio for all HTTP communication.

### Installation

```bash
fvm flutter pub add dio
```

Add to `pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.9.0
```

### API Client Singleton

Create `lib/services/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:myapp/config/app_config.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.requestTimeout,
      receiveTimeout: AppConfig.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static Dio get instance => _dio;
}
```

### Usage Example

```dart
import 'package:myapp/services/api_client.dart';

class UserService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getUser(int id) async {
    final response = await _dio.get('/users/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final response = await _dio.post('/users', data: data);
    return response.data;
  }
}
```

### Error Handling

```dart
import 'package:dio/dio.dart';

Future<void> fetchData() async {
  try {
    final response = await ApiClient.instance.get('/data');
    // Handle success
  } on DioException catch (e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        // Handle timeout
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        // Handle HTTP errors (400, 401, 404, 500, etc.)
        break;
      case DioExceptionType.connectionError:
        // Handle no internet
        break;
      default:
        // Handle other errors
        break;
    }
  }
}
```

---

## 9) Database (ObjectBox)

Use ObjectBox for local persistence.

### Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  objectbox: ^5.1.0

dev_dependencies:
  objectbox_generator: ^5.1.0
  build_runner: ^2.4.0
```

Run:

```bash
fvm flutter pub get
fvm dart run build_runner build
```

### Entity Example

Create `lib/models/user.dart`:

```dart
import 'package:objectbox/objectbox.dart';

@Entity()
class User {
  @Id()
  int id = 0;

  String name;
  String email;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  User({
    this.id = 0,
    required this.name,
    required this.email,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
```

### ObjectBox Initialization

Create `lib/services/objectbox_service.dart`:

```dart
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../objectbox.g.dart';

class ObjectBoxService {
  ObjectBoxService._();

  static Store? _store;

  static Store get store {
    if (_store == null) {
      throw Exception('ObjectBox not initialized. Call init() first.');
    }
    return _store!;
  }

  static Future<void> init() async {
    if (_store != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'objectbox');
    _store = await openStore(directory: dbPath);
  }

  static void close() {
    _store?.close();
    _store = null;
  }
}
```

Initialize in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ObjectBox
  await ObjectBoxService.init();

  // Initialize localization
  // ...

  runApp(const MyApp());
}
```

### Basic CRUD Operations

```dart
import 'package:myapp/models/user.dart';
import 'package:myapp/services/objectbox_service.dart';
import '../objectbox.g.dart';

class UserRepository {
  final Box<User> _box = ObjectBoxService.store.box<User>();

  // Create or Update
  int put(User user) {
    return _box.put(user);
  }

  // Get by ID
  User? get(int id) {
    return _box.get(id);
  }

  // Get all
  List<User> getAll() {
    return _box.getAll();
  }

  // Delete
  bool delete(int id) {
    return _box.remove(id);
  }

  // Query
  List<User> findByName(String name) {
    final query = _box.query(User_.name.equals(name)).build();
    final results = query.find();
    query.close();
    return results;
  }
}
```

---

## 10) In-App Debugger (Logarte)

For debugging network requests and viewing logs directly on the device, use Logarte.

See the detailed integration guide: [In-App Debugger Documentation](flutter/IN_APP_DEBUGGER.md)

**Requirements:**
- Must be accessible from the Settings screen
- Must be enable/disable via `AppConfig.enableLogarte`

**Key features:**
- Network request logging (automatic with Dio interceptor)
- Navigation event logging
- Searchable log viewer
- Password protection for release builds
- Log sharing and export

---

## Dependency Injection

Use `GetIt` for service location and dependency injection. Register services at app startup and
retrieve them via `GetIt.instance`. This keeps services decoupled and testable.

---

## JSON Serialization

Use `freezed` + `json_serializable` for type-safe API models. This generates immutable data
classes with `fromJson`/`toJson` methods, `copyWith`, and equality out of the box.

---

## Widget Rebuild Optimization

Minimize unnecessary widget rebuilds to maintain smooth performance:

- Use `const` constructors wherever possible
- Extract subtrees into separate widgets to limit rebuild scope
- Avoid building large widget trees inside a single `build` method
- Use `BlocSelector` or `BlocBuilder` with `buildWhen` to rebuild only when relevant state changes

---

## Respect System Insets (SafeArea)

Screen-level content must never render underneath the system UI — the status bar,
the notch/cutout, or the bottom navigation/gesture bar. Otherwise bottom controls
(a Save button, an FAB, the last list item) sit partly behind the Android nav bar
and are hard or impossible to tap.

- **Wrap the `Scaffold` `body` in a `SafeArea`** for any screen whose content can
  reach a screen edge — especially scrollable bodies (`ListView`, `SingleChildScrollView`,
  `Column` with a bottom button). The `AppBar` already handles the top inset; the
  bottom inset is the one that bites.

  ```dart
  // Anti-pattern: bottom button scrolls under the nav bar
  body: ListView(padding: const EdgeInsets.all(16), children: [...]),

  // Correct: SafeArea insets the scroll view above the system bars
  body: SafeArea(
    child: ListView(padding: const EdgeInsets.all(16), children: [...]),
  ),
  ```

- `EdgeInsets` padding is **not** a substitute — a hardcoded padding value does not
  track the device's actual inset (varies by phone, gesture vs button nav, landscape).
- **Don't double-inset.** A `Scaffold` `appBar` already consumes the top inset; if you
  keep `SafeArea` defaults (`top: true`) under an `AppBar` it's harmless (inset is
  already zero there), but don't also add manual top padding on top of it.
- For a body behind a keyboard, `Scaffold.resizeToAvoidBottomInset` (default `true`)
  handles the keyboard; `SafeArea` handles the persistent system bars. They are
  separate concerns — keep both defaults on unless you have a reason not to.
- Full-bleed content (a background image, an edge-to-edge map) is the deliberate
  exception: opt out per-edge (`SafeArea(bottom: false, ...)`) rather than dropping
  `SafeArea` entirely, so only the intended edge bleeds.

---

## Never Let a Widget Take Infinite Height in a Scroll View

A scroll view hands its children **unbounded** constraints on the scroll axis
(`maxHeight: infinity`). Greedy widgets resolve that by taking everything they are
offered, so a widget that is correct inside a `Column` becomes an infinite-height
child inside a `ListView`.

The damage lands on a **different widget than the buggy one**: once a child reports
infinite height, the list stops laying out and *every sibling below it is never
built*. Those siblings produce no exception, no log, and no error widget — they
simply do not exist. You end up reading the missing widget's code, which is correct.

The greedy widgets, and what they do under unbounded constraints:

| Inside a scroll view | Result |
|---|---|
| `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` | children sized to `maxHeight` → **infinite** |
| `height: double.infinity`, `SizedBox.expand` | infinite |
| `Expanded` / `Flexible` / `Spacer` in a vertical parent | error |
| `ListView` / `GridView` without `shrinkWrap: true` | error |

```dart
// Anti-pattern: fine in a Column, fatal in a ListView — and it silently
// deletes every sibling below it.
Row(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [Expanded(child: _Card()), Expanded(child: _Card())],
)

// Correct: IntrinsicHeight bounds the row, equal-height children preserved
IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [Expanded(child: _Card()), Expanded(child: _Card())],
  ),
)
```

Rules:

- **Only a `Row` is at risk from `stretch`.** A `Column`'s cross axis is horizontal,
  which is bounded — `CrossAxisAlignment.stretch` on a `Column` is fine.
- **Bound it explicitly**: `IntrinsicHeight`, a fixed `SizedBox(height:)`, or
  `AspectRatio`. Prefer `IntrinsicHeight` when children must match heights.
- **Run every new screen once in a debug build before shipping a release APK.**
  Debug asserts on this by name — `BoxConstraints forces an infinite height` — and
  points at the offending widget. Release strips the assert and the failure goes
  completely silent, which is what makes this class of bug expensive.
- **Widget-test the composition, not just the widget.** Pump the widget in a
  `ListView` *with a sibling after it* and assert both a finite height and that the
  sibling was built. A widget tested alone passes while the screen is broken.

  ```dart
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: ListView(children: const [MyRow(), Text('below')]),
  )));
  expect(tester.takeException(), isNull);
  expect(tester.getSize(find.byType(MyRow)).height.isFinite, isTrue);
  expect(find.text('below'), findsOneWidget); // never built if MyRow is infinite
  ```

- **Suspect the siblings' constraints before the missing widget's own code.** A
  widget that renders nothing and logs nothing is usually a victim, not the cause.
- The default `ErrorWidget` sizes to `constraints.biggest`, so a *crash* in a list
  child produces the same infinite blank block. A custom `ErrorWidget.builder` with a
  bounded height and the exception text turns that into a visible, readable failure.

---

## Self-Describing Classes

Implement the common "Self-Describing Classes" rule using an abstract class or mixin.

```dart
abstract class Searchable {
  /// Returns a map of field name to field value for all searchable fields.
  Map<String, String> getSearchableFields();
}

class Customer implements Searchable {
  final String name;
  final String email;
  final String phone;

  const Customer({required this.name, required this.email, required this.phone});

  @override
  Map<String, String> getSearchableFields() {
    return {'name': name, 'email': email, 'phone': phone};
  }
}
```

Alternatively, use a mixin when classes already have an inheritance hierarchy
(follow the [Mixins](#mixins) rules):

```dart
mixin SearchableMixin {
  Map<String, String> getSearchableFields();
}
```

---

## Mixins, Widgets, and Injected Services (Coupling)

Reinforces core principle #1 (Composition over inheritance) and
**Inject Collaborators, Don't Fold Dependencies In** in `COMMON_RULES.md`.

- **`with SomeMixin` folds the mixin's dependencies into the widget/class.** Stacking behavior
  mixins spreads their imports across the host. Prefer a child widget or an injected service
  (get_it / Provider / Riverpod) for anything that carries dependencies; keep mixins for small,
  dependency-free behavior.
- **A god `build()` method is a coupling sink.** A widget whose `build()` wires many services and
  passes values down through several constructor layers (prop-drilling) depends on everything it
  drills through. Extract child widgets, and pass a single config object or read shared state via
  `InheritedWidget` / a provider instead of threading many parameters.

```dart
// Anti-pattern: one widget builds everything and drills props through 3 layers
// Correct: extract InvoiceHeader / InvoiceActions child widgets; inject services via provider,
//          pass an InvoiceViewConfig value object instead of a dozen constructor params
```
