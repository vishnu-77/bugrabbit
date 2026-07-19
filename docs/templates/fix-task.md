# Fix-task template (one per FIX-NNN)

Copy this block into `docs/backlog.md` under "Task bodies". Keyed by `owner/repo#issue`.

```
### FIX-NNN · <owner>/<repo>#<N> · <short title>
- **Repository:** <owner>/<repo>
- **Severity:** critical | high | medium | low
- **Reproduced:** yes/no — <how: command / input / failing test>
- **Root cause:** <file:line> — <function> — <why it fails> (via codebase-memory trace)
- **Symptom site (if different):** <file:line>
- **Blast radius (trace_path):** callers/dependents = <list>
- **Proposed fix (minimal):** <what to change at the cause site — smallest correct change>
- **Verify:** before = <repro fails>, after = <repro passes>, gate = green
- **Branch:** fix/<N>-<slug>
- **Status:** READY | IN-PROGRESS | IN-REVIEW | DONE | BLOCKED
- **Notes:** <uncertainties / follow-ups>
```
