#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ═══════════════════════════════════════════════════════════════════════════════
#  SYMBOLS
# ═══════════════════════════════════════════════════════════════════════════════
$sym = @{
    Up    = [char]::ConvertFromUtf32(0x2191)   # ↑
    Down  = [char]::ConvertFromUtf32(0x2193)   # ↓
    Enter = [char]::ConvertFromUtf32(0x23CE)   # ⏎
    Check = [char]::ConvertFromUtf32(0x25CF)   # ● filled
    Empty = [char]::ConvertFromUtf32(0x25CB)   # ○ empty
    OK    = [char]::ConvertFromUtf32(0x2714)   # ✔
    Fail  = [char]::ConvertFromUtf32(0x2718)   # ✘
}

# ═══════════════════════════════════════════════════════════════════════════════
#  THEME — auto-detects Windows dark / light mode via registry
# ═══════════════════════════════════════════════════════════════════════════════
function Get-IsDarkMode {
    try {
        $val = Get-ItemPropertyValue `
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
            -Name AppsUseLightTheme -ErrorAction Stop
        return ($val -eq 0)
    }
    catch { return $true }
}

$isDark = Get-IsDarkMode

# 256-color ANSI palette — two variants, identical semantics
$c = if ($isDark) {
    @{
        Banner    = 77    # bright teal-green   — header art
        Accent    = 215   # warm amber          — hints, highlights
        Checked   = 114   # sage green          — selected items
        Normal    = 253   # near-white          — unselected items
        Cursor_Fg = 16    # black               — text on cursor row
        Cursor_Bg = 215   # amber               — cursor row background
        Dim       = 240   # muted gray          — secondary info
        Error     = 203   # soft red
        Success   = 82    # bright green
        Border    = 238   # dark gray           — dividers
    }
} else {
    @{
        Banner    = 22    # dark forest green
        Accent    = 130   # burnt orange
        Checked   = 28    # forest green
        Normal    = 234   # near-black
        Cursor_Fg = 231   # white
        Cursor_Bg = 130   # burnt orange
        Dim       = 244   # medium gray
        Error     = 124   # deep red
        Success   = 28    # forest green
        Border    = 250   # light gray
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ANSI HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
$ESC = [char]27

# Write styled text with optional foreground/background 256-color codes.
# -FillBg: clears EOL *before* resetting — so the background extends to the
#          right edge of the terminal (used for the cursor-highlighted row).
function Write-Styled {
    param(
        [string]$Text,
        [int]$Fg        = -1,
        [int]$Bg        = -1,
        [switch]$Bold,
        [switch]$NoNewline,
        [switch]$FillBg
    )
    $seq = [System.Collections.Generic.List[string]]::new()
    if ($Bold)     { $seq.Add('1') }
    if ($Fg -ge 0) { $seq.Add("38;5;$Fg") }
    if ($Bg -ge 0) { $seq.Add("48;5;$Bg") }

    $open = if ($seq.Count) { "$ESC[$($seq -join ';')m" } else { '' }

    # FillBg: ESC[0K before reset  → EOL filled with current BG
    # Normal: reset first, ESC[0K → EOL cleared with default BG (erases ghosts)
    $out = if ($FillBg) {
        "${open}${Text}$ESC[0K$ESC[0m"
    } else {
        "${open}${Text}$ESC[0m$ESC[0K"
    }

    if ($NoNewline) { Write-Host $out -NoNewline }
    else            { Write-Host $out }
}

# Project run header — name embedded inside dashes:
#   -- project-name -------------------------------------------------
function Write-ProjectHeader {
    param([string]$Name, [int]$FgColor)
    $width = [Math]::Max(20, [Math]::Min([Console]::WindowWidth - 4, 72))
    $label = " $Name "

    # Center calculation
    $left  = [Math]::Floor(($width - $label.Length) / 2)
    $right = [Math]::Max(0, $width - $left - $label.Length)
    Write-Styled ''
    Write-Styled ("  " + ("~" * $left) + $label + ("~" * $right)) -Fg $FgColor -Bold
    Write-Styled ''
}

# Section header — title centered inside equals signs:
#   =================== SUMMARY ====================================
function Write-SectionHeader {
    param([string]$Title, [int]$FgColor)
    $width = [Math]::Max(20, [Math]::Min([Console]::WindowWidth - 4, 72))
    $label = " $Title "
    $left  = [Math]::Max(0, [int](($width - $label.Length) / 2))
    $right = [Math]::Max(0, $width - $left - $label.Length)
    Write-Styled ("  " + ("=" * $left) + $label + ("=" * $right)) -Fg $FgColor -Bold
}

# ═══════════════════════════════════════════════════════════════════════════════
#  PROJECTS
# ═══════════════════════════════════════════════════════════════════════════════
$projects = @(
    Get-ChildItem -Directory -Exclude '.*' |
    Select-Object -ExpandProperty Name |
    Sort-Object
)

if ($projects.Count -eq 0) {
    Write-Styled "  No subdirectories found in '$(Get-Location)'." -Fg $c.Error
    exit 1
}

# Saved selection persists for the whole session (S to save, Z to restore)
$script:savedIndices   = [System.Collections.Generic.List[int]]::new()
$script:commandHistory = [System.Collections.Generic.List[string]]::new()

# ═══════════════════════════════════════════════════════════════════════════════
#  BANNER
# ═══════════════════════════════════════════════════════════════════════════════
$bannerArt = @'
 __    __     __  __     __         ______   __     ______     __  __     ______     ______
/\ "-./  \   /\ \/\ \   /\ \       /\__  _\ /\ \   /\  ___\   /\_\_\_\   /\  ___\   /\  ___\
\ \ \-./\ \  \ \ \_\ \  \ \ \____  \/_/\ \/ \ \ \  \ \  __\   \/_/\_\/_  \ \  __\   \ \ \____
 \ \_\ \ \_\  \ \_____\  \ \_____\    \ \_\  \ \_\  \ \_____\   /\_\/\_\  \ \_____\  \ \_____\
  \/_/  \/_/   \/_____/   \/_____/     \/_/   \/_/   \/_____/   \/_/\/_/   \/_____/   \/_____/
'@

function Write-Banner {
    param([string[]]$Hints = @())
    Write-Styled $bannerArt -Fg $c.Banner
    Write-Styled ''
    Write-Styled "  Eng. Ayah Refai" -Fg $c.Dim -NoNewline
    Write-Styled "   |   $(Get-Location)" -Fg $c.Dim
    Write-Host ""
    foreach ($h in $Hints) {
        Write-Styled "  $h" -Fg $c.Accent
    }
    Write-Styled ''
}

# ═══════════════════════════════════════════════════════════════════════════════
#  INTERACTIVE MULTI-SELECT MENU
#
#  Fix: banner is printed ONCE before the loop; subsequent iterations jump
#  the cursor back to $menuTopRow and overwrite lines in-place — no Clear-Host,
#  no flicker.
# ═══════════════════════════════════════════════════════════════════════════════
function Show-Menu {
    param([string[]]$Options)

    $cursor = 0
    # HashSet gives O(1) Contains / Add / Remove for toggle operations
    $selected = [System.Collections.Generic.HashSet[int]]::new()

    $hints = @(
        "$($sym.Up)$($sym.Down) Navigate   Space Toggle   A All   D Clear",
        "S Save   Z Restore   $($sym.Enter) Run   Esc Cancel"
    )

    Clear-Host
    Write-Banner -Hints $hints
    $menuTopRow = [Console]::CursorTop   # cursor row of the first item line
    [Console]::CursorVisible = $false

    try {
        while ($true) {
            # ── Overwrite item rows in-place (cursor repositioning, not Clear-Host) ──
            [Console]::SetCursorPosition(0, $menuTopRow)

            for ($i = 0; $i -lt $Options.Count; $i++) {
                $isFocused = ($i -eq $cursor)
                $isChecked = $selected.Contains($i)
                $mark      = if ($isChecked) { $sym.Check } else { $sym.Empty }
                $label     = "  $mark  $($Options[$i])"

                if ($isFocused) {
                    # FillBg: highlight extends to right edge of terminal
                    Write-Styled $label -Fg $c.Cursor_Fg -Bg $c.Cursor_Bg -Bold -FillBg
                } elseif ($isChecked) {
                    Write-Styled $label -Fg $c.Checked
                } else {
                    Write-Styled $label -Fg $c.Normal
                }
            }

            # ── Status bar ───────────────────────────────────────────────────
            Write-Styled ''
            $selCount    = $selected.Count
            $statusColor = if ($selCount -gt 0) { $c.Accent } else { $c.Dim }
            $noSelHint   = if ($selCount -eq 0) { '  (nothing selected)' } else { '' }
            Write-Styled "  Selected: $selCount / $($Options.Count)$noSelHint  " -Fg $statusColor

            # ── Read next keypress ────────────────────────────────────────────
            $ki = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

            switch ($ki.VirtualKeyCode) {
                38 { # ↑ — move up, wrap
                    $cursor = if ($cursor -gt 0) { $cursor - 1 } else { $Options.Count - 1 }
                }
                40 { # ↓ — move down, wrap
                    $cursor = if ($cursor -lt $Options.Count - 1) { $cursor + 1 } else { 0 }
                }
                32 { # Space — toggle current item
                    if (-not $selected.Remove($cursor)) { [void]$selected.Add($cursor) }
                }
                65 { # A — select all
                    0..($Options.Count - 1) | ForEach-Object { [void]$selected.Add($_) }
                }
                68 { # D — deselect all
                    $selected.Clear()
                }
                83 { # S — save current selection for this session
                    $script:savedIndices = [System.Collections.Generic.List[int]]($selected | Sort-Object)
                    # Brief inline feedback — overwrite the status bar line
                    [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
                    Write-Styled "  Saved $($selected.Count) item(s).  " -Fg $c.Success
                    Start-Sleep -Milliseconds 600
                }
                90 { # Z — restore saved selection
                    $selected.Clear()
                    foreach ($idx in $script:savedIndices) { [void]$selected.Add($idx) }
                }
                13 { # Enter — confirm and return sorted indices
                    if ($selected.Count -gt 0) {
                        return [int[]]($selected | Sort-Object)
                    }
                }
                27 { # Esc — cancel, return to command input
                    return @()
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  COMMAND EXECUTION WITH PER-PROJECT SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
function Invoke-MultiExec {
    param(
        [string]$CommandLine,
        [int[]]$ProjectIndices
    )

    $commands = $CommandLine -split '&&' |
                ForEach-Object { $_.Trim() } |
                Where-Object   { $_ -ne '' }

    $results  = [System.Collections.Generic.List[hashtable]]::new()
    $rootPath = (Get-Location).Path   # absolute root — safe anchor for every iteration

    foreach ($idx in $ProjectIndices) {
        $name  = $projects[$idx]
        $start = Get-Date
        $ok    = $true

        Write-ProjectHeader -Name $name -FgColor $c.Accent

        # cd into project folder
        Write-Styled "  > cd ./$name" -Fg $c.Dim
        Set-Location (Join-Path $rootPath $name)
        try {
            foreach ($cmd in $commands) {
                Write-Styled "  > $cmd" -Fg $c.Dim
                try {
                    $global:LASTEXITCODE = 0
                    cmd /c $cmd
                    if ($LASTEXITCODE -ne 0) { $ok = $false }
                }
                catch {
                    Write-Styled "  Error: $_" -Fg $c.Error
                    $ok = $false
                }
            }
        }
        finally {
            # cd back to root after each project
            Write-Styled "  > cd ../" -Fg $c.Dim
            Set-Location $rootPath
        }

        $elapsed = (Get-Date) - $start
        $results.Add(@{ Name = $name; OK = $ok; Elapsed = $elapsed })
    }

    # ── Execution summary ─────────────────────────────────────────────────────
    Write-Styled ''
    Write-SectionHeader -Title 'SUMMARY' -FgColor $c.Banner

    $passed = 0
    $failed = 0
    foreach ($r in $results) {
        $icon  = if ($r.OK) { $sym.OK }   else { $sym.Fail }    # keep separate — mixing ; $passed++ in the same if-expression makes $icon an array
        $color = if ($r.OK) { $c.Success } else { $c.Error }
        if ($r.OK) { $passed++ } else { $failed++ }
        $time  = $r.Elapsed.ToString('mm\:ss')
        Write-Styled "  $icon  $($r.Name.PadRight(35)) $time" -Fg $color
    }

    Write-Styled ''
    $totalColor = if ($failed -eq 0) { $c.Success } else { $c.Error }
    Write-Styled "  $passed passed, $failed failed  " -Fg $totalColor
    Write-Styled ''
}

# ═══════════════════════════════════════════════════════════════════════════════
#  COMMAND INPUT SCREEN
# ═══════════════════════════════════════════════════════════════════════════════
function Get-UserCommand {
    Clear-Host
    Write-Banner -Hints @("$($sym.Up)$($sym.Down) Browse history in the input prompt")
    Write-Styled ''

    if ($script:commandHistory.Count -gt 0) {
        Write-Styled '  Recent commands:' -Fg $c.Dim
        $script:commandHistory | Select-Object -Last 5 | ForEach-Object {
            Write-Styled "    $($sym.Check) $_" -Fg $c.Dim
        }
        Write-Styled ''
    }

    $cmd = (Read-Host '  Enter commands (separate with &&)').Trim()

    if ($cmd -and ($script:commandHistory.Count -eq 0 -or $script:commandHistory[-1] -ne $cmd)) {
        $script:commandHistory.Add($cmd)
    }

    return $cmd
}

# ═══════════════════════════════════════════════════════════════════════════════
#  MAIN LOOP  (loop instead of recursion — avoids call-stack overflow)
# ═══════════════════════════════════════════════════════════════════════════════
function Start-MultiExec {
    while ($true) {
        try {
            $cmd = Get-UserCommand
            if ([string]::IsNullOrWhiteSpace($cmd)) { continue }

            $indices = @(Show-Menu -Options $projects)   # @() ensures array even for 1 item
            if ($indices.Count -eq 0) { continue }

            Clear-Host
            Write-Banner -Hints @("Running: $cmd")
            Invoke-MultiExec -CommandLine $cmd -ProjectIndices $indices

            Write-Styled "  Press any key to run again, or Ctrl+C to exit..." -Fg $c.Dim
            [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

        }
        catch [System.Management.Automation.PipelineStoppedException] {
            # Ctrl+C
            Write-Styled "`n  Goodbye!" -Fg $c.Accent
            break
        }
        catch {
            Write-Styled "`n  Unexpected error: $_" -Fg $c.Error
            Write-Styled "  Press any key to continue..." -Fg $c.Dim
            [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    }
}

Start-MultiExec
