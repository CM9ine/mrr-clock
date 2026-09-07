# Agent prompt

The prompt to hand a fresh agent to implement the next task. It is task-agnostic —
it discovers what to work on itself — so paste it verbatim every time, once per task.

**One task per agent, one agent at a time.** Each starts with no memory of the last.

Progress is recorded twice on purpose: the open/closed state of
[issues #1–#19](https://github.com/CM9ine/mrr-clock/issues) is what an agent reads, and
the checklist in [TASKS.md](TASKS.md) is what a human reads. Step 6 updates both — if they
ever disagree, the issues are right.

---

````markdown
You are implementing one task of MRRClock, a macOS menu bar app.
Repo: /Users/cmabalot/Documents/projects/mrr-clock

## 1. Find your task

Run: `gh issue list --state open --json number,title -q 'min_by(.number) | "#\(.number) \(.title)"'`

The lowest-numbered open issue is your task. Its title starts with a task id
(e.g. "T07"). **Do that one task and nothing else.** Do not start the next one,
do not fix unrelated things you notice, do not refactor code other tasks own.

## 2. Read before writing anything

- `docs/tasks/T<id>-*.md` — your full brief: what to build, and every test with
  its expected value. This is your specification.
- `docs/TDD.md` — the working rules. Follow them exactly.
- `docs/METRICS.md` — the definitions, if your task touches money or dates.
- `docs/ARCHITECTURE.md` — where your files go and which seam you're behind.

## 3. Check dependencies

Your brief lists "Depends on". If any of those issues is still open, stop and
say so — do not work around a missing dependency.

## 4. Build it, test-first

For each test in your brief's Tests list, in order:

1. Write the test.
2. Run it. **Watch it fail.** A test that has never failed proves nothing.
3. Write the least code that makes it pass.
4. Refactor with the test green.

Never write the implementation first and the tests after. If you catch yourself
doing it, delete the implementation and restart the loop.

**The expected values in the brief are the specification.** They were derived by
hand from METRICS.md. When a test fails, fix the code — never edit the
expectation to match what the code printed. If you genuinely believe a value in
the brief is wrong, stop, show your arithmetic, and ask. Do not silently change it.

Non-negotiable, every task: no network in tests · no `Date()` in tested code
(inject `Clock`) · no sleeps · no real or fake-but-plausible secrets · no
`Double` for money.

## 5. Verify

`swift test` must be green across the whole suite, not just your new tests.
Paste the summary line into your report.

If your brief has a **manual checklist** (the UI and release tasks do), you
cannot tick those boxes yourself. Do the code and the unit tests, then post the
checklist as a comment on the issue for a human to run.

## 6. Finish

1. Tick your task's box in the `## Progress` section of `docs/TASKS.md`.
2. Commit to `main`: subject `T07: short description`, body listing the tests
   you added. Do not commit a red suite.
3. `git push origin main`
4. Close the issue with a comment listing the tests added and anything a later
   task should know.

## Stop and ask instead of guessing if

- a dependency issue is still open
- an expected value in the brief looks wrong
- the brief contradicts METRICS.md or ARCHITECTURE.md
- the work needs a decision the docs don't cover

## Report back

Which task you did, the tests you added, `swift test` output, and anything
surprising you hit.
````

---

## Notes

- **T01 is the exception to step 5.** There is no suite to be green until it creates one.
  Its brief covers that.
- **It commits straight to `main`**, matching the one-commit-per-task rule; there is no
  branch protection to fight. To review each task before it lands, change step 6 to branch
  as `task/T07` and open a PR with `gh pr create` — nothing else changes.
- **Each agent needs `gh`, `git` and `swift` on PATH**, and `gh` already authenticated.
- If an agent dies mid-task, its issue stays open and the next agent picks it up. Check for
  a half-finished working tree before starting: `git status`.
