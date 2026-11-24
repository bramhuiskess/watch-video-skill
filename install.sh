#!/usr/bin/env bash
# Installs the watch-video skill for Claude Code, Codex, Antigravity and/or Gemini CLI.
#
#   ./install.sh                 install for every agent found on this machine
#   ./install.sh --codex --claude
#   ./install.sh --all           install for all four, found or not
#   ./install.sh --no-whisper    skip local Whisper (subtitles-only transcripts)
#
# What it touches, and nothing else:
#   ~/.local/share/watch-video/            the script + a Python venv for Whisper
#   ~/.claude/skills/watch-video/          (Claude Code)
#   ~/.codex/skills/watch-video/           (Codex)
#   ~/.gemini/config/skills/watch-video/   (Antigravity)
#   ~/.gemini/skills/watch-video/          (Gemini CLI)
#   ~/.cache/huggingface/                  Whisper "base" model download
# It never uses sudo and never installs system packages.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${WATCH_VIDEO_HOME:-$HOME/.local/share/watch-video}"
WANT=() ; WHISPER=1 ; MODELS=1

for arg in "$@"; do
  case "$arg" in
    --claude|--codex|--antigravity|--gemini) WANT+=("${arg#--}") ;;
    --all) WANT=(claude codex antigravity gemini) ;;
    --no-whisper) WHISPER=0 ;;
    --no-models) MODELS=0 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

say() { printf '%s\n' "$*"; }
ok()  { printf '  ok  %s\n' "$*"; }
bad() { printf '  !!  %s\n' "$*"; }

# ------------------------------------------------------------ requirements
say "Checking requirements"
missing=0
command -v python3 >/dev/null && ok "python3 $(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')" \
  || { bad "python3 not found"; missing=1; }
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null \
  || { bad "python 3.9 or newer is required"; missing=1; }
for t in ffmpeg ffprobe; do
  command -v "$t" >/dev/null && ok "$t" || { bad "$t not found"; missing=1; }
done
command -v yt-dlp >/dev/null && ok "yt-dlp (optional)" || say "  --  yt-dlp not installed (optional, only for URLs; local files work without it)"

if [ "$missing" = 1 ]; then
  say ""
  say "Install the missing tools first, then rerun this script:"
  say "  macOS:          brew install python ffmpeg"
  say "  Debian/Ubuntu:  sudo apt install python3 python3-venv ffmpeg"
  exit 1
fi

# ------------------------------------------------------------ script + venv
say ""
say "Installing script to $HOME_DIR"
mkdir -p "$HOME_DIR"
install -m 0755 "$HERE/watch.py" "$HOME_DIR/watch.py"
ok "watch.py"

if [ "$WHISPER" = 1 ]; then
  say "Setting up local Whisper (own venv, nothing installed globally)"
  [ -x "$HOME_DIR/.venv/bin/python" ] || python3 -m venv "$HOME_DIR/.venv"
  "$HOME_DIR/.venv/bin/pip" install -q --upgrade pip
  "$HOME_DIR/.venv/bin/pip" install -q -r "$HERE/requirements.txt"
  ok "faster-whisper (CPU)"
  if [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ]; then
    "$HOME_DIR/.venv/bin/pip" install -q -r "$HERE/requirements-mlx.txt" && ok "mlx-whisper (Apple Silicon GPU)" \
      || bad "mlx-whisper failed to install; faster-whisper will be used instead"
  fi
  if [ "$MODELS" = 1 ]; then
    say "Downloading the Whisper base model (about 150 MB, one time)"
    "$HOME_DIR/.venv/bin/python" - <<'PY' || bad "model download failed; it will retry on first use"
from faster_whisper import WhisperModel
WhisperModel("base", device="cpu", compute_type="int8")
try:
    from huggingface_hub import snapshot_download
    import platform
    if platform.system() == "Darwin" and platform.machine() == "arm64":
        snapshot_download("mlx-community/whisper-base-mlx")
except Exception:
    pass
PY
    ok "base model cached"
  fi
fi

# ------------------------------------------------------------ skills
if [ ${#WANT[@]} -eq 0 ]; then
  [ -d "$HOME/.claude" ] && WANT+=(claude)
  [ -d "$HOME/.codex" ] && WANT+=(codex)
  [ -d "$HOME/.gemini/antigravity" ] && WANT+=(antigravity)
  command -v gemini >/dev/null && WANT+=(gemini)
fi
if [ ${#WANT[@]} -eq 0 ]; then
  say ""
  say "No agents found. Rerun with --claude, --codex, --antigravity, --gemini or --all."
  exit 1
fi

say ""
say "Installing the skill"
for agent in "${WANT[@]}"; do
  case "$agent" in
    claude)      dir="$HOME/.claude/skills/watch-video";         tool='Open each image with the `Read` tool; it shows image files to you.' ;;
    codex)       dir="$HOME/.codex/skills/watch-video";          tool='Open each image with the `view_image` tool.' ;;
    antigravity) dir="$HOME/.gemini/config/skills/watch-video";  tool='Open each image with your file viewer (`view_file`); it shows image files to you.' ;;
    gemini)      dir="$HOME/.gemini/skills/watch-video";         tool='Open each image with the `read_file` tool; it shows image files to you.' ;;
  esac
  mkdir -p "$dir"
  if [ -f "$dir/SKILL.md" ] && ! grep -q "installed by watch-video-skill" "$dir/SKILL.md"; then
    mv "$dir/SKILL.md" "$dir/SKILL.md.bak"
    bad "$agent: existing SKILL.md was not ours, moved it to SKILL.md.bak"
  fi
  VIEW_TOOL="$tool" python3 - "$HERE/skill/SKILL.template.md" "$dir/SKILL.md" <<'PY'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read().replace("{{VIEW_TOOL}}", os.environ["VIEW_TOOL"])
head, sep, body = text.partition("\n---\n")
text = head + sep + "\n<!-- installed by watch-video-skill: https://github.com/bramhuiskess/watch-video-skill -->\n" + body
open(dst, "w").write(text)
PY
  ok "$agent -> $dir"
done

say ""
say "Done. Ask your agent to watch a video, for example:"
say '  "Watch ~/Desktop/recording.mov and tell me what happens"'
say "Restart the agent (or start a new session) so it picks up the skill."
