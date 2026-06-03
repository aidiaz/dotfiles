---
name: vera-kiosk-e2e
description: >-
  Agentic E2E test of Vera's kiosk UI via Playwright MCP. Drives a full
  manufacturing part lifecycle through the browser -- pressing start through
  crating -- checking for errors, regressions, and correct stage progression
  at every step. Use when the user says "test the kiosk", "e2e test",
  "run kiosk test", "test the app", "verify kiosk flow", or invokes
  /vera-kiosk-e2e.
---

# Vera Kiosk E2E -- Agentic Browser Test

You are an agentic QA tester. You drive the Vera MES kiosk UI through
Playwright MCP tools, reading the page semantically (accessibility snapshots)
and interacting by intent, not by hardcoded selectors. If the UI changes,
you adapt.

## Prerequisites

- Playwright MCP tools must be available (browser_navigate, browser_snapshot,
  browser_click, browser_fill_form, browser_select_option, browser_take_screenshot).
- The target instance must be reachable (default: https://integral-destined-toucan.ngrok-free.app).
- Backend must have seed data: at least one active press with a loaded mold,
  active part types, and VENEER materials with SKUs.

## Quick-reference: environment

| Item | Value |
|------|-------|
| Base URL | `https://integral-destined-toucan.ngrok-free.app` (override with user input) |
| Login | username: `taller`, password: `8760` (override with user input) |
| Kiosk scanner URL pattern | `/kiosk/web/{STAGE_NAME}` |
| Pressing start (add) URL | `/process-records/web/add/{stage_id}?kiosk=true` |
| Terminate URL | `/process-records/web/terminate/{record_id}?kiosk=true` |
| Completion success URL | `/process-records/web/completion-success/{uid}` |
| Part status API | `/api/parts/lookup/{partial_uuid}` |

## Domain rules (learned from testing)

### Part status transitions

Only **QC** and **CRATING** can set terminal part statuses:
- `approved` -> part stays `active`, downstream stage created
- `approved_substandard` -> part stays `active`, downstream created (flagged)
- `reprocess_needed` -> part set to `on_hold`, redirect to reprocess selection
- `retained` -> part set to `on_hold`, CANCELLED downstream record created
- `rejected` -> part set to `scrapped`, no downstream

**Pressing and Trimming** do NOT set terminal statuses:
- `approved` -> part stays `active`, PENDING downstream created
- `unsure` -> identical to approved (PENDING downstream, part active)
- `rejected` -> part stays `active`, CANCELLED downstream created
  (rejection at these stages is supervisory, not terminal)

### Reprocess stage options

When reprocess_needed is selected, the reprocess selection page offers
different stages depending on the source:

| Source Stage | Reprocess Options |
|-------------|-------------------|
| QC | Sand Again, Press Frame Again |
| Crating | Sand Again, Press Frame Again, Paint Again |

Multi-select is supported (operator can check multiple stages).

### Reprocess flow behavior

After reprocess, the part walks forward through stages again. Stages that
were already completed may be **skipped** ("Part has already completed X").
The part eventually arrives back at QC (or Crating) via a redo of the
original record.

### Retained (unretain) flow

A retained part (on_hold) can be re-inspected by scanning it at QC again.
This creates a **new QC record** (not a redo of the old one). The CANCELLED
downstream records are reactivated to PENDING when approved.

### Photo uploads

Most stages require at least 1 photo upload. The submit button stays
disabled until the photo uploads successfully. Use `browser_file_upload`
with a test image from the project:
`/home/aidiaz/developer/vera/app/static/images/patterns/ellipse.png`

Trigger the file chooser by clicking the "Take / Upload Photo" label,
then use `browser_file_upload` to set the file. Wait 3-4 seconds for the
async upload to complete before checking the submit button state.

### Pressing form specifics

- Pressing is started via the add form, not the kiosk scanner
- To create a pressing with a part, pass `?part_id={uuid}&kiosk=true`
- The scanner requires an existing GENERATION record; the add form creates
  one if a part_id is provided
- After selecting Press + Part Type, finishing layer SKU fields appear
  dynamically. Type SKUs slowly (`slowly: true`) and Tab out to trigger
  validation. Known SKUs: `C-P-CINZA`, `C-P-NogalCatedral`
- A confirmation dialog appears on submit -- handle with `browser_handle_dialog`

### Verification methods

Always verify outcomes using three approaches:
1. **UI verification** -- check redirect URL (`?success=true`), alert messages
2. **API verification** -- GET `/api/parts/lookup/{partial_uuid}` to check
   `status`, `current_stage`, `crate_uid`, `package_uid`
3. **Cross-station scanning** -- scan the part at the next kiosk station to
   confirm downstream records exist or are blocked
4. **Server logs** -- `docker logs --tail N vera-web` for handler-level messages

## Core principles

1. **Read the page, don't assume.** Always take a `browser_snapshot` before
   interacting. The snapshot tells you what elements exist right now. Never
   guess element refs from a previous snapshot after a page navigation or
   form submission.

2. **Interact by intent.** Find the element whose accessible name or role
   matches what you need ("Start Process" button, "Press" select, barcode
   input). If the label changed, you still find it by role + context.

3. **Check for errors after every navigation.** After each page load or form
   submission, look for:
   - Alert/error banners in the snapshot (role=alert, class alert-danger, etc.)
   - Console errors (check console_messages if available)
   - Unexpected URL (e.g. still on the same page after submit = validation error)
   - HTTP error codes in page title or body

4. **Screenshot on failure.** If anything unexpected happens, take a screenshot
   before reporting the failure. This gives the user visual evidence.

5. **Report progress.** After each stage completes, print a one-line status.
   At the end, print a summary table.

## Test flow: full part lifecycle

The test walks a single part through the entire manufacturing pipeline via the
kiosk UI. The stages in order:

```
PRESSING (start) -> PRESSING (complete) -> TRIMMING -> SANDING -> FRAME_PRESSING -> QUALITY_CHECK -> PAINTING -> CRATING
```

After TRIMMING, the macropanel subdivides into child parts (typically 2 or 4
depending on mold). The test picks the **first child** and continues the
remaining stages with it.

### Phase 0: Login

1. Navigate to the base URL.
2. If redirected to `/login`, fill username + password and click Login.
3. Verify you land on the Home page (check heading or nav bar).
4. **PASS/FAIL:** Logged in successfully.

### Phase 1: PRESSING -- start a new record

1. Navigate to `/process-records/web/add/10?part_id={uuid}&kiosk=true`
   with a fresh UUID (generate one or use user-provided).
2. Take a snapshot to see available fields.
3. Fill the form:
   - **Part Type:** Select "Catalogue Products" first (determines slot count).
   - **Press:** Select an available press (determines mold + surface pattern).
   - **Pressing Duration:** Select available option (e.g. 75 min).
   - **Finishing Layers:** Type SKUs slowly, Tab out to trigger validation.
4. Click "Start Process", accept the confirmation dialog.
5. Verify redirect to pressing scanner with active record.
6. **PASS/FAIL:** Pressing record created.

### Phase 2: PRESSING -- complete the record

1. Click "Complete Process" link from the scanner or navigate to terminate URL.
2. Upload a photo via file input.
3. Fill all per-slot defect radio buttons to "No".
4. Select continuation_status = "approved".
5. Click "Complete Process".
6. Verify redirect to scanner.
7. **PASS/FAIL:** Pressing completed.

### Phase 3: TRIMMING -- scan + subdivide

1. Navigate to `/kiosk/web/TRIMMING`, scan the macropanel UUID.
2. Click "Complete Process" to go to terminate form.
3. Upload photo, fill macropanel fields (yes/no/no/no, horizontal lines=0).
4. Set per-slot continuation status (approved for happy path).
5. Submit. Find child UUIDs from server logs (`docker logs vera-web | grep "Created child Part"`).
6. **PASS/FAIL:** Trimming completed, children created.

### Phases 4-8: SANDING through CRATING

For each stage, the pattern is:
1. Navigate to kiosk scanner, scan child UUID.
2. If add form appears (FRAME_PRESSING), upload photo and submit start.
3. On terminate form, upload photo, fill fields, select approved, submit.
4. For PAINTING: assign to package, then bulk-complete by scanning package barcode.
5. For CRATING: fill defect ratings, select approved, assign crate, upload photo.

## Sad path scenarios

### Part status outcomes (S1-S8)

Test each quality outcome at QC and Crating. For each, verify:
- Part status via API (`/api/parts/lookup/{partial_uuid}`)
- Whether downstream stage was created (scan at next station)
- Reprocess selection page if applicable

### Reprocess combinations (S4/S9 extended)

Test ALL reprocess stage selections at both QC and Crating:

| ID | Source | Selection | Verify |
|----|--------|-----------|--------|
| S4a | QC | Sand Again | New SANDING record, no PAINTING |
| S4b | QC | Press Frame Again | New FRAME_PRESSING record |
| S4c | QC | Sand + Frame (multi) | Both records created |
| S9a | Crating | Paint Again | New PAINTING record, no crate |
| S9b | Crating | Sand Again | New SANDING record |
| S9c | Crating | Press Frame Again | New FRAME_PRESSING record |
| S9d | Crating | Paint + Sand (multi) | Both records created |
| S9e | Crating | All three (multi) | All three records created |

For each: verify part status = on_hold, verify selected stage(s) have
new PENDING records, verify stages NOT selected don't have new records.

### Retained + unretain flow (S6 extended)

1. QC retained -> part on_hold, CANCELLED PAINTING
2. Scan at QC again -> new QC record (not redo)
3. Approve -> PAINTING reactivated to PENDING
4. Verify part status transitions correctly

### Redo flows (S10-S11)

Scan a part with completed QC/Crating record at the same station.
Verify redo confirmation page, previous data shown, form reloads.

## After the walk

Print a summary table with PASS/FAIL/FINDING per scenario, then a
part status matrix showing actual vs expected status for each outcome.

For any FAIL or FINDING, include:
- What was expected vs. what happened
- The URL at the time of failure
- Part status from API
- Any console errors or server log excerpts

## Error handling

- **Stale record recovery:** If the scan redirects to `/kiosk/web/recover/{id}`,
  take a snapshot and click "Abandon" to clear the stale record, then re-scan.
- **Validation errors:** If the form re-renders with error messages instead of
  redirecting, capture the error text and report it.
- **Unexpected redirects:** If a navigation lands on an unexpected page, take
  a screenshot and snapshot, report the URL and visible content.
- **Disabled submit button:** Take a snapshot to identify which required field
  is missing or which validation failed. Try to fill it. If it's photo-gated,
  upload a test image.

## Adapting to UI changes

This skill describes **what to do**, not **which element ref to click**. Each
time you interact with the page:
1. Take a fresh snapshot.
2. Find elements by role + accessible name (e.g. "button named 'Start Process'",
   "textbox named 'Barcode'", "radio named 'approved'").
3. If a label changed, reason about which element matches the intent.
4. If the page structure changed (new steps, removed fields), adapt and note
   the deviation in your report.

## Optional: seed backend state first

If the user wants a fully seeded backend before the kiosk test, suggest running:
```bash
ENVIRONMENT=development venv/bin/python scripts/seed_to_stage.py
```
This creates parts at each stage that the kiosk test can then scan.

## User overrides

The user may specify:
- A different base URL (e.g. `localhost:8000`)
- Different credentials
- A specific stage to test (skip earlier stages)
- A specific part UUID to scan (skip pressing start)
- Whether to test the "reprocess" or "redo" flows
- Specific reprocess combinations to test

Adapt the test accordingly.
