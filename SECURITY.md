# Security

## Reporting a problem

Please don't open a public issue (issues are off anyway). Use GitHub's private
reporting instead: the **Security** tab of this repo, then **Report a vulnerability**.

Include what you found, how to reproduce it, and what an attacker could do with it.

## What's in scope

- `watch.py`, `install.sh`, `uninstall.sh`
- The skill instructions in `skill/SKILL.template.md`, for example wording that
  makes an agent more likely to follow instructions hidden in a video

Bugs in ffmpeg, yt-dlp, Whisper or the agents themselves belong with those projects.

## Verifying what you run

The only official source is https://github.com/bramhuiskess/watch-video-skill.
Read `install.sh` before running it. Don't run copies posted elsewhere, and don't
pipe anything from the internet straight into a shell.
