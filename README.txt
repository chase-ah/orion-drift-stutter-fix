===============================================================================
  ORION DRIFT PC SPECTATOR STUTTER FIX
  Unofficial community tool
===============================================================================

WHAT'S ACTUALLY WRONG

  The PC build caps its texture streaming pool at 1500 MB. That number comes
  from the Quest version, and on PC it overrides the engine's own sizing, which
  is based on how much VRAM you actually have.

  So if your card has memory to spare, it just sits there unused while the game
  throws textures away and reloads them over and over. That's what you're
  feeling when the camera moves somewhere new and it stutters.

  Here's the game's own log saying it, two lines apart:

      LogRHI: Texture pool is 19793 MB (70% of 28277 MB)
      LogContentStreaming: Texture pool size now 1500 MB

  The engine worked out 19.8 GB. Then the setting forced it down to 1500.

  This tool reads YOUR log, finds YOUR card's VRAM, and sets the pool based on
  that. No hardcoded numbers, and it'll never make your pool smaller.


-------------------------------------------------------------------------------
HOW TO USE IT
-------------------------------------------------------------------------------

  1. Run the Orion Drift spectator client once, then close it.
     The tool needs the log it makes to work out what GPU you have.

  2. EXTRACT this zip to a real folder. If you run it from inside the zip
     window the .bat won't find the .ps1.

  3. Double click:  Fix Orion Drift Stutter.bat

  4. Read what it tells you. It shows your card, your current pool size, and
     how many stutters it found in your last session. Nothing has changed at
     this point.

  5. Press Y to apply, or N to back out.

  6. Launch the game normally. It stays applied, you don't need to run this
     before every session.

  To get rid of it, double click:  Undo.bat


-------------------------------------------------------------------------------
WHAT IT CHANGES
-------------------------------------------------------------------------------

  One setting, in one file that belongs to you:

      %LOCALAPPDATA%\A2\Saved\Config\Windows\Engine.ini

  It adds a clearly marked block:

      ; ===== BEGIN ORION-STUTTER-FIX (managed) =====
      [SystemSettings]
      r.Streaming.PoolSize=<sized for your card>
      ; ===== END ORION-STUTTER-FIX =====

  No game files get touched. Your Meta Horizon install stays exactly as it was,
  so there's nothing for a file check to complain about and nothing to
  redownload. Your old Engine.ini gets backed up first, into the "backups"
  folder.

  It sets that file to read only afterwards. That isn't paranoia, it's
  necessary: the game rewrites Engine.ini when it closes and deletes any
  section it doesn't recognise, so without it the fix would quietly vanish.
  Undo.bat clears the flag along with everything else.

  Side effect: while it's installed, the game can't save a small netcode value
  (CachedClientID) to that file. Looks harmless. If you start getting weird
  connection issues, run Undo.bat and see if they stop.


-------------------------------------------------------------------------------
WHAT SIZE YOU GET
-------------------------------------------------------------------------------

      Your VRAM     Default      You get
      ---------     -------      -------
      2 GB          1500 MB      no change
      4 GB          1500 MB      no change
      6 GB          1500 MB      2304 MB   (1.5x)
      8 GB          1500 MB      3072 MB   (2.0x)
      12 GB         1500 MB      4608 MB   (3.1x)
      16 GB         1500 MB      6144 MB   (4.1x)
      24 GB+        1500 MB      8192 MB   (5.5x)

  It works out to 37.5% of your VRAM, capped at 8192 MB, and it only bothers
  offering the change if it's at least 25% bigger than what you've already got.

  Small cards get left alone on purpose. 1500 MB on a 4 GB card is about right
  already, and inflating it would just steal memory from other things and could
  make it worse. This only helps cards with memory going spare.

  The 8192 cap is there because that's the biggest value anyone has actually
  tested. I'm not guessing past that.


-------------------------------------------------------------------------------
WHAT I ACTUALLY KNOW, AND WHAT I DON'T
-------------------------------------------------------------------------------

  Being straight about this instead of overselling it.

  DEFINITELY TRUE
      The setting is wrong on PCs with a decent amount of VRAM. The log shows
      the engine picking a big number and a project setting stamping it down to
      a Quest era value. That bit isn't up for debate.

  MEASURED, ON ONE MACHINE
      An RTX 5090, two sessions of almost exactly the same length:

                                  Before      After
          session length          28.9 min    29.0 min
          stutters                33          5
          ignoring loading spike  30          2
          per minute, same        1.13        0.08
          how busy the area was   2.80/sec    3.13/sec

      That last row matters. The "after" session was in a BUSIER area than the
      "before" one, so if anything it should have looked worse. It still came
      out 93% better once you ignore the loading spike at the start.

  NO IDEA
      How much it helps you. One GPU has been tested. The benefit scales with
      how much spare memory you have, so a 6 GB card should expect a lot less
      than a 24 GB one, maybe nothing at all.

  The tool shows you your own stutter numbers so you don't have to take my word
  for any of it. Run it, note what it says, apply it, play, run it again.

  One thing to watch when you compare: play a similar amount of time in a
  similarly busy area. A short session is mostly loading hitches and will look
  worse than it really is. 15 minutes or more gives you a fair read.


-------------------------------------------------------------------------------
IF SOMETHING GOES WRONG
-------------------------------------------------------------------------------

  "No Orion Drift log found"
      Run the spectator client once and close it, then try again.

  "Could not read your GPU from the log"
      Run the game once more so it writes a fresh startup log, then retry.

  The window flashes up and disappears
      You're running it from inside the zip. Extract the folder first.

  Antivirus or SmartScreen complains
      It's a plain text PowerShell script with a .bat that runs it. Nothing is
      compiled or packed. Open both in Notepad and read them, that's exactly
      why they ship as readable source instead of an .exe.

  Windows says the files are blocked
      They came off the internet. Right click each one, Properties, tick
      Unblock.

  The stutter came back
      Run the tool again. A game update or a Meta Horizon repair can clear the
      read only flag and let the game strip the setting back out.

  I want it gone
      Undo.bat. It removes the block, clears the read only flag, and leaves the
      rest of your config exactly as it was.


-------------------------------------------------------------------------------
IS THIS ALLOWED
-------------------------------------------------------------------------------

  Nothing to do with Another Axiom. Not made by them, not endorsed by them, not
  supported by them.

  All it does is change a config file that the engine already reads. It isn't a
  mod, it doesn't touch game code or content, and it doesn't give you any
  advantage in game. It's a graphics memory setting.

  The real fix is for this to get sorted out in the game itself, which would
  help everyone instead of just the people willing to run something off GitHub.
