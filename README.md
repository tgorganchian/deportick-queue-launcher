# deportick-queue-launcher

Opens several isolated Chrome windows so each one takes its own place in the
Deportick waiting room. **It does not buy anything**: you check out by hand in
whichever window gets through first.

Built for **Argentina vs Benin**, on sale **Thursday 2026-09-24, 18:00 ART**
([AFA info page](https://www.deportick.com/static/afaproxpartidos)).
Based on the idea behind [fpiantoni/ticketing-Script-Invoker](https://github.com/fpiantoni/ticketing-Script-Invoker).

## How it works

- Deportick runs on Crowder with **Queue-it** as its waiting room. Your place in
  line is the Queue-it `QueueId`, stored in Queue-it cookies, not in the
  Deportick session.
- You log in once (`profile-0`). Each extra window is a fresh Chrome profile
  that only receives `profile-0`'s cookies and localStorage. Deportick stores
  the login in localStorage (`crowder`, `crowder-user`), not in a cookie.
- Before launching, Queue-it cookies (`*queue-it*`, `QueueIT*`) are deleted from
  every profile, so each window is assigned a fresh `QueueId`.
- Profiles live in `profiles/` (gitignored). They contain your login token, so
  don't share them.

## Requirements

- Google Chrome in its default install path.
- Windows: PowerShell 5.1+ and Python 3 on `PATH` (used to clear the cookie SQLite DB).
- macOS: nothing extra (`sqlite3` ships with macOS).

## Usage

**1. Before the sale: log in once.** A single window opens. Log in, then fully
quit Chrome (on macOS: `Cmd+Q`). Profiles can't be copied while Chrome is running.

```bash
# macOS
bash macos/launch.sh --setup
# Windows
powershell -ExecutionPolicy Bypass -File windows\launch.ps1 -Setup
```

**2. At ~17:55: launch the windows.** Use the `/event/...` URL once Deportick
publishes it. If it isn't out yet, use the info page and click through in each window.

```bash
# macOS
bash macos/launch.sh "https://www.deportick.com/event/<event>" 12
# Windows
powershell -ExecutionPolicy Bypass -File windows\launch.ps1 -Url "https://www.deportick.com/event/<event>" -Count 5
```

**3. In the queue:**
- Check the **Queue ID** shown at the bottom of each waiting room page. They must all be different.
- Don't refresh, and don't close the windows or re-run the script once they're queued.
  A re-run starts from scratch.
- Buy in **one** window only. If there's a per-account/DNI limit, parallel orders can get cancelled.

**Reset** (wipe all profiles and the saved login):

```bash
bash macos/launch.sh --reset        # macOS
powershell -ExecutionPolicy Bypass -File windows\launch.ps1 -Reset   # Windows
```

## How many windows

**10–12, 20 at most.** RAM is not the limit on a recent MacBook. These are:

- **Screen.** On macOS the script reads the screen size and tiles ~500px-wide
  windows in 2 rows. On a 14"/16" MacBook Pro that's 6 side by side. Windows
  7–12 are stacked over those slots, offset 40px. Past ~12 you can't tell which
  one got through.
- **Captchas.** Deportick loads reCAPTCHA and Turnstile. If each window has to
  solve one to enter the queue, 30 windows means minutes of captchas.
- **Detection.** Many sessions from one IP make it more likely Queue-it flags you.
- **One purchase anyway.** Same account, and likely a per-DNI limit.

Queue-it typically randomizes everyone who arrives *before* the sale opens
(general Queue-it behavior, not verified for this event). In that pre-queue each
window is one more ticket in the draw. Windows opened *after* 18:00 line up
first-come-first-served, all at roughly the same spot, so extra windows add
little. Launch at ~17:55.

## Fallback: launch without the shared login

Every cloned window shares the same Deportick session. If that turns out to be a
problem (the Queue IDs aren't distinct, windows collapse into one place in line,
or Deportick logs the other windows out), reset and launch **without** `--setup`.
Every window then starts from a blank profile, like the reference repo. Log in
only in the window that gets through.

```bash
# macOS
bash macos/launch.sh --reset && bash macos/launch.sh "https://www.deportick.com/event/<event>" 5
# Windows
powershell -ExecutionPolicy Bypass -File windows\launch.ps1 -Reset
powershell -ExecutionPolicy Bypass -File windows\launch.ps1 -Url "https://www.deportick.com/event/<event>" -Count 5
```

Close the current windows first: a reset while they're open fails, because
Chrome locks the profile files. Relaunching also loses the current places in line,
so decide early, ideally right when the waiting room opens.

## Status

| | Windows | macOS |
|---|---|---|
| Windows open with isolated profiles | ✅ tested | ⚠️ not run yet |
| Login carries over to cloned windows | ✅ tested with a real account | ⚠️ not run yet |
| Queue-it cookies cleared, other cookies kept | ✅ tested with dummy cookies | ⚠️ not run yet |
| Window tiling fits the screen | fixed grid for 1920px | ⚠️ math checked for 14"/16", not run yet |
| Distinct QueueId per window | ⏳ only verifiable once the queue is live | ⏳ |

On macOS, do a dry run the day before: `--setup`, log in, quit, then launch 3
windows against `https://www.deportick.com` and check all of them are logged in.

## Caveats

- Deportick has `userSessionsEnabled`. It might invalidate the session in the
  other windows when you act in one. If so, just log in again in the window that
  got through.
- Running several queue positions most likely goes against Deportick's terms of service.
