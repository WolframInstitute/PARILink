#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$project_root/.deps"

fetch() {
  local name="$1" url="$2" revision="$3" target
  target="$project_root/.deps/$name"
  if [[ -d "$target/.git" ]]; then
    if [[ "$(git -C "$target" rev-parse HEAD)" != "$revision" ]] || [[ -n "$(git -C "$target" status --porcelain)" ]]; then
      printf '%s\n' "$target differs from the pinned revision; move it aside before fetching." >&2
      exit 1
    fi
    return
  fi
  git init --quiet "$target"
  git -C "$target" remote add origin "$url"
  git -C "$target" fetch --quiet --depth 1 origin "$revision"
  git -C "$target" checkout --quiet --detach FETCH_HEAD
}

fetch PacletPage https://github.com/WolframInstitute/PacletPage.git d5e08231b5c918cfd0773ebe7c8034b021574ba1
fetch MarkdownToNotebook https://github.com/WolframInstitute/MarkdownToNotebook.git d08fccf2b6640213503d94557b624641cf40d825
fetch WolframParser https://github.com/sw1sh/WolframParser.git bbe93ce11796973fbbf7150e61ed05021ef18520
