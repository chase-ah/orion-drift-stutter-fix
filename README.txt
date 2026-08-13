===============================================================================
  ORION DRIFT PC SPECTATOR - STUTTER FIX
  Unofficial community tool
===============================================================================

WHAT IT FIXES

  The Orion Drift PC spectator client ships with its texture streaming pool
  pinned to 1500 MB, by a project setting that overrides the engine's own
  VRAM-based sizing. That number is carried over from the Quest build.

  On a PC graphics card with memory to spare, a pool that small means textures
  are constantly thrown away and reloaded as the camera moves. You feel it as
  hitching when you fly into new areas.

  Proof from the game's own log, two lines apart:

      LogRHI: Texture pool is 19793 MB (70% of 28277 MB)
      LogContentStreaming: Texture pool size now 1500 MB

  The engine sized the pool at 19.8 GB, then the setting forced it to 1500 MB.

  This tool reads YOUR log to find YOUR card's memory, and sizes the pool as a
  fraction of it. It never hardcodes a number, and it never lowers your pool.


-------------------------------------------------------------------------------
HOW TO USE
-------------------------------------------------------------------------------

  1. Run the Orion Drift spectator client at least once, then close it.
     (The tool reads the log it produces. Without it there is nothing to
     detect your graphics card from.)

  2. EXTRACT this zip to a real folder. Do not run it from inside the zip
     viewer - the .bat will not find the .ps1.

  3. Double-click:  Fix Orion Drift Stutter.bat

  4. Read what it tells you. It shows your card, your current pool size, your
     last session's stutter count, and what it would change. Nothing has been
     changed yet at this point.

  5. Type Y and press Enter to apply. Type N to cancel.

  6. Launch Orion Drift normally. The fix is active from then on - you do NOT
     need to run this before every session.

  To remove it, double-click:  Undo.bat


-------------------------------------------------------------------------------
WHAT IT CHANGES
-------------------------------------------------------------------------------

  Exactly one setting, in one file that belongs to you:

      %LOCALAPPDATA%\A2\Saved\Config\Windows\Engine.ini

  It adds a clearly marked block:

      ; ===== BEGIN ORION-STUTTER-FIX (managed) =====
      [SystemSettings]
      r.Streaming.PoolSize=<sized for your card>
      ; ===== END ORION-STUTTER-FIX =====

  It does NOT touch any game file. Your Meta Horizon install is untouched and
  unmodified, so there is nothing for a file check to object to and nothing to
  repair-download.

  Your original Engine.ini is copied to the "backups" folder before any change.

  The file is set read-only afterwards. This is deliberate and load-bearing:
  the game rewrites Engine.ini when it closes and deletes sections it does not
  recognise, which would silently undo the fix. Undo.bat clears the read-only
  flag along with everything else.

  Side effect of that: while the fix is installed, the game cannot save a small
  netcode value (CachedClientID) to that file. This appears to be harmless. If
  you ever hit connection oddities, run Undo.bat and see if they go away.


-------------------------------------------------------------------------------
WHAT SIZE YOU GET
-------------------------------------------------------------------------------

  Pool = 37.5% of your card's dedicated video memory, capped at 8192 MB, and
  only offered if it is at least 25% bigger than what you have now.

      Your VRAM     Default      You get
      ---------     -------      -------
      2 GB          1500 MB      no change
      4 GB          1500 MB      no change
      6 GB          1500 MB      2304 MB   (1.5x)
      8 GB          1500 MB      3072 MB   (2.0x)
      12 GB         1500 MB      4608 MB   (3.1x)
      16 GB         1500 MB      6144 MB   (4.1x)
      24 GB+        1500 MB      8192 MB   (5.5x)

  Small cards are told to leave it alone on purpose. A 1500 MB pool on a 4 GB
  card is not the misconfiguration it is on a 24 GB card - it is roughly the
  right size already, and inflating it would take memory away from other things
  and could make performance WORSE. This tool only helps cards with memory to
  spare.

  The cap is 8192 MB because that is the largest value anyone has actually
  measured. It is not extrapolated.


-------------------------------------------------------------------------------
WHAT TO EXPECT - AND WHAT WE ACTUALLY KNOW
-------------------------------------------------------------------------------

  Being straight with you about the evidence:

  SOLID:   The setting is objectively wrong on high-VRAM PCs. The log shows the
           engine computing a large pool and a project setting stomping it down
           to a Quest-era value. That is not a matter of opinion.

  MEASURED ON ONE MACHINE: On an RTX 5090, stutters in comparable steady-state
           windows dropped from 30 to 2 - about 1.1/min down to 0.1/min. That
           is a 90% drop raw, or roughly 47% after crudely correcting for the
           fact that the second session was in a quieter area.

  NOT KNOWN: How much this helps YOU. It has been tested on one GPU. The
           benefit scales with how much spare memory your card has, so a 6 GB
           card should expect a much smaller improvement than a 24 GB one -
           possibly none.

  This tool also shows you your own stutter numbers before and after, so you can
  judge for yourself rather than taking anyone's word for it. Run it, note the
  numbers, apply, play a session, run it again.

  One catch when comparing: play a similar length of time in a similarly busy
  area. A short session is dominated by loading hitches and will look worse than
  it is. Fifteen minutes or more gives a fair reading.


-------------------------------------------------------------------------------
TROUBLESHOOTING
-------------------------------------------------------------------------------

  "No Orion Drift log found"
      Run the spectator client once and close it, then try again.

  "Could not read your GPU from the log"
      Run the game once more so it writes a fresh startup log, then retry.

  The window flashes and vanishes
      You are running it from inside the zip. Extract the folder first.

  Windows SmartScreen or antivirus complains
      This is a plain-text PowerShell script with a .bat that runs it - nothing
      is compiled or packed. Open both files in Notepad and read them; that is
      why they ship as readable source instead of an .exe.

  It says the pool is right but stutter came back
      Run the tool again. A game update or a Meta Horizon repair can clear the
      read-only flag and let the game strip the setting.

  I want it gone
      Undo.bat. It removes the block, clears the read-only flag, and leaves the
      rest of your config exactly as it was.


-------------------------------------------------------------------------------
NOTES
-------------------------------------------------------------------------------

  This is not made by, endorsed by, or supported by Another Axiom. It changes a
  user configuration file that the engine already supports changing. It is not a
  mod, it does not alter game code or content, and it gives no gameplay
  advantage - it is a graphics memory setting.

  The underlying issue is a shipping default on the PC build. The proper fix is
  for it to be corrected upstream, which would help every player rather than
  only the ones who run tools from the internet.
