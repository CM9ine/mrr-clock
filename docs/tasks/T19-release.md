# T19 · Release build, signing, install

**Depends on:** T18 · **Milestone:** M6

## Goal

A signed app running from `/Applications` on your own machine, with a live Stripe key and
your real goals. Done means *in use*, not *compiles*.

## Build

1. **Icon** — a 1024 px source rendered to the full `AppIcon` set. A menu bar template
   image (monochrome, `.template` rendering) so it adapts to light and dark menu bars.
2. **Signing** — Developer ID Application. Hardened runtime on. Entitlements: outgoing
   network, Keychain. Nothing else.
3. **Notarise** — `xcrun notarytool submit --wait`, then `xcrun stapler staple`.
   Only needed if the app will ever be copied to another machine; skip for a local-only
   build and note that in the commit.
4. **Archive and export** to a `.app`, copy to `/Applications`.
5. **Switch to the live key** — create the restricted key per
   [STRIPE.md § The key](../STRIPE.md#the-key), paste it in Settings.
6. **Enter your real goals**, each with a target amount where you have one.
7. **Enable launch at login.**

## Verification

There are no new unit tests here. There is a release checklist, and every box must be
ticked before the task is closed:

- [ ] `swift test` green — the full suite, one final time
- [ ] Release build runs with no debug logging and no `print`
- [ ] `codesign -dv --verbose=4` shows the Developer ID and the hardened runtime
- [ ] Launching from `/Applications` shows no Gatekeeper warning
- [ ] MRR shown matches the Stripe Dashboard's own MRR to within a few dollars —
      **if it does not, do not adjust the code to match; find out which one is right.**
      The Dashboard uses its own conventions ([METRICS.md](../METRICS.md) documents ours),
      so a small difference may be correct and explainable. An unexplained one is a bug.
- [ ] Earned to date matches the Dashboard's net volume for the same period
- [ ] Countdown matches a hand count from a calendar
- [ ] Quit and relaunch: numbers appear instantly from cache
- [ ] Leave it running for a full day: no leak, no runaway CPU, no duplicate menu bar item
- [ ] `grep -rn "2027\|rk_live\|sk_live" Sources/ App/` returns nothing

## Afterwards

Write down, in `docs/RETRO.md`:

- What the MRR actually was on day one
- Which of the 19 tasks took the longest, and why
- What you would cut if you built it again

Then open the goals list and check the number. That is the whole point of the thing.

## Out of scope

App Store distribution, Sparkle auto-updates, a website. If a second person ever wants a
copy, that is a new plan.
