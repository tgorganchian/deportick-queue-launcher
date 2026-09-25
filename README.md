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
- You log in once (Windows: `profiles/login`; macOS: `profiles/profile-0`).
  Each extra window is a fresh Chrome profile
  that only receives the login profile's cookies and localStorage. Deportick stores
  the login in localStorage (`crowder`, `crowder-user`), not in a cookie.
- Before launching, Queue-it cookies (`*queue-it*`, `QueueIT*`) are deleted from
  every profile, so each window is assigned a fresh `QueueId`.
- All Chrome profiles live in `profiles/` (gitignored). They contain your login
  token, so don't share them.

## Requirements

- Google Chrome in its default install path.
- Windows: PowerShell 5.1+ and Python 3 on `PATH` (used to clear the cookie SQLite DB).
- macOS: nothing extra (`sqlite3` ships with macOS).

## Usage

**1. Before the sale: log in once.** A single window opens. Complete the
Deportick login and confirm that `Mi cuenta` / `Mis entradas` appears. Then fully
quit that Chrome window (on macOS: `Cmd+Q`). Profiles can't be copied while Chrome
is running. The launcher creates the login profile inside `profiles/`.

```bash
# macOS
bash macos/launch.sh --setup
# Windows
powershell -ExecutionPolicy Bypass -File windows\launch.ps1 -Setup
```

**2. At ~17:55: launch the windows.** The default URL is the
[Argentina vs Benin event page](https://www.deportick.com/event/argbenin26).
Deportick redirects each logged-in browser to the Queue-it waiting room with
its own access token. Opening the bare Queue-it URL directly led to human
verification or `Acceso restringido` in a live check on 2026-09-24.
Close every launcher Chrome window before this step; restarting loses any
existing queue position. Do not commit or share `profiles/`.

```bash
# macOS
bash macos/launch.sh "https://www.deportick.com/event/argbenin26" 12
# Windows
powershell -ExecutionPolicy Bypass -File windows\launch.ps1 -Count 9
```

**3. In the queue:**
- Complete the human captcha **manually in every window**. Each isolated profile
  gets its own challenge; copying the login does not complete it. The launcher
  cannot put a window in the queue until its challenge is solved.
- Check the **Queue ID** shown at the bottom of each waiting room page. They must all be different.
- Don't refresh, and don't close the windows or re-run the script once they're queued.
  A re-run starts from scratch.
- Buy in **one** window only. If there's a per-account/DNI limit, parallel orders can get cancelled.

**Reset** (wipe queue profiles; on macOS this also removes the saved login):

```bash
bash macos/launch.sh --reset        # macOS
powershell -ExecutionPolicy Bypass -File windows\launch.ps1 -Reset   # Windows
```

On Windows, `-Reset` keeps `profiles/login`, so the next launch can reuse it.

## How many windows

More windows means more places in line, but each one gets smaller. The script
tiles ~500px-wide columns (Chrome's minimum width, measured) and picks the
fewest rows, up to 4, that fit every window side by side. On a typical
laptop-size or 1080p screen (3 columns):

| Windows per screen | Grid | Looks |
|---|---|---|
| 9 | 3 × 3 | Comfortable. The page is readable. |
| 12 | 3 × 4 | Tight: little more than the tab bar and page header. Still enough to spot the window that gets through. |

Even when a window is small you can tell it got through: the page switches from
the Queue-it waiting room to Deportick, and the tab title changes. Past 4 rows,
extra windows stack over the same slots, offset 40px.

**Several monitors (Windows only for now):** the grid spans every screen, so the
count scales with the number of monitors (e.g. 2 screens → 18 at 3 × 3). The
limit then is the machine, not the screen: each window is a full browser
instance, so watch RAM and CPU. If windows start loading slowly, you've
opened too many. On macOS the script still treats the whole desktop as one screen,
so stick to the laptop screen there.

Other limits:

- **Captchas.** Every window required a manual human challenge in the live
  2026-09-24 flow. Budget time for N challenges when choosing N windows.
- **Detection.** Many sessions from one IP make it more likely Queue-it flags you.
- **One purchase anyway.** Same account, and likely a per-DNI limit.

At 18:00 ART, each Queue ID in the pre-queue is assigned a place by a draw.
The time estimate shown afterward varies by Queue ID; it is not a fixed part
of this workflow. Enter early enough to finish every manual captcha before
the draw.

## Fallback: launch without the shared login

Every cloned window shares the same Deportick session. If that turns out to be a
problem (the Queue IDs aren't distinct, windows collapse into one place in line,
or Deportick logs the other windows out), stop using the cloned windows. Log in
manually in one browser profile and continue there.

On Windows or macOS, open the [event page](https://www.deportick.com/event/argbenin26)
in one normal Chrome profile.

Close the current windows first: a reset while they're open fails, because
Chrome locks the profile files. Relaunching also loses the current places in line,
so decide early, ideally right when the waiting room opens.

## Status

| | Windows | macOS |
|---|---|---|
| Windows open with isolated profiles | ✅ tested | ⚠️ not run yet |
| Login carries over to cloned windows | ✅ tested with a real account | ⚠️ not run yet |
| Queue-it cookies cleared, other cookies kept | ✅ tested with dummy cookies | ⚠️ not run yet |
| Window tiling fits the screen | ✅ tested on 2 screens with mixed scaling (100% + 125%), 12 and 18 windows | ⚠️ math checked for 14"/16", not run yet |
| Distinct QueueId per window | ✅ tested | ⏳ |

On macOS, do a dry run the day before: `--setup`, log in, quit, then launch 3
windows against `https://www.deportick.com` and check all of them are logged in.

## Caveats

- Deportick has `userSessionsEnabled`. It might invalidate the session in the
  other windows when you act in one. If so, just log in again in the window that
  got through.
- Running several queue positions most likely goes against Deportick's terms of service.
