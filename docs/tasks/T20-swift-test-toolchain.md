# T20 · Make plain `swift test` work locally and in CI

**Depends on:** T01 (closed) · **Milestone:** M1 · Foundation follow-up

## Goal

After documented development setup, running plain `swift test` from the repository
root discovers Swift Testing and runs the full suite without extra framework flags.
Verify the same command in macOS CI.

This is an independently assignable tooling task. When assigned T20 explicitly, work
this task rather than selecting the lowest-numbered open issue. It does not depend on
T04–T19 and does not change their sequencing.

## Read first

- [TDD.md](../TDD.md), including the Command Line Tools workaround
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [T01](T01-package-skeleton.md)
- `Package.swift` and any existing CI/setup documentation

## Observed failure

During T03, on Apple Swift 6.3.3 / Command Line Tools 26.6, plain `swift test`
failed with `error: no such module 'Testing'`. The full command with the framework
compile/link/runtime paths documented in TDD.md passed:

```text
✔ Test run with 23 tests in 2 suites passed after 0.003 seconds.
```

That baseline includes one existing disabled Money precondition test. Preserve its
status; do not disable additional tests or change domain expectations to fix tooling.
The actual suite may grow before this task starts: compare discovery against the suite
at the working revision, not a permanently fixed count of 23.

Sandboxed execution also encountered compiler-cache permission errors. Distinguish
those from framework discovery; neither is a failing domain assertion. Investigate the
root cause before choosing a remedy. A particular toolchain installation is not yet
proven to be the solution.

## Build

- Record the selected developer directory, Swift version, SDK and executable paths.
- Reproduce the unmodified command's failure before changing setup or configuration.
- Find the smallest maintainable remedy. Document the supported macOS development
  toolchain and exact reproducible setup. Prefer supported toolchain selection/setup
  over embedding one machine's absolute framework paths in the package.
- Keep Swift Testing and the dependency-free core package. A wrapper, shell alias, or
  command that still requires extra `-Xswiftc`/`-Xlinker` flags is not plain `swift test`.
- Add or update macOS CI to run plain `swift build` and `swift test` on pushes and pull
  requests. State the selected runner/toolchain; verify an actual successful CI run.
- Update TDD.md with the verified setup and status of the old workaround. Retain the
  workaround as historical/fallback guidance only if still useful, clearly labeled.

## Tests / verification, in order

This task tests toolchain wiring through command-level checks. Use the existing suite
as the regression test; do not add a trivial unit test merely to inflate the count.
Capture the initial failing command, then the successful commands after the remedy.

1. **Plain command reproduces the reported failure before the fix.** Capture its output
   and toolchain details. If it already succeeds, investigate what changed and document
   the evidence rather than manufacturing a failure.
2. **A clean build succeeds.** Run `swift package clean`, then plain `swift build`.
   Expected: exit status 0, no project warnings or errors.
3. **Plain test discovers and executes the entire suite.** Run plain `swift test` after
   the clean build. Expected: exit status 0, every enabled test at this revision runs,
   no additional skips, no missing Testing module or framework loader failures.
4. **A fresh shell works after documented setup.** Repeat plain `swift test` from a fresh
   shell without a shell alias or ad hoc framework flags. Expected: exit status 0 and
   the same enabled suite discovered.
5. **macOS CI runs the same commands successfully.** Expected: a green run of plain
   `swift build` and `swift test`; record the run URL, toolchain version and summary.

No network inside tests, no sleeps, no new wall-clock dependencies, no secrets, and no
changes to money/date expectations. CI checkout/setup may access the network; tests may not.

## Done when

- All verification above is evidenced in the issue report.
- The supported local setup runs plain `swift test` successfully.
- The CI run is green and linked from the issue.
- Setup documentation is sufficient for another developer to reproduce the result.
- Tick T20 in TASKS.md only on completion, commit the tooling fix with subject
  `T20: ...`, push, and close the issue with the evidence and any remaining limitations.

## Out of scope

Implementing another product task; rewriting existing tests; fixing the existing
Money precondition-test skip; replacing Swift Testing; adding app UI or release signing.
