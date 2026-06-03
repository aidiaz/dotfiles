---
name: w-skin-sentinel-direct
description: Inspects a w-skin manufacturing run directly from top-view photos using Claude's own vision — no external model, no client. Use when the user asks to "inspect this run", "analyze w-skin", "check these layers", or points at a folder of sequential layer photos from the additive wood+glue line. Produces a lean markdown table plus a JSON log flagging wood features (knots, tears, splits, patching), piece fit, grain orientation, and glue-line quality across layers 1–4, plus aesthetic review of layer 5.
---

# w-skin Sentinel (direct)

Claude reads the photos with its own vision and writes the report. No
external model calls.

## Process at a glance

w-skin is built top-down in 5 layers, viewed from above:

- **Layers 1–4** — wood pieces placed, then glue lines along the image's
  **long dimension**, then the next layer.
- **Layer 5** — wood only, customer-facing. **No glue over it.**

Standard product: 2 pieces per layer (up to 14). Layer 5 piece count may
differ.

## Input

A folder or path list of **9–10 top-view photos**, filename-sorted ascending
(higher index = later in the run). The **first photo may be missing**, so
infer phase/layer from what's visible rather than assuming index 1 = layer 1.

Typical rhythm: `place1, glue1, place2, glue2, place3, glue3, place4, glue4, finish5`.

## What to inspect

Read all photos in one pass. For each photo:

- **Phase** — `placement`, `glue`, or `finishing`.
- **Wood features** per piece, qualitative only:
  - `knots`: `none | few | several | many` — do NOT emit an integer count.
    Counting dense features on top-view photos is unreliable; commit to a
    bucket instead.
  - `tears`, `splits`: `true | false` plus a short note on where.
  - `patching`: `true | false` (highlight, not a defect).
- **Grain orientation** per piece — describe the grain flow in detail. Use `LONGITUDINAL` for grain aligned with the long dimension of the image (side-to-side) and `TRANSVERSAL` for grain aligned with the short dimension (top-to-bottom). Use knot color streaks as the cue (the long axis of a knot's color halo points along the grain). Note how the knot color propagates through the wood to confirm grain direction. Flag inconsistency within a single layer.
- **Piece fit** per layer — `good_fit`, `separated`, `overlapping`
  (qualitative; don't claim measurements).
- **Glue** (only on `glue` phase photos, layers 1–4): report `coverage`
  as one of exactly `absolute | partial | none`:
  - `absolute` — glue is visible across the entire placed surface with
    no uncovered gaps.
  - `partial`  — glue is present but clearly misses portions of the
    surface.
  - `none`     — no glue visible on the layer.
  Also flag `pooling` (true/false) and any visible discontinuities by
  filename. Do NOT report a numeric line count — line counts are not
  reliably resolvable from these photos. Skip the glue section
  entirely for placement shots and for layer 5.
- **Layer 5 aesthetic** — no holes, uniform color, no scratches. Hold to a
  higher bar: "it must be beautiful."

## Verdict rubric

- `pass` — ship it.
- `review` — human check before shipping (minor split, one separated joint,
  thin glue spot).
- `fail` — heavy pooling, missing glue lines, gross misalignment, layer-5
  scratch/hole, or similar blocker.

Patching alone never lowers the verdict.

## Output

Save a JSON log to `logs/inspection_<YYYYMMDD_HHMMSS>.json`:

```json
{
  "run_id": "folder name or timestamp",
  "total_images": 9,
  "per_image": [
    {
      "idx": 1,
      "name": "photo_01.jpg",
      "phase": "placement",
      "layer_inferred": 1,
      "pieces": [
        {"id": 1, "grain": "LONGITUDINAL (with description)", "knots": "few", "tears": false, "splits": false, "patching": false, "notes": ""}
      ],
      "piece_fit": "good_fit",
      "glue": {"applicable": false, "coverage": null, "pooling": false, "discontinuities": [], "visible_in_photos": []},
      "aesthetic_notes": "",
      "verdict": "pass",
      "reason": ""
    }
  ],
  "overall": {
    "grain_consistency": "consistent | mixed | contradictory",
    "glue_coverage_by_layer": {
      "1": "absolute | partial | none",
      "2": "absolute | partial | none",
      "3": "absolute | partial | none",
      "4": "absolute | partial | none"
    },
    "cumulative_defects": "short paragraph",
    "finishing_quality": "pass | review | fail",
    "verdict": "pass | review | fail",
    "actions": []
  }
}
```

Then print a lean table to the user:

```
| #  | Phase      | Layer | Fit        | Glue coverage | Wood flags  | Grain        | Verdict |
|----|------------|-------|------------|---------------|-------------|--------------|---------|
| 1  | placement  | 1     | good_fit   | —             | few knots   | LONGITUDINAL | pass    |
| 2  | glue       | 1     | good_fit   | absolute      | few knots   | LONGITUDINAL | pass    |
| …  |            |       |            |               |             |              |         |
| ∑  | overall    | —     | —          | —             | —           | —            | pass    |
```

Close with `Log: logs/<file>.json` and `Overall: <verdict>` — if not `pass`,
add one sentence on why and the recommended action.

## Edge cases

- **Single photo** — skip cross-layer reasoning; overall = per-image.
- **Missing first photo** — note it, infer from what's there.
- **Placement shot with no glue visible** — don't invent glue findings.
