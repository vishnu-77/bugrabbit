# Review-report template (pr-reviewer output)

Structured findings the `pr-reviewer` returns; the Coordinator records each as an `F-NNN` row.

```
## Review — <PR #N | range | working tree> — <repo> — <date>
Verdict: pass | changes_required   (changes_required if any critical/high)

| severity | category    | location (file:line) | failure scenario                 | suggested fix        | verdict    |
|----------|-------------|-----------------------|-----------------------------------|-----------------------|------------|
| high     | correctness | app.js:214           | empty scan → r.meta undefined → TypeError | guard r.meta, default {} | CONFIRMED |
| medium   | tests       | app.js:214           | no test for empty-scan path      | add regression test  | CONFIRMED  |

Notes: <uncertainties, PLAUSIBLE items, out-of-scope observations>
```

Rules: most-severe first; every row needs `file:line` + a concrete failure scenario; empty table when
clean. Review-only — no code edits, no merge.
