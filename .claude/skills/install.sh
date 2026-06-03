#!/usr/bin/env bash
#
# Claude skills installer.
#
# Symlinks the skills you author into their runtime locations so the whole
# folder structure lives in one version-controlled place and is reproducible
# on any machine.
#
#   Source of truth : ~/dotfiles/.claude/skills/{global,projects/<name>}
#   Mapping         : skills.map  (scope  target  mode)
#   Idempotent      : safe to re-run. An already-correct symlink is left alone;
#                     a real dir/file at a target is backed up first.
#
# Modes:
#   dir   The target itself becomes a symlink to the scope dir (whole-dir mount).
#         Use for a project repo whose .claude/skills is wholly ours.
#   each  Every child of the scope dir is symlinked individually into target/.
#         Use for ~/.claude/skills, shared with tool-managed skills that are
#         symlinked in from ~/.agents/skills -- those are left untouched.
#
set -euo pipefail

skills_dir="${HOME}/dotfiles/.claude/skills"
map="${skills_dir}/skills.map"

link_one() {  # link_one <src> <dst>
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    if [ "$(readlink -- "$dst")" = "$src" ]; then
      printf 'ok     %s\n' "$dst"
      return
    fi
    rm -- "$dst"
  elif [ -e "$dst" ]; then
    local bak="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$dst" "$bak"
    printf 'backup %s -> %s\n' "$dst" "$bak"
  fi
  mkdir -p -- "$(dirname -- "$dst")"
  ln -s -- "$src" "$dst"
  printf 'link   %s -> %s\n' "$dst" "$src"
}

while read -r scope target mode _; do
  case "$scope" in
    '' | \#*) continue ;;
  esac
  [ -z "${target:-}" ] && continue

  src="${skills_dir}/${scope}"
  dst="${HOME}/${target}"

  if [ ! -d "$src" ]; then
    printf 'skip   %s (no source dir yet)\n' "$scope"
    continue
  fi

  case "${mode:-dir}" in
    dir)
      link_one "$src" "$dst"
      ;;
    each)
      mkdir -p -- "$dst"
      for child in "$src"/*/; do
        [ -d "$child" ] || continue
        link_one "${child%/}" "${dst}/$(basename -- "$child")"
      done
      ;;
    *)
      printf 'skip   %s (unknown mode: %s)\n' "$scope" "$mode"
      ;;
  esac
done < "$map"
