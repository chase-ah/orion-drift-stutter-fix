# Orion Drift PC Spectator Stutter Fix

[![Release](https://img.shields.io/github/v/release/chase-ah/orion-drift-stutter-fix?color=blue)](../../releases/latest)
[![Downloads](https://img.shields.io/github/downloads/chase-ah/orion-drift-stutter-fix/total)](../../releases/latest)
[![License](https://img.shields.io/github/license/chase-ah/orion-drift-stutter-fix)](LICENSE)

Unofficial fix for the constant hitching in the Orion Drift PC spectator client.

**[Download it here](../../releases/latest)**, extract it, double click `Fix Orion Drift Stutter.bat`.

On the machine it was built on, stutters went from **33 down to 5** over a matched 29 minute
session. Ignoring the loading spike at the start, **30 down to 2**.

## What it looks like

```
  ORION DRIFT SPECTATOR - STUTTER FIX  v1.0.0
  Unofficial community tool. Edits one user config file. No game files touched.

  Your system
  -----------
    graphics card             NVIDIA GeForce RTX 5090
    video memory              32187 MB
    texture pool now          1500 MB

  Your last session
  -----------------
    session length            28.9 min
    stutters detected         33  (1.14 per minute)
    worst freeze              419 ms
    (this counts only stutters the log happens to catch - it is a floor, not a total)

  Recommendation
  --------------
    texture pool now          1500 MB
    would change to           8192 MB
    that is                   5.5x bigger

  Apply this fix? (Y/N)
```

It tells you what it found and what it wants to do, then waits. Nothing changes until you
press Y.

## What's actually wrong

The PC build caps its texture streaming pool at 1500 MB. That number comes from the Quest
version, and on PC it overrides the engine's own sizing, which is based on how much VRAM you
actually have.

So if your card has memory to spare, it just sits there unused while the game throws
textures away and reloads them over and over. That's what you're feeling when the camera
moves somewhere new and it stutters.

Here's the game's own log saying it, two lines apart:

```
LogRHI: Texture pool is 19793 MB (70% of 28277 MB)
LogContentStreaming: Texture pool size now 1500 MB
```

The engine worked out 19.8 GB. Then the setting forced it down to 1500. And a third line
spells out exactly why the engine lost that argument:

```
LogConsoleManager: Warning: Setting the console variable 'r.Streaming.PoolSize' with
'SetByScalability' was ignored as it is lower priority than the previous 'SetByProjectSetting'.
Value remains '1500'
```

## What this does about it

It reads your log, finds your GPU's VRAM, and sets the pool based on that. No hardcoded
numbers, and it will never make your pool smaller than it already is.

| Your VRAM | Default | You get |
|---|---|---|
| 2 GB | 1500 MB | no change |
| 4 GB | 1500 MB | no change |
| 6 GB | 1500 MB | 2304 MB (1.5x) |
| 8 GB | 1500 MB | 3072 MB (2.0x) |
| 12 GB | 1500 MB | 4608 MB (3.1x) |
| 16 GB | 1500 MB | 6144 MB (4.1x) |
| 24 GB+ | 1500 MB | 8192 MB (5.5x) |

The pool works out to 37.5% of your VRAM, capped at 8192 MB, and it only bothers offering
the change if it's at least 25% bigger than what you've already got.

Small cards get left alone on purpose. 1500 MB on a 4 GB card is about right already, and
inflating it would just steal memory from other things and could make it worse. This only
helps cards with memory going spare.

The 8192 cap is there because that's the biggest value anyone has actually tested. I'm not
guessing past that.

## How to use it

1. Run the spectator client once and close it. The tool needs the log it makes to work out
   what GPU you have.
2. Extract the zip properly. If you run it from inside the zip window the `.bat` won't find
   the `.ps1`.
3. Double click **`Fix Orion Drift Stutter.bat`**
4. It shows your card, your current pool size, and how many stutters it found in your last
   session. **Nothing has changed at this point.**
5. Press `Y` to apply, `N` to back out.
6. Launch the game normally. It stays applied, you don't need to run this every time.

To get rid of it, double click **`Undo.bat`**.

## What it changes

One setting, in one file that belongs to you:

```
%LOCALAPPDATA%\A2\Saved\Config\Windows\Engine.ini
```

```ini
; ===== BEGIN ORION-STUTTER-FIX (managed) =====
[SystemSettings]
r.Streaming.PoolSize=<sized for your card>
; ===== END ORION-STUTTER-FIX =====
```

**No game files get touched.** Your Meta Horizon install stays exactly as it was, so there's
nothing for a file check to complain about and nothing to redownload. Your old `Engine.ini`
gets backed up before anything happens.

It sets that file to read only afterwards. That part isn't paranoia, it's necessary: the
game rewrites `Engine.ini` when it closes and deletes any section it doesn't recognise, so
without it the fix would quietly vanish. `Undo.bat` clears the flag along with everything
else.

Side effect: while it's installed, the game can't save a small netcode value
(`CachedClientID`) to that file. Looks harmless. If you start getting weird connection
issues, run `Undo.bat` and see if they stop.

## What I actually know, and what I don't

Being straight about this instead of overselling it:

**Definitely true.** The setting is wrong on PCs with a decent amount of VRAM. The log shows
the engine picking a big number and a project setting stamping it down to a Quest era value.
That bit isn't up for debate.

**Measured, on one machine.** An RTX 5090, two sessions of almost exactly the same length:

| | Before | After |
|---|---|---|
| Session length | 28.9 min | 29.0 min |
| Stutters | 33 | 5 |
| Ignoring the loading spike | 30 | 2 |
| Per minute, same | 1.13 | 0.08 |
| How busy the area was | 2.80 voice events/sec | 3.13 voice events/sec |

That last row matters. The "after" session was in a *busier* area than the "before" one, so
if anything it should have looked worse. It still came out 93% better once you ignore the
loading spike at the start.

**No idea.** How much it helps *you*. One GPU has been tested. The benefit scales with how
much spare memory you have, so a 6 GB card should expect a lot less than a 24 GB one, maybe
nothing at all.

The tool shows you your own stutter numbers so you don't have to take my word for any of
this. Run it, note what it says, apply it, play, run it again.

One thing to watch when you compare: play a similar amount of time in a similarly busy area.
A short session is mostly loading hitches and will look worse than it really is. 15 minutes
or more gives you a fair read.

## If something goes wrong

| What you see | What to do |
|---|---|
| "No Orion Drift log found" | Run the spectator client once and close it |
| "Could not read your GPU from the log" | Run the game once more so it writes a fresh startup log |
| Window flashes up and disappears | You're running it from inside the zip, extract it first |
| Antivirus or SmartScreen complains | It's plain text, nothing compiled or packed. Open both files in Notepad and read them |
| Stutter came back | Run the tool again. A game update can clear the read only flag |
| I want it gone | `Undo.bat` |

If Windows marks the files as blocked because they came off the internet, right click each
one, Properties, tick **Unblock**.

## Is this allowed

Nothing to do with Another Axiom. Not made by them, not endorsed by them, not supported by
them.

All it does is change a config file that the engine already reads. It isn't a mod, it
doesn't touch game code or content, and it doesn't give you any advantage in game. It's a
graphics memory setting.

The real fix is for this to get sorted out in the game itself, which would help everyone
instead of just the people willing to run something off GitHub.

## License

MIT, see [LICENSE](LICENSE).
