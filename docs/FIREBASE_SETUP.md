# DOCRS — Firebase setup & security checklist

Project: **`docrs-clinical-system`** (project number `805661697613`).

---

## START HERE — handoff for the Firebase administrator

**Who this is for:** the person with Owner/Editor access to the Firebase project who will set it up.

**What this branch (`feature/secure-firestore-web`) does**

- Replaces the fake login with real Firebase sign-in (email + password). Only accounts that also have a
  role document in Firestore (`users/{uid}`) can open the app or read any data.
- Adds Firestore security rules (`firestore.rules`) that enforce roles, field/size limits and a hard cap of
  **1,000 stored patients**. Nothing can be deleted from the app.
- Moves visits and prescriptions into per-patient subcollections and stores drawings as compact bytes.
- Turns off Firestore's automatic indexing (`firestore.indexes.json`) — it was ~85 % of the stored bytes.
- Makes the app work on the **web** (Firebase Hosting config + security headers included).

**Nothing in this branch changes the live Firebase project by itself.** The rules, indexes, users and
settings only take effect when *you* do the steps below.

> ⚠️ **Do not deploy the rules before the users and role documents exist** (steps 3 and 4 below), or
> nobody — including you — will be able to open the app. Do the steps in order.

### Checklist (tick as you go)

Everything is explained in the numbered sections further down; this is the order and the "done" check for each.

- [ ] **A. Get the code and check it builds** — `git fetch && git checkout feature/secure-firestore-web`.
      Windows only: enable **Developer Mode** (`start ms-settings:developers`), then `flutter pub get`.
      *Done when:* `flutter analyze` shows no issues.
- [ ] **B. (Recommended) run the tests** — `flutter test`, then `cd firebase-rules-tests && npm ci && npm test`
      (needs Java 21+ for the emulator). *Done when:* both pass (Flutter 82 tests, rules 55 tests).
- [ ] **C. Plan and cost protection** — sections **1** and **2**. *Done when:* you know if the project is Spark or Blaze,
      and (if Blaze) a budget alert exists.
- [ ] **D. Create the sign-in accounts** — section **3**. *Done when:* each staff member can be found under Authentication → Users,
      sign-up is **disabled**, and you have each person's **User UID**.
- [ ] **E. Create the role documents** — section **4**. *Done when:* `users/{uid}` exists for every account, with `role` =
      `admin`, `physician` or `staff`. **Do this before F.**
- [ ] **F. Publish rules and indexes** — section **5** (`firebase deploy --only firestore:rules,firestore:indexes`).
      *Done when:* the deploy succeeds **and** the `curl` check in section 5 is refused (403).
- [ ] **G. Restrict the API keys** — section **6**.
- [ ] **H. App Check** — section **7**. Register the apps, **watch for a day, only then click Enforce.**
- [ ] **I. Preview the web app, sign in with each role, then publish** — section **9**.
- [ ] **J. Report back** — see "What to send back" below.

### Who should get which role

The old login screen listed three physicians: Dr. Sigrid Robillos, Dr. Arceas Calzada, Dr. Jenkins. Decide the real
accounts with the clinic. Suggested: the clinic owner = `admin` (1–2 people only), doctors = `physician`,
front-desk = `staff` (registers patients and uses the calendar; **cannot** see visits or prescriptions).

### What was tested, and what was NOT (please check the second list)

Tested (automatically): app logic and screens (Flutter tests), the security rules against the Firestore **emulator**
(including replaying the app's real saves), and a release web build loaded in headless Chrome with the security headers
(login page renders, Firebase initialises, no console errors).

**Not tested against the real project — please verify these and tell us what you see:**

1. `firebase deploy --only firestore:indexes` — the file uses the documented `"fieldPath": "*"` exemption syntax but was never deployed.
   If the CLI reports an error, send us the exact message.
2. **Signing in with a real Firebase account** and saving a patient, a visit (with a drawing) and a prescription end to end.
3. **App Check** with real keys, and the web **Content-Security-Policy** with the real hosting domain (open the browser console, F12).
4. **Android / iOS builds** — not built. The Windows and macOS generated plugin files are refreshed by `flutter pub get`.
5. The Firestore storage numbers are estimates; after some real use compare them with the console's usage page.

### What to send back

- The result of each checkbox above (a screenshot of the `users` collection and of the rejected `curl` is plenty).
- Any error text from a deploy or build, copied exactly.
- The hosting preview URL, and which roles you signed in with successfully.
- Anything in the rules that blocked a legitimate action (the app shows a red "Not saved" badge with the reason).

### Rules of the road

- **Do not give an AI assistant live access** to this project (no MCP server, no service-account key). See `CLAUDE.md`.
- Deleting patients is done **in the console**, then lower the counter — see section 10.
- To change any limit, change `lib/config/app_limits.dart` **and** `firestore.rules` together and run the tests.

---

The full step-by-step follows.

The code now assumes real sign-in, locked-down Firestore rules, and a hard cap of
**1,000 stored patients**. None of that protects you until the steps below are done
in the Firebase / Google Cloud consoles — the repo cannot do them for you. Do them
**in this order**; each step is safe to do before the next.

> ⚠️ **Order matters.** If you publish the new rules *before* creating users and
> role documents (steps 3–4), nobody — including you — can open the app.

---

## 0. One-time tools on your computer

```powershell
npm install -g firebase-tools     # the Firebase CLI
firebase login                    # sign in with the Google account that owns the project
firebase use docrs-clinical-system
```

On Windows, turn on **Developer Mode** (Settings → System → For developers) so
Flutter can build plugins, then run `flutter pub get` once. This also regenerates the
Windows/macOS plugin registrant files for the new `firebase_auth` and
`firebase_app_check` packages.

## 1. Check who owns the project and which plan you are on

1. Open <https://console.firebase.google.com/project/docrs-clinical-system/settings/iam>.
   *Project settings → Users and permissions* lists every account with access.
   Remove anyone who should not be there. Keep **at least two Owners** so you cannot lock yourself out.
2. Open <https://console.firebase.google.com/project/docrs-clinical-system/usage/details>.
   Note whether the plan says **Spark** (free, cannot be billed) or **Blaze** (pay as you go).
   - **Stay on Spark if you can.** With 1,000 patients the app fits inside the free
     limits (1 GiB stored, 50,000 reads/day, 20,000 writes/day), and Spark can never produce a bill.
   - If you are on Blaze, do step 2 **before anything else**.

## 2. Cost protection (Blaze only, but do it first if you have Blaze)

1. <https://console.cloud.google.com/billing> → your billing account → **Budgets & alerts → Create budget**.
2. Scope: project `docrs-clinical-system`. Amount: for example **$5 / month**.
3. Alert thresholds: **50 %, 90 %, 100 %**, emails to at least two people.
   *A budget only sends alerts; it does not stop spending.*
4. Optional hard stop: connect the budget to a Pub/Sub topic and a small Cloud Function that
   disables billing at 100 % (Google documents this as "Disable billing usage with notifications").
   Disabling billing turns the project back into Spark-like behaviour and the app will stop working until you re-enable it.

## 3. Sign-in: create the three physician accounts

1. <https://console.firebase.google.com/project/docrs-clinical-system/authentication/providers>
   → **Sign-in method** → enable **Email/Password**. Leave every other provider **off**
   (especially *Anonymous*). Do **not** enable "Email link".
2. **Settings → User actions** → **untick "Enable create (sign-up)"**. This stops strangers
   registering accounts; only you can add users. Also tick **Email enumeration protection**.
3. **Users → Add user**: create one account per person (email + a long unique password).
   Have each person change it on first sign-in. Write down each user's **User UID** (shown in the table).
4. Recommended: **Settings → Password policy** → require length ≥ 12.
5. **Settings → Authorized domains**: keep only `localhost` (for development) and your hosting domains
   (`docrs-clinical-system.web.app`, `docrs-clinical-system.firebaseapp.com`, and your custom domain if any).

## 4. Roles: the `users` collection

The app and the security rules only let in accounts listed in Firestore under
`users/{uid}`. Create one document per person:

1. <https://console.firebase.google.com/project/docrs-clinical-system/firestore/databases/-default-/data>
   (If Firestore has never been created, create it in **production mode**. *The region cannot be changed later.*)
2. **Start collection** → id `users`. For each person: **Document ID = their User UID** (from step 3), one field:

   | Field | Type | Value |
   |---|---|---|
   | `role` | string | `admin`, `physician`, or `staff` |

   - **admin** — everything a physician can do (only role that you should give to the clinic owner; keep this to 1–2 people).
   - **physician** — patients, visits, prescriptions, calendar, notifications.
   - **staff** — patient registration, calendar, notifications. **Cannot** read or write visits or prescriptions.
3. (Optional) create `meta` → document id `counters` with number fields
   `patientCount = 0`, `encounterCount = 0`, `prescriptionCount = 0`. If you skip this the first save creates it.

> Nobody can edit `users/` from the app — only from this console. That is deliberate.

## 5. Publish the security rules

From the project folder:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

- `firestore.rules` enforces sign-in + role, field/size limits, the **1,000-patient cap**, bounded queries, and **no deletes from the app**.
- `firestore.indexes.json` **switches off automatic indexing** for every collection and keeps only the one index the app
  queries (`lastModified`, newest first, on visits and prescriptions). Automatic indexes were ~85 % of the bytes stored per visit,
  so this cuts stored data per visit from roughly 27 KB to under 5 KB. Deploying it makes Firestore drop the old index entries.
  If a future feature filters or sorts on another field, add that index on purpose (`indexes.test.mjs` will remind you).

Cloud Storage: DOCRS does not use it. If you have never opened **Storage** in the console, leave it that way.
If it is enabled, also run `firebase deploy --only storage` to publish `storage.rules` (deny everything).

**Verify the rules work** (should be refused, `403 PERMISSION_DENIED`) — replace `YOUR_API_KEY`
with the `apiKey` value from `lib/firebase_options.dart` for the `web` app:

```powershell
curl "https://firestore.googleapis.com/v1/projects/docrs-clinical-system/databases/(default)/documents/patients?key=YOUR_API_KEY"
```

If that returns patient data, **stop and re-check step 5** before going any further.

## 6. Restrict the API keys

The Firebase API key is public by design, so limit what it can do.
<https://console.cloud.google.com/apis/credentials?project=docrs-clinical-system> → for **each** key:

| Key | Application restriction |
|---|---|
| Browser key | **Websites** → `https://docrs-clinical-system.web.app/*`, `https://docrs-clinical-system.firebaseapp.com/*`, your custom domain, and `http://localhost:*/*` while developing |
| Android key | **Android apps** → package `com.example.ophthalmology_clinical_record_system` + your signing **SHA-1** |
| iOS key | **iOS apps** → the bundle id |

Under **API restrictions** choose *Restrict key* and allow only: Identity Toolkit API, Token Service API,
Cloud Firestore API, Firebase Installations API, Firebase App Check API, reCAPTCHA Enterprise / reCAPTCHA API.

## 7. App Check (blocks scripts that copy your API key)

<https://console.firebase.google.com/project/docrs-clinical-system/appcheck>

1. **Web app**: register with **reCAPTCHA v3** → create the site key at <https://www.google.com/recaptcha/admin> (type *v3*, add your hosting domains). Give the *site key* to the build (step 9); paste the *secret key* into the console.
2. **Android**: register with **Play Integrity** (needs the app to be distributed through Google Play, including internal testing — a sideloaded APK will not pass).
3. **iOS/macOS**: register with **App Attest** or **DeviceCheck**.
4. **Windows desktop has no hardware attestation.** Its build uses a debug provider, so you must register a debug token for each Windows PC (run the app, copy the token from the log, add it under *Manage debug tokens*). If most users are on the web/Android/iOS apps, this is fine.
5. **Do not click "Enforce" yet.** Run the apps for a day and check the App Check **Requests** graph shows *Verified* traffic. Then **Enforce** for **Cloud Firestore** and **Authentication**. Enforcing before every client is registered locks those clients out.

## 8. Backups

*Firestore → Disaster recovery* (Blaze): enable **scheduled backups** (daily, 7-day retention) and **Point-in-time recovery**.
On Spark, export manually now and then: `gcloud firestore export gs://<bucket>`.

## 9. Build and publish the web app

```powershell
flutter pub get
flutter build web --release --dart-define=DOCRS_RECAPTCHA_SITE_KEY=<your reCAPTCHA v3 site key>

# test on a temporary preview URL first (expires after 7 days)
firebase hosting:channel:deploy preview --expires 7d

# then the real site
firebase deploy --only hosting
```

Open the preview URL and check the browser console (F12) has no red errors, that you can sign in, and that
patient data loads. `firebase.json` sets security headers (CSP, HSTS, no framing). The CSP allows inline scripts
because the Firebase web plugin injects some; everything else is restricted to Google's Firebase domains.

**Automatic deploys (optional):** in GitHub → Settings → Secrets and variables → Actions add
`FIREBASE_SERVICE_ACCOUNT` (from `firebase init hosting:github`) and the variable `DOCRS_RECAPTCHA_SITE_KEY`.
`.github/workflows/ci.yml` then tests every push and deploys `main` to Hosting. Rules are never deployed from CI.

## 10. Everyday administration

| Task | How |
|---|---|
| Add a user | Authentication → Add user, then a `users/{uid}` document with a role (steps 3–4) |
| Remove someone | Authentication → disable or delete the user (and delete their `users/{uid}` document) |
| Clinic is at the 1,000-patient limit | Export/archive old patients, delete them **in the console** (patient document **and** its `encounters` / `prescriptions` subcollections), then lower `meta/counters.patientCount` by the number removed (and `encounterCount` / `prescriptionCount` likewise) |
| Raise the limit | Change `AppLimits.maxPatients` in `lib/config/app_limits.dart` **and** the number `1000` in `firestore.rules`, run the tests, and redeploy |
| Change any rule | Edit `firestore.rules`, run `npm test` in `firebase-rules-tests/`, then `firebase deploy --only firestore:rules` |

## Limits enforced (client **and** rules)

| Limit | Value |
|---|---|
| Stored patients | **1,000** |
| Visits (all patients) / per patient | 20,000 / 200 (per-patient limit is enforced in the app) |
| Prescriptions (all patients) | 20,000 |
| Patient document | ≤ 8 KB (demographics only) |
| Visit document | ≤ 50 KB (drawings are stored as compact bytes: ≤ 20 KB sheet, ≤ 8 KB per eye) |
| Long text / notes / short fields | 2,000 / 1,000 / 300 characters |
| List queries | must carry a `limit` (patients ≤ 1,000, visits ≤ 200, calendar/alerts ≤ 500) |
| Deleting from the app | not allowed |

## What is and is not protected

**Protected by the rules + tests:** anonymous access, accounts without a role, staff reading clinical records,
unknown fields, oversized text/drawings, exceeding the patient/visit/prescription caps, full-collection scans, deletions.

**Not protected (know the limits):**

- A signed-in user who is *listed* in `users/` is trusted with the data their role allows. Use strong unique passwords
  and remove people who leave.
- Short structured exam values (visual acuity, refraction) are key-restricted but not length-restricted by the rules
  (Firestore rules stop at 1,000 expressions). Storage is still bounded by the 1 MiB document limit and the 20,000-visit cap.
- The number of calendar events and notifications is not capped by the rules (each is small and role-gated).
- Firestore rules cannot rate-limit. App Check (step 7) and the budget alert (step 2) are your protection against traffic floods.
- Patient data is cached on-device by Firestore on Android, iOS, macOS and Windows (private app storage, capped at 100 MB).
  Use device passcodes / disk encryption. The **web** app keeps no offline copy and asks for sign-in after 30 minutes of inactivity.
