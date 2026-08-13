<#
    Orion Drift PC Spectator - Stutter Fix
    ---------------------------------------------------------------------------
    The PC build ships with its texture streaming pool pinned to 1500 MB by a
    project setting that overrides the engine's own VRAM-based sizing. That value
    comes from the Quest build. On a PC GPU with plenty of VRAM it means textures
    are evicted and re-streamed constantly as the camera moves, which shows up as
    hitching when you fly into new areas.

    This tool reads YOUR log to find YOUR GPU's VRAM, then sizes the pool as a
    fraction of it. It never hardcodes a number, and it never lowers your pool.

    It writes ONE setting to ONE file you own:
        %LOCALAPPDATA%\A2\Saved\Config\Windows\Engine.ini

    It does not touch any game file, so the Meta Horizon install stays untouched
    and unmodified. Undo.bat reverses everything.

    Source is plain text on purpose - read it before you run it.
#>
[CmdletBinding()]
param(
    [switch] $Undo,
    [switch] $NonInteractive
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$ToolVersion = '1.0.0'
$BeginMarker = '; ===== BEGIN ORION-STUTTER-FIX (managed) ====='
$EndMarker   = '; ===== END ORION-STUTTER-FIX ====='

# Sizing curve. See README for the reasoning behind each number.
$VramFraction = 0.375   # pool = 37.5% of dedicated VRAM
$PoolCapMB    = 8192    # the only value with measured evidence behind it
$MinVramMB    = 4096    # below this the stock 1500 MB is already reasonable
$StockPoolMB  = 1500

$ConfigDir = Join-Path $env:LOCALAPPDATA 'A2\Saved\Config\Windows'
$EngineIni = Join-Path $ConfigDir 'Engine.ini'
$LogDir    = Join-Path $env:LOCALAPPDATA 'A2\Saved\Logs'
$BackupDir = Join-Path $PSScriptRoot 'backups'

function Write-Title {
    param([string] $Text)
    Write-Host ''
    Write-Host ('  ' + $Text) -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * $Text.Length)) -ForegroundColor DarkCyan
}

function Write-Row {
    param([string] $Label, $Value, [string] $Colour = 'Gray')
    Write-Host ('    {0,-26}' -f $Label) -NoNewline
    Write-Host $Value -ForegroundColor $Colour
}

function Get-LatestLog {
    if (-not (Test-Path -LiteralPath $LogDir)) { return $null }
    $log = Get-ChildItem -LiteralPath $LogDir -Filter 'A2*.log' -File -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $log) { return $null }
    $log.FullName
}

<#
    One pass over the log. Opened with FileShare ReadWrite because the game keeps
    its handle open while running.
#>
function Read-A2Log {
    param([Parameter(Mandatory)][string] $Path)

    $stampRe   = [regex] '^\[(\d{4})\.(\d{2})\.(\d{2})-(\d{2})\.(\d{2})\.(\d{2}):(\d{3})\]\[\s*(\d+)\]'
    $foundRe   = [regex] 'Found D3D12 adapter (\d+): (.+?) \(VendorId'
    $vramRe    = [regex] 'Adapter has (\d+)MB of dedicated video memory'
    $chosenRe  = [regex] 'Chosen D3D12 Adapter Id = (\d+)'
    $poolRe    = [regex] 'Texture pool size now (\d+) MB'

    $times  = New-Object 'System.Collections.Generic.List[double]'
    $frames = New-Object 'System.Collections.Generic.List[int]'
    $adapters = @{}
    $lastAdapterId = $null
    $chosenId = $null
    $poolMB = $null
    $t0 = $null

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
                                 [System.IO.FileAccess]::Read,
                                 [System.IO.FileShare]::ReadWrite)
    try {
        $sr = New-Object System.IO.StreamReader($fs)
        try {
            while ($null -ne ($line = $sr.ReadLine())) {
                $m = $stampRe.Match($line)
                if ($m.Success) {
                    $t = [datetime]::new(
                        [int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value,
                        [int]$m.Groups[4].Value, [int]$m.Groups[5].Value, [int]$m.Groups[6].Value,
                        [int]$m.Groups[7].Value)
                    if ($null -eq $t0) { $t0 = $t }
                    $times.Add(($t - $t0).TotalSeconds)
                    $frames.Add([int]$m.Groups[8].Value)
                }

                $fm = $foundRe.Match($line)
                if ($fm.Success) {
                    $lastAdapterId = [int]$fm.Groups[1].Value
                    if (-not $adapters.ContainsKey($lastAdapterId)) {
                        $adapters[$lastAdapterId] = [pscustomobject]@{
                            Id = $lastAdapterId; Name = $fm.Groups[2].Value.Trim(); VramMB = 0
                        }
                    }
                    continue
                }

                # "Adapter has NNNNMB of dedicated video memory" always follows the
                # "Found D3D12 adapter N:" line it belongs to.
                if ($null -ne $lastAdapterId) {
                    $vm = $vramRe.Match($line)
                    if ($vm.Success) {
                        $adapters[$lastAdapterId].VramMB = [int]$vm.Groups[1].Value
                        $lastAdapterId = $null
                        continue
                    }
                }

                $cm = $chosenRe.Match($line)
                if ($cm.Success) { $chosenId = [int]$cm.Groups[1].Value }

                $pm = $poolRe.Match($line)
                if ($pm.Success) { $poolMB = [int]$pm.Groups[1].Value }
            }
        } finally { $sr.Dispose() }
    } finally { $fs.Dispose() }

    $chosen = $null
    if ($null -ne $chosenId -and $adapters.ContainsKey($chosenId)) { $chosen = $adapters[$chosenId] }

    [pscustomobject]@{
        Path          = $Path
        Times         = $times
        Frames        = $frames
        Adapter       = $chosen
        TexturePoolMB = $poolMB
    }
}

function Measure-Hitches {
    param([Parameter(Mandatory)] $Facts)

    $times = $Facts.Times; $frames = $Facts.Frames
    if ($times.Count -lt 2) {
        return [pscustomobject]@{ SessionMin = 0; Hitches = 0; PerMin = 0; WorstMs = 0 }
    }
    $span = $times[$times.Count - 1] - $times[0]
    $hitches = 0; $worst = 0.0
    for ($i = 1; $i -lt $times.Count; $i++) {
        $dt = $times[$i] - $times[$i - 1]
        if ($dt -le 0 -or $dt -gt 4.0) { continue }
        $df = ($frames[$i] - $frames[$i - 1]) % 1000
        if ($df -lt 0) { $df += 1000 }
        if ($df -eq 0) { continue }
        if ((($dt / $df) * 1000.0) -gt 16.0 -and $dt -gt 0.030) {
            $hitches++
            if (($dt * 1000.0) -gt $worst) { $worst = $dt * 1000.0 }
        }
    }
    $perMin = 0.0
    if ($span -gt 0) { $perMin = $hitches / ($span / 60.0) }

    [pscustomobject]@{
        SessionMin = [math]::Round($span / 60.0, 1)
        Hitches    = $hitches
        PerMin     = [math]::Round($perMin, 2)
        WorstMs    = [math]::Round($worst, 0)
    }
}

function Get-RecommendedPoolMB {
    param([int] $VramMB)

    if ($VramMB -lt $MinVramMB) { return 0 }        # 0 means "no change recommended"
    $rec = [math]::Round($VramMB * $VramFraction)
    if ($rec -gt $PoolCapMB) { $rec = $PoolCapMB }
    # Round down to a 128 MB boundary so the written value looks deliberate.
    $rec = [int]([math]::Floor($rec / 128) * 128)
    if ($rec -le $StockPoolMB) { return 0 }
    $rec
}

function Get-BlockPattern {
    '(?s)\r?\n?' + [regex]::Escape($BeginMarker) + '.*?' + [regex]::Escape($EndMarker) + '\r?\n?'
}

function Write-IniText {
    param([string] $Path, [string] $Text, [bool] $MakeReadOnly)

    if (Test-Path -LiteralPath $Path) {
        $i = Get-Item -LiteralPath $Path -Force
        if ($i.IsReadOnly) { $i.IsReadOnly = $false }
    }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
    if ($MakeReadOnly) { (Get-Item -LiteralPath $Path -Force).IsReadOnly = $true }
}

function Install-Fix {
    param([int] $PoolMB)

    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    if (Test-Path -LiteralPath $EngineIni) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -LiteralPath $EngineIni -Destination (Join-Path $BackupDir "Engine.ini.$stamp.bak") -Force
    }

    $text = ''
    if (Test-Path -LiteralPath $EngineIni) { $text = [System.IO.File]::ReadAllText($EngineIni) }
    $text = [regex]::Replace($text, (Get-BlockPattern), '')     # idempotent
    $text = $text.TrimEnd("`r", "`n")

    $block = @(
        $BeginMarker
        '[SystemSettings]'
        "r.Streaming.PoolSize=$PoolMB"
        $EndMarker
    ) -join "`r`n"

    if ([string]::IsNullOrWhiteSpace($text)) { $new = $block + "`r`n" }
    else { $new = $text + "`r`n`r`n" + $block + "`r`n" }

    # Read-only is load-bearing, not paranoia: the game rewrites Engine.ini on exit
    # and strips sections it does not recognise, which would silently revert this.
    Write-IniText -Path $EngineIni -Text $new -MakeReadOnly $true
}

function Uninstall-Fix {
    if (-not (Test-Path -LiteralPath $EngineIni)) { return $false }
    $text = [System.IO.File]::ReadAllText($EngineIni)
    $had = $text -match [regex]::Escape($BeginMarker)

    $stripped = [regex]::Replace($text, (Get-BlockPattern), '')
    $stripped = $stripped.TrimEnd("`r", "`n") + "`r`n"
    Write-IniText -Path $EngineIni -Text $stripped -MakeReadOnly $false
    return $had
}

function Test-BlockPresent {
    if (-not (Test-Path -LiteralPath $EngineIni)) { return $false }
    ([System.IO.File]::ReadAllText($EngineIni)) -match [regex]::Escape($BeginMarker)
}

function Test-GameRunning {
    $null -ne (Get-Process -Name 'A2-Win64-Shipping', 'A2' -ErrorAction SilentlyContinue)
}

function Stop-WithMessage {
    param([string] $Message, [string] $Colour = 'Yellow')
    Write-Host ''
    Write-Host "  $Message" -ForegroundColor $Colour
    Write-Host ''
    exit 1
}

# --------------------------------------------------------------------- main

Write-Host ''
Write-Host ('  ORION DRIFT SPECTATOR - STUTTER FIX  v{0}' -f $ToolVersion) -ForegroundColor White
Write-Host '  Unofficial community tool. Edits one user config file. No game files touched.' -ForegroundColor DarkGray

if ($Undo) {
    if (Uninstall-Fix) {
        Write-Host ''
        Write-Host '  Fix removed. Your texture pool goes back to the default on next launch.' -ForegroundColor Green
    } else {
        Write-Host ''
        Write-Host '  Nothing to undo - the fix was not installed.' -ForegroundColor Gray
    }
    if (Test-GameRunning) {
        Write-Host '  The game is running. Restart it for this to take effect.' -ForegroundColor Yellow
    }
    Write-Host ''
    exit 0
}

$log = Get-LatestLog
if ($null -eq $log) {
    Stop-WithMessage 'No Orion Drift log found. Run the spectator client once, then try again.'
}

$facts = Read-A2Log -Path $log
$hitch = Measure-Hitches -Facts $facts

Write-Title 'Your system'
if ($null -eq $facts.Adapter) {
    Write-Row 'graphics card' 'could not detect' 'Yellow'
    Stop-WithMessage 'Could not read your GPU from the log. Run the game once more, then retry.'
}
Write-Row 'graphics card' $facts.Adapter.Name 'White'
Write-Row 'video memory'  ('{0} MB' -f $facts.Adapter.VramMB) 'White'

$current = $facts.TexturePoolMB
if ($null -eq $current) { $current = $StockPoolMB }
Write-Row 'texture pool now' ('{0} MB' -f $current)

Write-Title 'Your last session'
if ($hitch.SessionMin -lt 1) {
    Write-Row 'session length' 'too short to measure' 'DarkGray'
} else {
    Write-Row 'session length' ('{0} min' -f $hitch.SessionMin)
    Write-Row 'stutters detected' ('{0}  ({1} per minute)' -f $hitch.Hitches, $hitch.PerMin)
    Write-Row 'worst freeze' ('{0} ms' -f $hitch.WorstMs)
}
Write-Host '    (this counts only stutters the log happens to catch - it is a floor, not a total)' -ForegroundColor DarkGray

$recommended = Get-RecommendedPoolMB -VramMB $facts.Adapter.VramMB

# Re-running the tool is encouraged, so the common case is "already done". Also
# refuse to offer a change too small to be worth a config edit and a restart - a
# 4 GB card computes to 1536 MB, a 2% bump that would be dressed up as a fix.
$MinimumGain = 1.25
if ($recommended -ne 0 -and $recommended -lt ($current * $MinimumGain)) { $recommended = 0 }

Write-Title 'Recommendation'
if ($recommended -eq 0) {
    if ($current -le $StockPoolMB) {
        Write-Row 'verdict' 'no change needed' 'Green'
        Write-Host ''
        Write-Host ('  Your card has {0} MB of video memory. The default {1} MB pool is' -f $facts.Adapter.VramMB, $current)
        Write-Host '  already a reasonable size for it, so this fix has nothing useful to do.'
        Write-Host '  Raising it further would take memory away from other things and could'
        Write-Host '  make performance worse. Leaving your settings alone.'
        Write-Host ''
        Write-Host '  This tool only helps cards with memory to spare. Yours is not the problem.' -ForegroundColor DarkGray
    } else {
        Write-Row 'verdict' 'already applied' 'Green'
        Write-Host ''
        Write-Host ('  Your texture pool is already {0} MB, at or above what this tool would' -f $current)
        Write-Host '  set for your card. Nothing to do - you are good to go.'
        if (-not (Test-BlockPresent)) {
            Write-Host ''
            Write-Host '  Heads up: that value is live in the game but this tool is not currently' -ForegroundColor Yellow
            Write-Host '  installed in your config. If the pool drops back to 1500 MB later, run' -ForegroundColor Yellow
            Write-Host '  this tool again.' -ForegroundColor Yellow
        }
    }
    Write-Host ''
    exit 0
}

Write-Row 'texture pool now'   ('{0} MB' -f $current)
Write-Row 'would change to'    ('{0} MB' -f $recommended) 'Green'
Write-Row 'that is'            ('{0:n1}x bigger' -f ($recommended / [double]$current)) 'Green'

Write-Host ''
Write-Host '  What this does: the PC build pins the texture streaming pool to 1500 MB, a' -ForegroundColor Gray
Write-Host '  value carried over from the Quest version. On a PC card with spare memory that' -ForegroundColor Gray
Write-Host '  forces textures to be thrown away and reloaded constantly as the camera moves,' -ForegroundColor Gray
Write-Host '  which is felt as hitching when you fly somewhere new.' -ForegroundColor Gray
Write-Host ''
Write-Host '  Honest about the evidence: this was measured on one machine (32 GB card),' -ForegroundColor DarkYellow
Write-Host '  where stutters dropped from roughly 1.1/min to 0.1/min. How much it helps you' -ForegroundColor DarkYellow
Write-Host '  depends on your hardware, and on a smaller card the gain will be smaller.' -ForegroundColor DarkYellow
Write-Host ''
Write-Host ('  It writes one line to: {0}' -f $EngineIni) -ForegroundColor DarkGray
Write-Host '  A backup is saved first, and Undo.bat reverses it completely.' -ForegroundColor DarkGray

if (Test-BlockPresent) {
    Write-Host ''
    Write-Host '  Note: the fix is already installed. Re-applying will update the value.' -ForegroundColor Cyan
}

if (-not $NonInteractive) {
    Write-Host ''
    $answer = Read-Host '  Apply this fix? (Y/N)'
    if ($answer -notmatch '^[Yy]') {
        Write-Host ''
        Write-Host '  Cancelled. Nothing was changed.' -ForegroundColor Gray
        Write-Host ''
        exit 0
    }
}

Install-Fix -PoolMB $recommended

Write-Host ''
Write-Host ('  Done. Texture pool set to {0} MB.' -f $recommended) -ForegroundColor Green
Write-Host ''
if (Test-GameRunning) {
    Write-Host '  The game is currently running - CLOSE IT AND REOPEN IT for this to apply.' -ForegroundColor Yellow
} else {
    Write-Host '  Launch Orion Drift normally. The fix is active from now on.' -ForegroundColor White
}
Write-Host ''
Write-Host '  Run this tool again any time to check it is still applied.' -ForegroundColor DarkGray
Write-Host '  Run Undo.bat to remove it.' -ForegroundColor DarkGray
Write-Host ''
