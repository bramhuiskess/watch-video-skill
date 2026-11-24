#!/usr/bin/env bash
# Removes everything install.sh added. Only deletes skill folders this project created.
set -euo pipefail

HOME_DIR="${WATCH_VIDEO_HOME:-$HOME/.local/share/watch-video}"

for dir in \
  "$HOME/.claude/skills/watch-video" \
  "$HOME/.codex/skills/watch-video" \
  "$HOME/.gemini/config/skills/watch-video" \
  "$HOME/.gemini/skills/watch-video"; do
  if [ -f "$dir/SKILL.md" ] && grep -q "installed by watch-video-skill" "$dir/SKILL.md"; then
    rm -f "$dir/SKILL.md"
    if [ -f "$dir/SKILL.md.bak" ]; then
      mv "$dir/SKILL.md.bak" "$dir/SKILL.md"
      echo "restored your previous skill in $dir"
    else
      rmdir "$dir" 2>/dev/null || true
      echo "removed $dir"
    fi
  fi
done

if [ -f "$HOME_DIR/watch.py" ]; then
  rm -rf "$HOME_DIR"
  echo "removed $HOME_DIR"
fi

echo ""
echo "Left in place (shared with other tools, delete by hand if you want):"
echo "  ~/.cache/huggingface/hub/models--Systran--faster-whisper-base"
echo "  ~/.cache/huggingface/hub/models--mlx-community--whisper-base-mlx"
echo "  any ./.watch/ folders in projects where you watched videos"
