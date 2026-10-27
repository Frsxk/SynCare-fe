# SynCare: Flutter client

Current M11 closed locally2026-10-27: [report](../docs/planning/mvp-verification-report.md), [runbook](../docs/planning/demo-runbook.md).216 full tests/clean analyzer/web build PASS; actual patient tab-session migration/reload/original expiry/new independent tab/logout included in6 combined browser cases. Encrypted sessionStorage is the documented local preview alternative; no persistent grant, no HttpOnly/XSS-immunity claim. Native storage unchanged; absolute24h/no renewal, login may be needed after closing tab. Host fixture adapter outside lib/ reads protected credentials privately; actual two-account integration1 PASS. Native/deployment deferred; older entries historical.

M11 current2026-10-27: [verification](../docs/planning/mvp-verification-report.md), [local demo runbook](../docs/planning/demo-runbook.md).214 full tests/analyze PASS;3 new accessibility tests cover held/urgent/missing/error at320/text200 and keyboard48dp. Existing compiled patient3001 retained because product source unchanged. M11 remains in progress/NOT_READY: default Flutter web encrypted localStorage is an open NFR-004 boundary; no native storage/IME/deployed certification. Other current security/Q10 limits are in the report. Earlier entries are historical.

## Patient clarity revision,2026-10-26

Patient copy is shorter and form/card/action spacing is clearer. Routine technical evidence is retained in labeled expandable PatientDetails with keyboard/button semantics; urgent/reassessment warnings remain visible. Plan cards fill the available width and wrap original text. Final211 tests/analyzer/web build and15 real-browser shots/two accounts/eight disclosure interactions PASS. [Verification and limits](../docs/planning/SYNCARE-PATIENT-CLARITY-VERIFICATION.md). Refresh patient3001 to load the latest build. No M11/backend/Next nurse work; older entries below are historical.

## Pre-M11 design refinement,2026-10-26

Updated green/navy/steel supporting palette, white record/form cards, functional icons, early primary check-in and selected bottom navigation. Light Material3/native fonts, routes, data and clinical warnings retained. Theme: lib/theme/app_theme.dart, compatible export core/theme.dart. Final208 tests/analyze/web build PASS; actual390px browser login/summary/check-in/homecare/plan and all changed route actions PASS. Shared320dp/text200/state regressions included. [Both-client design evidence and limitations](../docs/planning/SYNCARE-PRE-M11-DESIGN-VERIFICATION.md). Open patient3001 with local backend8080. Browser evidence only; M11 unstarted. Older sections below are historical.

## Current M10 integration evidence,2026-10-26

M01-M09/browser support accepted; M10 locally complete awaiting ACC. [Report](../docs/planning/SYNCARE-M10-VERIFICATION.md), [SDK browser setup](../docs/planning/identity-monitoring-evidence.md).207 full tests/analyzer clean/web build78.4s PASS. Official test-only integration binding/host driver use runtime private fixtures and the real app/providers/web storage; production main unchanged. Final compiled browser two accounts verifies Completed booking, canonical plan, all4 F5 sources, private resolved alert, persistent F2 warning and no-plan/F5 urgent390/320/pageErrors0. Existing patient3001/backend8080 setup below remains. Original Android command NOT RUN/native plugins/deployed/whole-MVP open. M11 unauthorized; earlier status paragraphs historical.

## Current local M09 behavior,2026-10-26

M01-M08/browser support accepted; M09 locally complete awaiting ACC. Tanya Rencana uses authenticated own Q1, one session-bound async state and exact typed F5 outcomes. Every citation is shown with complete wrapping ID and approved-plan/unapproved-education distinction. Refusal stays verbatim; F5 urgent uses sourced guidance without alert/call/dispatch claim; error offers explicit retry. No default patient identity/direct Langflow/raw JSON narrative. Nurse Flutter routes remain authenticated and retained.

[M09 evidence](../docs/planning/SYNCARE-M09-VERIFICATION.md):206 full tests plus final10 ask/two actual integration checks, final analyzer clean, web build173.9s and isolated compiled actual three-source answer/second urgent warning390/320 PASS/pageErrors0.113-file client scan PASS. Existing browser setup below unchanged;3001 patient/8080 backend/3000 nurse. Native/plugins/APK/deployed/whole-MVP open, M10-M11 unauthorized. Earlier status notes historical.

## Current local M08 behavior,2026-10-26

M01-M07/browser support accepted; M08 locally complete awaiting ACC. Normal Rencana route uses authenticated own-patient C7 verified care-plan history/source applicability, strict DTO and scoped Riverpod provider. Clinical artifact stays unchanged, including original DRAFT field; surrounding metadata states canonical row+audit approval. No staff reviewer note/raw source/direct Langflow. Loading/empty/error/retained refresh/denied/disposal/paging states are tested; no legacy identity fallback.

[M08 evidence](../docs/planning/SYNCARE-M08-VERIFICATION.md):197 full tests plus two actual HTTP/provider/captured320-text200 checks, analyzer no issues, web build96.9s and isolated compiled actual keyboard-login/own-plan/refresh at390/320 PASS/pageErrors0.111-file final client configured-value scan PASS. Existing browser startup below remains current; patient3001/backend8080/nurse3000. No device/AVD at final inventory; native/plugins/APK/deployed/whole-MVP unverified. M09-M11 unauthorized. Earlier status paragraphs below are historical.

## Current local M07 behavior,2026-10-26

M01-M06/browser support accepted, Q07 approved; M07 locally complete awaiting ACC. Ringkasan/urgent result -> Buka status tindak lanjut opens own lazy alert history and safe detail. Status/public summaries/report time/acknowledgment and operational timeline come from Bun; internal notes and staff controls are excluded. Sourced119 guidance is information only; operational closure never means recovered. Loading/empty/error/retry/refresh/denied and account disposal remain explicit. No direct Langflow call or client clinical scoring.

[M07 evidence](../docs/planning/SYNCARE-M07-VERIFICATION.md):193 full Flutter tests plus final13 after contextual loading-label refinement, two actual HTTP/provider/captured320-text200 checks, analyzer and final web build47.2s PASS. Isolated final compiled-browser actual keyboard login/history/pending-source detail/refresh at390/320 PASS, pageErrors0. Native/Android/iOS/storage/APK and deployed gates remain unverified. Browser startup below remains current; older milestone status text is historical. M08-M11 unauthorized.

## Local patient browser preview, accepted 2026-10-26

Open `http://127.0.0.1:3001` to test the Flutter patient app in the browser, with backend8080 running. From this directory run `./tool/run-browser.ps1` using Flutter3.44+/Dart3.12 on PATH, or set SYNCARE_FLUTTER_SDK to your SDK directory. The verified workstation SDK is `C:/Users/User/AppData/Local/Temp/syncare-flutter-3.44.0`. The script builds bundled local web resources with API_BASE=127.0.0.1:3001 then starts the loopback-only preview. For an existing build use `node tool/serve_browser.mjs`; rebuild after code changes. Nurse dashboard remains3000.

The same-origin development relay forwards only caller-supplied auth/intent headers to backend8080; it rejects foreign Origin/Host and never injects credentials or relaxes backend CORS. Four transport tests, build, analyze and direct/proxy actual login probes PASS; user manually accepted the preview. [Browser evidence/limits](../docs/planning/SYNCARE-BROWSER-TESTING.md). This is browser testing support, not native/deployed acceptance. M06 is now USER_APPROVED and M07 alone authorized (DL-015); older milestone notes below retain historical states.

## Current local M06 behavior, 2026-10-26

Homecare -> Buka booking saya opens own bounded booking history and detail with actual status, distinct preferred/confirmed WIB times, assigned nurse, completion evidence and patient-safe timeline. The committed request receipt also links to its detail. Own Requested/Under Review can be cancelled with a required reason; Scheduled/terminal cannot. Unknown delivery retains the original UUID/version/reason; conflict409 rereads without claiming success. Late GET cannot overwrite a newer receipt, and logout/denied access clears private state. Draft/intent remains authenticated-session memory, not a durable offline outbox.

Flutter186 full tests plus2 actual Dio/provider/captured-widget integration PASS; analyze/format/lock checks PASS. [M06 verification](../docs/planning/SYNCARE-M06-VERIFICATION.md). Native device/AVD unavailable; no native plugin/secure-storage or deployed proof. Existing theme/dependencies/clinical ownership unchanged. M01-M05 accepted, M06 awaits ACC, M07+ not authorized.

## Historical M05 behavior, 2026-10-26

Ringkasan -> Ajukan homecare opens the actual active catalog and own request form. DKI Jakarta address/administrative fields and preferred date/time are required; WIB is explicit, note optional. Only a committed backend receipt shows Pengajuan tersimpan/Diajukan. Uncertain delivery retains original input/UUID for Periksa pengajuan yang sama; Buat pengajuan baru explicitly resets intent. Preference is never a confirmed visit. Protected routing/logout isolates account state; full booking history/status/cancel remains M06. In-memory drafts are not a durable offline outbox.

Final evidence: Flutter176 tests plus2 actual HTTP/captured-receipt integration, analyze/format/lock checks PASS; [M05 verification](../docs/planning/SYNCARE-M05-VERIFICATION.md). No native device/AVD was available. Theme/dependencies unchanged; clinical F1-F5 remain behind Bun. M05 awaits ACC.

Mobile client (Android + iOS) for SynCare, a risk-adaptive post-discharge follow-up demo for CHF
patients. M02 replaces entry role selection with backend-validated account login. Patient mobile is the primary client; legacy nurse components remain for migration:

- **Patient:** check in, read the approved plan, ask grounded questions.
- **Nurse / clinician:** score a discharge summary, draft a plan, and run the human-approval desk.

Langflow makes every clinical decision behind `SynCare-be`. This client renders what the API returns;
it never scores, tiers, flags, drafts, or approves on its own.

## Current local M04 behavior, 2026-10-25

Ringkasan offers Tulis check-in and Buka riwayat laporan. The guarded compose screen uses committed API-M1 receipts, preserving the same request key on uncertain delivery and preventing double submit. Tersimpan and analytic processing are distinct. Explicit Mulai laporan baru creates a new intent. Bounded GET status reads never rerun F2. Own lazy history/detail uses API-M2 with typed empty/error/stale-refresh and permission clearing.

F2 routine, plan-review and urgent outcomes remain separate from confirmed F1. Known urgent output is visible above evidence and on overview, even with LOW F1 or unavailable alert/guidance persistence. Emergency contacts are sourced information only; the demo has no call action. Original unmounted check-in widgets remain in `legacy_checkin_screen.dart` with explicit legacy regression tests; normal routing uses the persisted M04 screen. See [M04 verification](../docs/planning/SYNCARE-M04-VERIFICATION.md). Native runtime/secure storage/APK and deployment remain unverified because no device/AVD is available.

## M03 overview baseline

The account screen opens Ringkasan perawatan saya and the guarded `/patient/home` / `/patient/profile` routes. Overview uses the verified account's patient link and real Bun API-P5, showing confirmed risk, original disclaimer/source provenance and a read-only profile. Proposed F1 is never substituted for confirmation; source changes show mandatory reassessment. Missing future sources are labelled unavailable. The first patient navigation destination is Ringkasan; legacy check-in source is retained for M04.

Verification: 152 Flutter regression tests, 2 separate actual-HTTP/captured-snapshot integration cases, static analysis and narrow large-text router checks PASS. Android SDK is present, but no connected device or configured AVD exists; native runtime/secure storage/APK are NOT VERIFIED. See [M03 verification](../docs/planning/SYNCARE-M03-VERIFICATION.md). M03 awaits user ACC before M04.

## Account boundary inherited from M02

The app starts at login, validates restored sessions with Bun and opens an account screen using the server's identity/patient link. Logout clears the local session/provider generation and revokes the current server session; offline revocation is labelled unconfirmed. Absolute lifetime is 24 hours without automatic extension. Credentials use secure storage key `syncare_session_token`; compile-time `API_TOKEN` and old demo-token storage are not fallbacks.

Private routes reject anonymous/wrong-role deep links. Account switches cancel old HTTP/SSE providers, clear F1/draft caches and ignore late responses. A patient's ID comes from the verified account link; demo preferences cannot grant access. Permission denial is distinct from server read-only mode.

The clinical screens/screenshots below document retained components. Raw F1/F2/F3/F4 calls and job streams are denied publicly until their domain milestones establish provenance. Scoped plan/F5 calls remain; no native mobile runtime or new clinical end-to-end claim follows from the widget tests. See [M02 verification](../docs/planning/SYNCARE-M02-VERIFICATION.md) and the [private account procedure](../docs/planning/demo-account-procedure.md).

<p align="center">
  <img src="docs/screenshots/01-role-picker.webp" width="270" alt="Role picker">
  <img src="docs/screenshots/03-checkin-escalation.webp" width="270" alt="Patient check-in escalation">
</p>

## Stack

| Concern | Choice |
|---|---|
| UI | Flutter 3.44 / Dart 3.12, Material 3 |
| State | `flutter_riverpod` 2.6 |
| Routing | `go_router` 17 |
| REST | `dio` with a bearer interceptor |
| SSE | `http.Client().send()` + a chunk-safe frame parser (never `EventSource`) |
| Secret | backend account session in `flutter_secure_storage`; no shared compile-time credential |

## Screens

### Patient

**Check-in** (`POST /api/v1/checkins`) renders F2 verbatim. A red-flag response
(`action: escalate_immediately`) produces an unmistakable red card with the server's reason,
above everything else.

<p align="center"><img src="docs/screenshots/03-checkin-escalation.webp" width="300" alt="Escalation"></p>

**My plan** (`GET /api/v1/plans/:patientId`) shows the approved plan, risk badge, care intensity,
follow-up date/hotline extracted from the ServiceRequest sentence, and the approval timestamp.
A `404` renders the "belum ada rencana" empty state, not an error. `plan_json.status` stays
`DRAFT pending human approval` by design: approval is the row existing, never that string.

<p align="center">
  <img src="docs/screenshots/04-patient-plan.webp" width="300" alt="Approved plan">
  <img src="docs/screenshots/06-patient-plan-satusehat.webp" width="300" alt="SATUSEHAT detail">
</p>

**Ask** (`POST /api/v1/answers`) shows the answer verbatim with its provenance chip. Refusals are
rendered as returned, not reworded.

<p align="center"><img src="docs/screenshots/08-patient-ask-answer.webp" width="300" alt="Grounded answer"></p>

### Nurse

**Intake** (`POST /api/v1/discharge`) renders tier, score, label, rationale, every risk factor
(value / threshold / points / met), missing fields, and the `not_clinically_validated` disclaimer.

<p align="center"><img src="docs/screenshots/11-nurse-intake-factors.webp" width="300" alt="Risk factors"></p>

**Draft** (`POST /api/v1/plans/draft`) requires an explicit follow-up date and hotline; F3 refuses
to invent either. The result is labelled as a draft with the server's status.

<p align="center"><img src="docs/screenshots/14-nurse-draft-result.webp" width="300" alt="Draft plan"></p>

**Approval desk** starts an F4 background job (`POST /api/v1/reviews`), consumes the SSE feed, and
renders the human gate with all four decisions. On resume it reopens the stream, so the terminal
output appears without a manual refresh. Timeout and stream failures show a retry path, not a
fabricated result.

<p align="center">
  <img src="docs/screenshots/18-approval-gate.webp" width="260" alt="Gate">
  <img src="docs/screenshots/19-approval-actions.webp" width="260" alt="Decisions">
  <img src="docs/screenshots/20-approval-result.webp" width="260" alt="Approved">
</p>

**Patients & audit** (`GET /api/v1/plans`) is read-only: approved rows plus the audit trail.

<p align="center"><img src="docs/screenshots/21-nurse-patients.webp" width="300" alt="Patients and audit"></p>

## Running

Prerequisites: Flutter stable (3.44+), Android SDK with a phone emulator or an iOS simulator, and a
running SynCare backend (`http://127.0.0.1:8080` locally).

```bash
flutter pub get
flutter doctor -v
flutter analyze
flutter test
```

Android emulator (host loopback alias, no CORS needed):

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE=http://10.0.2.2:8080
```

iOS simulator: `--dart-define=API_BASE=http://localhost:8080`.

| Define | Default | Purpose |
|---|---|---|
| `API_BASE` | `http://10.0.2.2:8080` | Backend base URL |
| `PATIENT_ID` | `demo-1` | Legacy demo-component default only, never a logged-in patient's identity |
| `REVIEWER` | `nurse-1` | Legacy approval-component default; cannot authorize a public approval |

Log in using a privately provisioned account. A protected request returning 401 closes the current generation and returns to login. The retained role-picker/token-dialog widgets are not an authentication path in the current router. Never pass a shared API/Langflow token into a build.

A local browser preview is supported through the loopback relay described above; public web deployment remains unverified. A physical native device needs reachable, protected transport; CORS applies to browsers and does not substitute for native transport or authorization. The current HTTP exception remains limited to the documented development hosts.

## API integration notes (verified against the live backend)

The live system overrides `FRONTEND-CONTRACT.md` where they differ. The client implements:

- **F4 start** takes the **complete F3 output JSON string** as `draft`; sending only `plan_text`
  fails the flow guard.
- **F4 resume to `SynCare-be` is flat**: `{request_id, action_id, actor, reviewer_note}`. The
  backend nests the decision for Langflow. `request_id` is always sent. Omitting it returns `200`
  while leaving the job suspended.
- `GET /api/v1/plans/:patientId` returns `{patientId, plans: [...]}`; the client takes the first
  filtered row. `404` is an empty state.
- SSE frames are Langflow v2 frames: `data: {"event": "...", "data": {...}}` with no `event:` line.
  The parser also accepts standard `event:` + `data:` frames.
- Langflow closes the job stream when it pauses at the gate; after resume the desk reconnects to the
  same job id to receive `output`/`end`. Replayed gate frames are ignored once a decision was sent.
- F5 output is plain text, optionally ending with a `[...]` provenance block; it is not JSON.

### Local review-database caveat

On this workstation Langflow writes approvals to `/home/frxskie/langflow/syncare-review.sqlite3`,
while `SynCare-be` reads `data/langflow/langflow/syncare-review.sqlite3`. Consequently a freshly
approved plan appears in the approval desk's live result but not in **Patients & audit**, and F5
answers can exist for a patient whose plan row is absent (and vice versa). This is a backend
runtime configuration issue, not client logic. Align `SYNCARE_REVIEW_DB` (backend) with the
`db_path` used by the F4/F5 flow nodes, then restart both services. The client continues to show
each endpoint's response unchanged in the meantime.

## Tests

`flutter analyze` is clean and `flutter test` passes 132 tests. Coverage includes:

- Dio bearer header, `401` / `503` mapping, F2's JSON-string body, the flat resume payload, and the
  filtered `plans/:id` wrapper;
- SSE parsing for both frame styles, chunk boundaries, and gate normalization;
- one widget test per screen (render, disclaimer, loading, empty, error) plus the escalation branch;
- approval-desk waiting/gate/resume/output/timeout/error states, including stream resubscription
  after resume.

Tests are hermetic: `DioAdapter` for HTTP, fake `SyncareApi` and `ReviewEventSource` for screens.
No test hits the live backend.

## Scope and safety

- Synthetic demo only; not clinically validated; no diagnosis, medication changes, or emergency
  advice. FHIR-shaped output is **not** a SATUSEHAT submission.
- No Langflow API key exists in the Flutter source, assets, or binary. The app calls only the
  backend.
- Tier, score, red flags, drafts, and approvals come from the API verbatim; the client adds no
  clinical logic and no fabricated fallbacks.
- `--dart-define` values are visible in process listings on a shared machine; use secure storage for
  anything beyond a local demo, and never commit a real token.
