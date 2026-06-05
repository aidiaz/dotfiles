---
name: narrate-win
description: Translate a BIG win you point to (a shipped feature/integration/tool — NOT routine commits) into a SMALL, plain-language message for the team channel, in the team's dry house voice, bilingual (ES+EN), framed as what it UNLOCKS (margin, the round, key clients, certifications, QC). YOU-DIRECTED and YOU-EXECUTED: you run /narrate-win and say what the win is; it narrates THAT, not every commit. Only use when you ask.
---

# Narrate a Win

Turn a real shipped win into a small, human, shareable message — making load-bearing infra work (invisible when it just works) visible to the team.

## You direct it — you name the win
**For big wins worth announcing, not every commit.** You run the skill and **tell it what the win is**. Work from that:
1. **You described the win** → narrate **that**. Use commits/repo context only to get details right.
2. **You point at recent work but aren't specific** → you may pull commits (`git log` / the commit channel) to **surface a few candidate big items** and ask which to narrate — **don't pick for the user, don't narrate routine commits.**
3. **No direction given** → just ask: *"What's the win?"* Never auto-summarize commit activity.
> One big win at a time, on the user's call. Routine/trivial work is not a win — skip it.

## Write the message — rules
- **Default small** — 2–4 sentences, one idea, paste-ready. Longer only when it's a thing people must *use* (let the content set the length).
- **Common-people language.** No jargon. If a technical term is unavoidable, explain it plainly.
- **Lead with the benefit / what it unlocks** — "what I built" → "what the company can now do."
- **Tie to what the company values** (pick what fits): contribution margin / self-financing, the funding round, key clients, certifications/traceability, QC quality grades, throughput, fewer errors/scrap, the data moat.
- **Tone & voice:** **dry, understated, witty** — the house voice (see Voice). Plain over peppy; no hype.
- **Bilingual:** always produce BOTH Spanish and English (part of the team is English-only) — ES first, then EN, equivalent (not word-for-word), both equally dry & accurate. Optionally a one-liner variant in both.
- **Credit the teammates who worked on it**, briefly, by name — one short line, not a gush. *(You supply the names when you run it.)*
- **Never invent or overstate.** State precisely what's automated vs. what still needs manual work / known limits (e.g. "auto-discount per order" ≠ "inventory always live" — losses are still adjusted by hand). The team prizes precision — **understate before you overstate.** If unsure of the real impact, ask.

## Voice — the house register
Dry, understated, a little witty — **not cheesy or corporate.** Match it:
- **Plain & factual first.** Say what changed in plain words and stop; let the significance land on its own. No "¡Team! 🎉", no exclamation spam.
- **Humble & collaborative:** "creo que…", "nosotros / lo sacamos con…" — propose, don't decree.
- **Chilean-casual & warm:** "quedó andando", "en cristiano", "sin tocar nada a mano"; relaxed, never stiff.
- **Deadpan wit** welcome; a touch of irony is fine.
- **Frame work as what it ENABLES, stated plainly** — "ahora tenemos el costo real por orden", not "una base enorme para la ronda".
- **Emoji: rare** — at most a single, semi-ironic 📈 at the end; **often zero**. No 🎉/🙌/🔥 hype, no "¡Team!" openers. English stays just as dry.

## Capture the *sense*, not a format (most important)
Sound right in **spirit**, not by filling a template:
- A **humble, precise engineer** sharing something useful — never showing off.
- **Plain and honest** — caveats included; never overclaim.
- **Dry, a touch witty**, no hype; minimal or no emoji.
- **Grounded** — a concrete example makes it real.
- **Why it matters, softly** — "la idea es que esto nos ayude a…", not "GAME CHANGER".
- **Collaborative & open** — credit who helped, leave the door open ("si ven algo raro, escríbannos y lo vamos iterando").
- Warm, human, casual; never corporate/stiff.

**Let the shape follow the content** — don't force a structure. A quick win = a sentence or two (+ maybe a deadpan 📈). Something people will actually *use* runs longer on its own terms (what it is, how to get in, an example, "tell us what's off"). A full tool launch is one reference of that fuller shape — **not a required format.**

## Translation examples (técnico → narrado)
- *fabrication-to-work-order traceability* → "Ya podemos seguir cada fabricación hasta su orden de trabajo: sabemos qué costó y qué rindió cada pieza. Es la base para saber si la operación se autofinancia. 📈"
- *auto-QC cabin assembled* → "La cabina de QC automático ya está armada y lista para correr. Primer paso para que la calidad que mandamos al cliente la respalde la IA, no solo el ojo."
- *MES+ERP integration (reservation + real-time MES discount + on-the-fly order↔production matching)* → "Quedó andando la integración MES + ERP. Dos cosas: vemos inventario en dos tiempos — lo reservado por las órdenes a futuro y lo que el MES confirma y descuenta en tiempo real al fabricar; y el calce orden↔producción es automático — el operador fabrica nomás y el sistema engancha la pieza a su orden (primero a las prioritarias, si no a cualquiera que le calce). Las mermas se ajustan aparte. 📈"
- *(EN — same dry register)* → "MES + ERP integration is live. Two things: inventory now shows two horizons — what work orders reserve ahead of time, and what the MES confirms and discounts in real time as we fabricate; and order↔production matching is automatic — operators just fabricate and the system links each piece to its order (priority orders first, otherwise any match). Loss adjustments are still done separately. 📈"

## After writing
Show the message(s). Offer to adjust tone/length. **The user posts it — never auto-post.**

## Source: pulling your own recent work (optional)
Prefer local `git log` for current commits. A Discord archive (discrawl MCP at `http://mcp:9000/mcp/`, tool `query_sql`, arg `sql`; `search_messages` is broken) is a snapshot fallback.

The commit channel is a GitHub webhook — commit/PR text lives in the embed `raw_json`, not `content` (which is empty). Extract with `json_extract(raw_json,'$.embeds[0].description')` (and `…fields[*].value`, `…url`), and filter to your own commits with `raw_json LIKE '%<your-github-username>%'`. The daily-update channel uses plain `content`, filtered by your Discord `user_id`. *(Fill in your own username, user_id, channel names, and repos.)*
