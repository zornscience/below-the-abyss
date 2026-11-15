# Claude Code repository instructions — Below the Abyss
Read GDD.md, TDD.md and CODEX_PLAN.md before modifying code. Work on one issue at a time. Never implement future milestones opportunistically.

- Use pinned Godot 4.x stable and typed GDScript.
- Keep gameplay logic modular and testable. Prefer composition, signals and Resources.
- Do not add third-party dependencies, Steam SDKs or network calls without approval.
- Do not change story, art direction, monetization or scope without approval.
- Do not store runtime scene instance IDs in save files. Use stable authored IDs.
- Treat saves as untrusted versioned data; preserve compatibility or provide migration.
- Implement keyboard and gamepad controls; avoid color-only or audio-only critical cues.
- Add tests for gameplay rules; run headless import and smoke checks.
- No placeholder code that silently pretends features work; label unimplemented behavior.
- Do not invent licensed assets or claim rights to generated or third-party media.
- In each PR provide changed files, acceptance-criteria mapping, commands/results, manual playtest instructions and known limitations.
- Do not commit secrets or Steam credentials. Avoid unrelated refactoring.
