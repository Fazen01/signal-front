# Signal Front

An original 3D real-time strategy game in Godot 4.7.2 (typed GDScript).
Design: [docs/DESIGN.md](docs/DESIGN.md). Work queue and session log:
[docs/ROADMAP.md](docs/ROADMAP.md). Read both before changing anything.

## How this project is built

The game is built by a relay of unattended sessions, mostly overnight. The
owner is not available to answer questions. Each session picks up where the
last one stopped, using only what is in the repository.

### At the start of every session

1. `git fetch --all --prune`.
2. Find the most advanced work: compare `origin/main` with every other remote
   branch and take the one with the newest commit. If your working branch does
   not already contain it, merge it in before doing anything else. Earlier
   sessions may have pushed to their own branches rather than to `main`.
3. If the newest commit on any remote branch is under 25 minutes old, another
   session is probably still running. Wait 10 minutes and look again; if a new
   commit has appeared, stop without making changes. Two sessions working the
   same roadmap item at once only produce conflicts.
4. Read the session log at the bottom of the roadmap, then start on the first
   unticked roadmap item.

### While working

- Never stop to ask a question. Decide, and record the decision in the
  session log.
- Commit small and push after **every** commit. A session can be cut off by a
  usage limit at any moment, and unpushed work is lost.
- Push something at least every 15 minutes so later sessions can tell you are
  alive. If the code is not ready, push a session-log update saying what you
  are working on.
- Add your session-log entry early and keep it current; do not leave it for
  the end.
- Push to your session's branch. If you are able to open pull requests, keep
  one to `main` open for the work and update its description as milestones
  land. Do not merge it; the owner reviews in the morning. If you cannot open
  one, pushing the branch is enough.
- Run `tools/check.sh` before every push once it exists. Never push a commit
  that breaks it, and never weaken a check to get it to pass.
- From M5 onward the game must stay playable at every pushed commit:
  menu → skirmish → match → result.

### Verifying without a screen

Sessions run headless and cannot look at the game, so checks carry the weight:

- `tools/install_godot.sh` downloads Godot 4.7.2 for Linux into `.godot-bin/`.
  Expected asset:
  `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
  — confirm the name against the release page if the download fails.
- `tools/check.sh` must: import the project, run the unit tests, boot the real
  menu and battle scenes headless for a few hundred frames, run a headless
  AI-vs-AI match, and fail on any script error or warning treated as error in
  the output.
- If a software-GL display is available (`xvfb-run` with
  `--rendering-driver opengl3`), capture screenshots of the battle scene and
  look at them to check that models, HUD and overlays are actually visible and
  sensibly laid out. If it is not available, say so in the session log.
- If Godot cannot be downloaded at all, say so in the session log, keep going,
  and be extra strict about typed code and small, simple changes.

## Code rules

- Simulation (`sim/`) is plain typed classes with no scene-tree access, a
  fixed 20 Hz tick and a seeded RNG. Presentation (`view/`, `ui/`) reads sim
  state and sends orders; it never mutates sim state directly.
- Units, buildings, weapons and factions are data in `data/`, not constants
  scattered through code.
- No downloaded or third-party assets. Models, effects and sound are generated
  in code.
- Everything is original. Do not use names, units, factions, art, audio, text
  or map layouts from any existing game.
- The owner plays on Windows 11 with Godot 4.7.2: keep paths `res://`-relative,
  file names lowercase snake_case, and avoid anything Linux-only at runtime.
