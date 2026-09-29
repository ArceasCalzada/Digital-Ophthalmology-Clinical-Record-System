# Notes for AI coding assistants

## Firebase access: NONE (deliberate)

The Firebase project `docrs-clinical-system` holds real patient records. The owner has decided
that AI assistants get **documentation only, never live access**:

- Only the Firebase *skills* (documentation) are installed, in `.claude/skills/`
  (source: <https://github.com/firebase/skills>, pinned in `skills-lock.json`).
- The **Firebase MCP server / plugin is intentionally NOT installed**, and no `firebase login`,
  service-account key, or Application Default Credentials should be set up for an assistant.
- Do not run `firebase deploy`, read or write production Firestore/Auth data, or change the
  Firebase or Google Cloud consoles. Ask the owner to do those steps; the checklist is in
  `docs/FIREBASE_SETUP.md`. Testing happens against the local emulator (`firebase-rules-tests/`).
- If a task seems to need live access, stop and ask the owner instead.

## Limits and rules

Storage limits (1,000 patients, etc.) live in `lib/config/app_limits.dart` and `firestore.rules`.
Change both together and run `npm test` in `firebase-rules-tests/`.
