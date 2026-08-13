# Orion Drift PC Spectator — Stutter Fix

Unofficial community tool that fixes hitching in the Orion Drift PC spectator client by
correcting an undersized texture streaming pool.

**[Download the latest release](../../releases/latest)** → extract → double-click
`Fix Orion Drift Stutter.bat`

---

## The problem

The PC build pins its texture streaming pool to **1500 MB** via a project setting that
overrides the engine's own VRAM-based sizing. That value is carried over from the Quest
build.

On a PC graphics card with memory to spare, a pool that small means textures are constantly
evicted and re-streamed as the camera moves. You feel it as hitching when you fly into new
areas.

Two lines apart in the game's own log:

```
LogRHI: Texture pool is 19793 MB (70% of 28277 MB)
LogContentStreaming: Texture pool size now 1500 MB
```

The engine sized the pool at 19.8 GB. The setting forced it to 1500 MB. A third line names
the mechanism outright:

```
LogConsoleManager: Warning: Setting the console variable 'r.Streaming.PoolSize' with
'SetByScalability' was ignored as it is lower priority than the previous 'SetByProjectSetting'.
Value remains '1500'
```

## What the tool does

Reads **your** log to find **your** card's memory, then sizes the pool as a fraction of it.
It never hardcodes a number and never lowers your pool.

| Your VRAM | Default | You get |
|---|---|---|
| 2 GB | 1500 MB | no change |
| 4 GB | 1500 MB | no change |
| 6 GB | 1500 MB | 2304 MB (1.5×) |
| 8 GB | 1500 MB | 3072 MB (2.0×) |
| 12 GB | 1500 MB | 4608 MB (3.1×) |
| 16 GB | 1500 MB | 6144 MB (4.1×) |
| 24 GB+ | 1500 MB | 8192 MB (5.5×) |

Pool = 37.5% of dedicated VRAM, capped at 8192 MB, offered only when it's at least 25%
bigger than what you already have.

**Small cards are told to leave it alone, on purpose.** A 1500 MB pool on a 4 GB card is
roughly the right size already — inflating it would take memory from other things and could
make performance *worse*. This tool only helps cards with memory to spare.

The cap is 8192 MB because that is the largest value anyone has actually measured. It is not
extrapolated.

## How to use

1. Run the Orion Drift spectator client once, then close it — the tool reads the log it
   produces to detect your card
2. **Extract** the zip to a real folder (not the zip viewer, or the `.bat` won't find the `.ps1`)
3. Double-click **`Fix Orion Drift Stutter.bat`**
4. It shows your card, current pool, and last session's stutter count. **Nothing has changed yet**
5. Press `Y` to apply, `N` to cancel
6. Launch Orion Drift normally — it stays applied, this is not a per-session thing

To remove it, double-click **`Undo.bat`**.

## What it changes

Exactly one setting, in one file that belongs to you:

```
%LOCALAPPDATA%\A2\Saved\Config\Windows\Engine.ini
```

```ini
; ===== BEGIN ORION-STUTTER-FIX (managed) =====
[SystemSettings]
r.Streaming.PoolSize=<sized for your card>
; ===== END ORION-STUTTER-FIX =====
```

**No game files are touched.** Your Meta Horizon install stays unmodified — nothing for a
file check to object to, nothing to repair-download. Your original `Engine.ini` is backed up
before any change.

The file is set read-only afterwards. That's deliberate and load-bearing: the game rewrites
`Engine.ini` on exit and strips sections it doesn't recognise, which would silently undo the
fix. `Undo.bat` clears the flag along with everything else.

*Side effect:* while installed, the game can't save a small netcode value (`CachedClientID`)
to that file. This appears harmless. If you hit connection oddities, run `Undo.bat` and see
if they stop.

## What we actually know

Being straight about the evidence:

- **Solid** — the setting is objectively wrong on high-VRAM PCs. The log shows the engine
  computing a large pool and a project setting stomping it to a Quest-era value. Not a
  matter of opinion.
- **Measured on one machine** — on an RTX 5090, stutters in comparable steady-state windows
  fell from 30 to 2, about 1.1/min → 0.1/min. A 90% drop raw, or roughly 47% after crudely
  correcting for the second session being in a quieter area.
- **Not known** — how much it helps *you*. Tested on one GPU. The benefit scales with spare
  memory, so a 6 GB card should expect much less than a 24 GB one, possibly none.

The tool shows your own stutter numbers so you can judge for yourself. Run it, note the
numbers, apply, play, run it again.

**One catch when comparing:** play a similar length of time in a similarly busy area. A short
session is dominated by loading hitches and will look worse than it is. Fifteen minutes or
more gives a fair reading.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "No Orion Drift log found" | Run the spectator client once and close it |
| "Could not read your GPU from the log" | Run the game once more for a fresh startup log |
| Window flashes and vanishes | You're running it from inside the zip — extract first |
| SmartScreen / antivirus complains | Plain-text script, nothing compiled or packed — open both files in Notepad and read them |
| Stutter came back | Run the tool again; a game update can clear the read-only flag |
| I want it gone | `Undo.bat` |

If Windows marks the extracted files as blocked (downloaded from the internet), right-click
each file → Properties → tick **Unblock**.

## Is this allowed?

Not made by, endorsed by, or supported by Another Axiom.

It changes a user configuration file the engine already supports changing. It is not a mod,
it does not alter game code or content, and it confers no gameplay advantage — it's a
graphics memory setting.

The underlying issue is a shipping default on the PC build. The proper fix is upstream,
which would help every player rather than only those who run tools from the internet.

## License

MIT — see [LICENSE](LICENSE).
