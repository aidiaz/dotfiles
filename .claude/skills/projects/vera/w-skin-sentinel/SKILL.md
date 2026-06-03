---
name: w-skin-sentinel
description: Inspects a w-skin manufacturing run via the local gemma4:31b vision model (called through vllm_client.py). Use when the user asks to "inspect this run", "analyze w-skin", "check these layers", or points at a folder of sequential layer photos from the additive wood+glue line. Produces a lean markdown table plus a JSON log flagging wood features (knots, tears, splits, patching), piece fit, grain orientation, and glue-line quality across layers 1–4, plus aesthetic review of layer 5.
---

# w-skin Sentinel

Delegates vision to local gemma4:31b via `vllm_client.py`; Claude orchestrates
and summarizes.

## Process at a glance

w-skin is built top-down in 5 layers, viewed from above:

- **Layers 1–4** — wood pieces placed, then ~90 glue lines along the image's
  **long dimension**, then the next layer.
- **Layer 5** — wood only, customer-facing. **No glue over it.**

Standard product: 2 pieces per layer (up to 14). Layer 5 piece count may
differ.

## Input

A folder or path list of **9–10 top-view photos**, filename-sorted ascending
(higher index = later in the run). The **first photo may be missing** — infer
phase/layer from content, don't hard-map index to layer.

Typical rhythm: `place1, glue1, place2, glue2, place3, glue3, place4, glue4, finish5`.

## How to run

```bash
cd /home/aidiaz/developer/ai-playground && \
python vllm_client.py <folder> "inspect this w-skin run" --batch --log
```

- `--batch` enables cross-layer reasoning (needed for grain consistency).
- `--log` writes `logs/inspection_<timestamp>.json`.
- Drop `--batch` if the user shared only one photo.

After the client returns, **read the newest `logs/inspection_*.json`** and
build the summary table from it. Don't re-run inference to make the table.

## What the model should look for

Give the client a prompt that covers these (adapt wording, don't recite):

- **Wood features** per piece: knots, tears, splits, **patching** (highlight,
  not a defect).
- **Grain orientation** per piece. Values: `long`, `short`, `unclear`.
  Never use `longitudinal`, `vertical`, `horizontal`, `diagonal`,
  `transverse`, or degrees — those conflate axes.

  **How to read grain from the image (do this, don't guess):**
  1. Find a knot — a darker brown/black patch in the wood.
  2. Look at how the knot's dark color streaks/bleeds outward. A knot
     is rarely a clean circle; its dark halo elongates along the fiber
     direction, like a flame stain.
  3. Compare the streak direction to the image edges:
     - Streak parallel to the image's **longer** edges → `long`.
     - Streak parallel to the image's **shorter** edges → `short`.
     - No knot visible, or halo is circular / ambiguous → `unclear`.
  4. Cross-check with faint surface lines (rays/pores) — they should
     run in the same direction as the knot streak. If they disagree,
     downgrade to `unclear`.

  Operator terminology translation: "longitudinal" → `long`,
  "transversal" → `short`. Always emit the enum value, never the
  operator's word.

  **Calibration assets** — `assets/grain_references/` contains
  confirmed examples of each class. Before calling a photo, compare
  it to both references:
  - `long_example_1.png`, `long_example_2.png` — grain=`long`.
  - `short_example_1.png`, `short_example_2.png` — grain=`short`.

  These are visual anchors for the *look* of each class. Do NOT
  infer that any specific layer number implies a specific
  orientation — layer→grain mapping is not fixed and must always be
  read from the image.

  Flag inconsistency within one layer.
- **Piece fit** per layer: `good_fit`, `separated`, `overlapping` —
  qualitative only.
- **Glue** (only on `glue` phase photos, layers 1–4): rough line count, flag
  `discontinuity` and `pooling`. Skip on placement shots and layer 5.
- **Layer 5 aesthetic**: no holes, uniform color, no scratches. Higher bar —
  "it must be beautiful."

## Verdict rubric

- `pass` — ship it.
- `review` — human check before shipping (minor split, one separated joint,
  thin glue spot).
- `fail` — heavy pooling, missing glue lines, gross misalignment, layer-5
  scratch/hole.

Patching alone never lowers the verdict.

## Output

The JSON log already lands under `logs/` via `--log`. Target shape for the
model response:

```json
{
  "run_id": "folder name or timestamp",
  "total_images": 9,
  "per_image": [
    {
      "idx": 1,
      "name": "photo_01.jpg",
      "phase": "placement | glue | finishing",
      "layer_inferred": 1,
      "pieces": [
        {"id": 1, "grain": "long", "knots": 2, "tears": 0, "splits": 0, "patching": 0, "notes": ""}
      ],
      "piece_fit": "good_fit | separated | overlapping",
      "glue": {"applicable": false, "lines": null, "discontinuities": [], "pooling": []},
      "aesthetic_notes": "",
      "verdict": "pass | review | fail",
      "reason": ""
    }
  ],
  "overall": {
    "grain_consistency": "consistent | mixed | contradictory",
    "cumulative_defects": "short paragraph",
    "finishing_quality": "pass | review | fail",
    "verdict": "pass | review | fail",
    "actions": []
  }
}
```

Then print a lean table:

```
| #  | Phase      | Layer | Fit        | Glue     | Wood flags  | Verdict |
|----|------------|-------|------------|----------|-------------|---------|
| 1  | placement  | 1     | good_fit   | —        | 1 knot      | pass    |
| …  |            |       |            |          |             |         |
| ∑  | overall    | —     | —          | —        | 1 split     | review  |
```

Close with `Log: logs/<file>.json` and `Overall: <verdict>` — if not `pass`,
add one sentence on why and the recommended action.

## Edge cases

- **Single photo** — drop `--batch`; overall = per-image.
- **Log missing** — parse the streamed stdout instead and note the miss.
- **Placement shot** — no glue findings.
