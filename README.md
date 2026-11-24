# watch-video

A skill that lets AI coding agents watch videos. Works with **Codex**, **Claude Code**, **Antigravity** and **Gemini CLI**.

Give your agent a YouTube link, a screen recording or any video file and ask what happens in it. The agent pulls stills from across the video, gets a transcript, looks at the frames, and answers with timestamps. For example:

```
> watch ./bug-repro.mov and tell me where the layout breaks

- 00:04  Settings page loads normally.
- 00:11  After tapping "Edit profile" the avatar overlaps the name field.
- 00:12  Rotating to landscape makes it worse: the Save button is pushed off screen.
```

## Why I made this

I wanted Codex to watch a screen recording and couldn't find a good skill for it. What I did find either sent the video to some cloud API, needed API keys, or ran install scripts I didn't trust. So I built my own: it runs locally, the code is short enough to read in one sitting, and it doesn't send anything anywhere unless you tell it to.

Turns out it's useful for more than bug recordings. I use it to summarize talks, check what a tutorial covers before I sit through it, and review UI flows.

## How it works

You can't feed a video into a language model, but you can do what a person does when they skim one.

1. `watch.py` takes a URL or a local file. URLs go through [yt-dlp](https://github.com/yt-dlp/yt-dlp).
2. [ffmpeg](https://ffmpeg.org) pulls evenly spaced stills (40 by default) and builds labelled contact sheets.
3. It gets a transcript, trying in this order:
   - subtitles from the site
   - subtitles embedded in the file
   - local Whisper on your machine (mlx-whisper on Apple Silicon, faster-whisper on the CPU everywhere else)
4. The agent reads the transcript, looks at the frames with its own image tool, and zooms in on moments that need a closer look.

Everything lands in `./.watch/<name>/` in your project, so you can open the frames yourself too.

## Install

Requirements: macOS or Linux, Python 3.9+, ffmpeg, and yt-dlp (only for URLs).

```bash
# macOS
brew install python ffmpeg yt-dlp
```

```bash
git clone https://github.com/bramhuiskess/watch-video-skill.git
cd watch-video-skill
```

Read `install.sh` before you run it. It's about 130 lines and explains what it touches. Then:

```bash
./install.sh
```

The installer finds which agents you have and installs the skill for each. To pick them yourself:

```bash
./install.sh --codex --claude          # or --antigravity, --gemini, --all
./install.sh --no-whisper              # skip local Whisper, subtitles only
```

Restart your agent or start a new session afterwards so it picks up the skill.

### What gets installed where

| Path | What |
|---|---|
| `~/.local/share/watch-video/` | `watch.py` plus a private Python venv with Whisper |
| `~/.claude/skills/watch-video/` | Claude Code skill |
| `~/.codex/skills/watch-video/` | Codex skill |
| `~/.gemini/config/skills/watch-video/` | Antigravity skill |
| `~/.gemini/skills/watch-video/` | Gemini CLI skill |
| `~/.cache/huggingface/` | Whisper base model, about 150 MB |

No sudo, no global pip installs, no changes to your shell config. If you already had a different skill called `watch-video`, the installer moves it to `SKILL.md.bak` and `uninstall.sh` puts it back.

### Uninstall

```bash
./uninstall.sh
```

## Usage

Just ask in plain language:

- "Watch https://youtu.be/... and summarize it"
- "Look at ~/Desktop/recording.mov. At what point does the upload fail?"
- "What's on the slides between 10:00 and 15:00 in this talk?"

You can run the script yourself as well:

```bash
python3 ~/.local/share/watch-video/watch.py video.mp4 --max-frames 60
python3 ~/.local/share/watch-video/watch.py "https://youtu.be/..." --start 600 --end 900 --interval 5
```

| Option | Default | What it does |
|---|---|---|
| `--max-frames` | 40 | Number of stills, max 300 |
| `--interval` | spread evenly | Seconds between stills |
| `--start` / `--end` | whole video | Only look at part of it |
| `--width` | 1024 | Still width in pixels, raise it for small text |
| `--whisper-model` | base | `small` or `medium` for harder audio |
| `--no-transcript` | off | Frames only |
| `--allow-cloud-transcribe` | off | Allow uploading audio to OpenAI if nothing local works |
| `-o` | `./.watch/<name>` | Output folder |

## Safety

I wanted this to be something I'd be comfortable running on my own machine. Here's what that means in practice.

- **Local by default.** Frames, subtitles and Whisper all run on your machine. The only network traffic is downloading the video you asked for and, once, the Whisper model. Audio goes to OpenAI only if you pass `--allow-cloud-transcribe` and have `OPENAI_API_KEY` set, and the skill tells the agent to ask you first.
- **Nothing downloaded gets executed.** The script runs ffmpeg, ffprobe and yt-dlp with fixed arguments, without a shell. yt-dlp runs with `--ignore-config`, so a config file can't add `--exec` hooks. The URL goes after `--`, so it can't be read as an option. Only `http(s)://` URLs are downloaded.
- **Prompt injection.** A video can contain text aimed at your agent, in its subtitles, description or on screen. The skill tells the agent to treat all of it as data and never follow instructions found in a video, and the manifest marks it as untrusted. That lowers the risk; it can't remove it. Keep your agent's approval prompts on for commands.
- **Limits.** Downloads are capped at 720p and 4 GB, stills at 300.
- **Pinned dependencies.** Whisper packages are pinned in `requirements.txt` and live in their own venv.
- **Readable.** About 450 lines of Python and two shell scripts. No binaries, no minified code, no telemetry.

Found a security problem? See [SECURITY.md](SECURITY.md).

## Disclaimer

Provided as is, without warranty of any kind. See [LICENSE](LICENSE).

- **Respect copyright and terms of service.** Only download videos you have the right to download. Some sites forbid downloading in their terms. You're responsible for what you watch with this.
- **Agents make mistakes.** The agent sees stills, not motion. It can miss things that happen between frames or misread text. Check anything that matters.
- **Third-party tools.** This relies on ffmpeg, yt-dlp, Whisper and your AI agent, each with its own license and behaviour. Keep ffmpeg and yt-dlp up to date, since they parse untrusted media.
- **Not affiliated** with OpenAI, Anthropic, Google, or the authors of any tool listed here.

## Contributing

This repo is read only: I'm not taking pull requests or issues. Fork it and change whatever you like, it's MIT licensed.

## License

[MIT](LICENSE)
