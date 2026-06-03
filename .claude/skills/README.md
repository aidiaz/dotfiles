# Claude skills — install flow

Source of truth for the skills **you author**. Runtime locations are symlinks back
into this directory, so the structure lives in one version-controlled place and is
reproducible on any machine via `setup.sh`.

> General-purpose skills installed by a skill manager live separately under
> `~/.agents/skills/` (tracked by its own `.skill-lock.json`) and are symlinked into
> `~/.claude/skills/`. This repo does **not** manage those — leave them alone. The
> installer's `each` mode coexists with them.

## Layout

    global/            -> fanned into ~/.claude/skills/<skill>   (loads in EVERY project)
    projects/<name>/   -> ~/developer/<name>/.claude/skills      (loads only in that repo)

`<name>` matches the repo directory under `~/developer/`.

## Install / re-sync

    ~/dotfiles/.claude/skills/install.sh

Idempotent — re-run any time. An already-correct symlink is left alone; a real
directory found at a target is backed up to `<target>.bak.<timestamp>` first.
`setup.sh` calls it automatically.

## Adding a skill

- Global (you author it, reusable anywhere): create `global/<skill>/SKILL.md`, then
  run `install.sh`. Third-party global skills are installed via the skill manager
  into `~/.agents/skills`, not here.
- Project-specific: create `projects/<name>/<skill>/SKILL.md`. If `<name>` is new,
  add a row to `skills.map`. Then run `install.sh`.

Decide scope by reach: a skill's `description` frontmatter loads into context for
every session of every project it's installed in, so keep project-specific skills
out of global.

## Mapping

`skills.map` rows are `<scope>  <target under $HOME>  <mode>`:
- `each` — fan each child skill into the target (target shared with other sources).
- `dir`  — the target itself becomes a symlink to the scope dir.

## Large assets

Big binary skill assets (e.g. `grain_references/` reference photos, ~13M each) are
gitignored and kept on disk only — see `.gitignore`. They won't sync to a fresh
clone; copy them out-of-band or switch to git-lfs if you need portability.
