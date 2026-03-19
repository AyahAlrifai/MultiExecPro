#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ═══════════════════════════════════════════════════════════════════════════════
#  SYMBOLS
# ═══════════════════════════════════════════════════════════════════════════════
$sym = @{
    Up       = [char]::ConvertFromUtf32(0x2191)   # ↑
    Down     = [char]::ConvertFromUtf32(0x2193)   # ↓
    Enter    = [char]::ConvertFromUtf32(0x23CE)   # ⏎
    Check    = [char]::ConvertFromUtf32(0x25CF)   # ● filled
    Empty    = [char]::ConvertFromUtf32(0x25CB)   # ○ empty
    OK       = [char]::ConvertFromUtf32(0x2714)   # ✔
    Fail     = [char]::ConvertFromUtf32(0x2718)   # ✘
    MoreUp   = [char]::ConvertFromUtf32(0x25B4)   # ▴ scroll-up indicator
    MoreDown = [char]::ConvertFromUtf32(0x25BE)   # ▾ scroll-down indicator
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

$c = if ($isDark) {
    @{
        Banner    = 211
        Accent    = 220
        Checked   = 220
        Normal    = 250
        Cursor_Fg = 235
        Cursor_Bg = 220
        Dim       = 241
        Error     = 196
        Success   = 82
        Border    = 237
        Key_Fg    = 235
        Key_Bg    = 220
    }
} else {
    @{
        Banner    = 161
        Accent    = 130
        Checked   = 136
        Normal    = 236
        Cursor_Fg = 231
        Cursor_Bg = 130
        Dim       = 245
        Error     = 160
        Success   = 34
        Border    = 252
        Key_Fg    = 231
        Key_Bg    = 130
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ANSI HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
$ESC = [char]27

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

    $out = if ($FillBg) {
        "${open}${Text}$ESC[0K$ESC[0m"
    } else {
        "${open}${Text}$ESC[0m$ESC[0K"
    }

    if ($NoNewline) { Write-Host $out -NoNewline }
    else            { Write-Host $out }
}

function Write-ProjectHeader {
    param([string]$Name, [int]$FgColor)
    $width = [Math]::Max(20, [Math]::Min([Console]::WindowWidth - 4, 72))
    $label = " $Name "
    $left  = [Math]::Floor(($width - $label.Length) / 2)
    $right = [Math]::Max(0, $width - $left - $label.Length)
    Write-Styled ''
    Write-Styled ("  " + ("~" * $left) + $label + ("~" * $right)) -Fg $FgColor -Bold
    Write-Styled ''
}

function Write-SectionHeader {
    param([string]$Title, [int]$FgColor)
    $width = [Math]::Max(20, [Math]::Min([Console]::WindowWidth - 4, 72))
    $label = " $Title "
    $left  = [Math]::Max(0, [int](($width - $label.Length) / 2))
    $right = [Math]::Max(0, $width - $left - $label.Length)
    Write-Styled ("  " + ("=" * $left) + $label + ("=" * $right)) -Fg $FgColor -Bold
}

function Write-KeyBar {
    param([hashtable[]]$Entries)
    $line = '  '
    foreach ($e in $Entries) {
        $k     = $e.Key
        $d     = $e.Desc
        $line += "$ESC[48;5;$($c.Key_Bg)m$ESC[38;5;$($c.Key_Fg)m$ESC[1m $k $ESC[0m $ESC[38;5;$($c.Dim)m$d$ESC[0m   "
    }
    Write-Host "$line$ESC[0K"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  SESSION STATE  (no longer a module-level $projects — loaded fresh each run)
# ═══════════════════════════════════════════════════════════════════════════════
$script:savedIndices   = [System.Collections.Generic.List[int]]::new()
$script:commandHistory = [System.Collections.Generic.List[string]]::new()

# ── Helper: load projects from CURRENT directory ─────────────────────────────
function Get-Projects {
    @(
        Get-ChildItem -Directory -Exclude '.*' |
        Select-Object -ExpandProperty Name |
        Sort-Object
    )
}

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
# ═══════════════════════════════════════════════════════════════════════════════
function Show-Menu {
    param([string[]]$Options)

    $cursor = 0
    $offset = 0

    $selectedSet  = [System.Collections.Generic.HashSet[int]]::new()
    $selectedList = [System.Collections.Generic.List[int]]::new()

    Clear-Host
    Write-Banner

    $menuTopRow = [Console]::CursorTop
    [Console]::CursorVisible = $false

    try {
        while ($true) {

            $windowLastRow = [Console]::WindowTop + [Console]::WindowHeight - 1
            $height = [Math]::Max(3, $windowLastRow - $menuTopRow - 3)

            if ($cursor -lt $offset)           { $offset = $cursor }
            if ($cursor -ge $offset + $height) { $offset = $cursor - $height + 1 }

            [Console]::SetCursorPosition(0, $menuTopRow)

            for ($row = 0; $row -lt $height; $row++) {
                $i = $offset + $row
                if ($i -ge $Options.Count) { Write-Styled ''; continue }

                $isFocused = ($i -eq $cursor)
                $isChecked = $selectedSet.Contains($i)
                $mark      = if ($isChecked) { $sym.Check } else { $sym.Empty }
                $label     = "  $mark  $($Options[$i])"

                if ($isFocused) {
                    Write-Styled $label -Fg $c.Cursor_Fg -Bg $c.Cursor_Bg -Bold -FillBg
                } elseif ($isChecked) {
                    Write-Styled $label -Fg $c.Checked
                } else {
                    Write-Styled $label -Fg $c.Normal
                }
            }

            $selCount   = $selectedSet.Count
            $statColor  = if ($selCount -gt 0) { $c.Accent } else { $c.Dim }
            $above      = $offset
            $below      = [Math]::Max(0, $Options.Count - $offset - $height)
            $scrollHint = ''
            if ($above -gt 0) { $scrollHint += "   $($sym.MoreUp) $above" }
            if ($below -gt 0) { $scrollHint += "   $($sym.MoreDown) $below" }
            Write-Styled "  $($sym.Check) $selCount of $($Options.Count) selected$scrollHint" -Fg $statColor

            Write-KeyBar @(
                @{Key="$($sym.Up)$($sym.Down)"; Desc='Move'}
                @{Key='Space';                  Desc='Select'}
                @{Key='A';                      Desc='All'}
                @{Key='D';                      Desc='Clear'}
                @{Key='S';                      Desc='Save'}
                @{Key='Z';                      Desc='Restore'}
                @{Key="$($sym.Enter)";          Desc='Run'}
                @{Key='Esc';                    Desc='Exit'}
            )

            $ki = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

            switch ($ki.VirtualKeyCode) {
                38 { $cursor = if ($cursor -gt 0) { $cursor - 1 } else { $Options.Count - 1 } }
                40 { $cursor = if ($cursor -lt $Options.Count - 1) { $cursor + 1 } else { 0 } }
                32 {
                    if ($selectedSet.Add($cursor)) {
                        $selectedList.Add($cursor)
                    } else {
                        [void]$selectedSet.Remove($cursor)
                        $pos = $selectedList.IndexOf($cursor)
                        if ($pos -ge 0) { $selectedList.RemoveAt($pos) }
                    }
                }
                65 {
                    $selectedSet.Clear(); $selectedList.Clear()
                    0..($Options.Count - 1) | ForEach-Object {
                        [void]$selectedSet.Add($_); $selectedList.Add($_)
                    }
                }
                68 { $selectedSet.Clear(); $selectedList.Clear() }
                83 {
                    $script:savedIndices = [System.Collections.Generic.List[int]]($selectedList)
                    Write-Styled "  Saved $($selectedList.Count) items" -Fg $c.Success
                    Start-Sleep -Milliseconds 600
                }
                90 {
                    $selectedSet.Clear(); $selectedList.Clear()
                    foreach ($idx in $script:savedIndices) {
                        [void]$selectedSet.Add($idx); $selectedList.Add($idx)
                    }
                }
                13 { if ($selectedList.Count -gt 0) { return [int[]]$selectedList } }
                27 { return @() }
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
        [int[]]$ProjectIndices,
        [string[]]$ProjectNames,
        [string]$RootPath
    )

    $commands = $CommandLine -split '&&' |
                ForEach-Object { $_.Trim() } |
                Where-Object   { $_ -ne '' }

    $results = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($idx in $ProjectIndices) {
        $name  = $ProjectNames[$idx]
        $start = Get-Date
        $ok    = $true

        Write-ProjectHeader -Name $name -FgColor $c.Accent

        Write-Styled "  > cd ./$name" -Fg $c.Dim
        Set-Location (Join-Path $RootPath $name)
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
            Write-Styled "  > cd ../" -Fg $c.Dim
            Set-Location $RootPath
        }

        $elapsed      = (Get-Date) - $start
        $resultIcon   = if ($ok) { $sym.OK    } else { $sym.Fail  }
        $resultColor  = if ($ok) { $c.Success } else { $c.Error   }
        $resultStatus = if ($ok) { 'Success'  } else { 'Failed'   }
        $resultTime   = $elapsed.ToString('mm\:ss')
        Write-Styled "  $resultIcon  $name  [$resultStatus]  $resultTime" -Fg $resultColor -Bold
        $results.Add(@{ Name = $name; OK = $ok; Elapsed = $elapsed })
    }

    Write-Styled ''
    Write-SectionHeader -Title 'SUMMARY' -FgColor $c.Banner

    $passed = 0; $failed = 0
    foreach ($r in $results) {
        $icon  = if ($r.OK) { $sym.OK    } else { $sym.Fail  }
        $color = if ($r.OK) { $c.Success } else { $c.Error   }
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
#  MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════
function Start-MultiExec {
    while ($true) {
        try {
            # ── Load projects fresh from current directory each iteration ──
            $rootPath = (Get-Location).Path
            $projects = Get-Projects

            if ($projects.Count -eq 0) {
                Write-Styled "  No subdirectories found in '$rootPath'." -Fg $c.Error
                Write-Styled "  Please run multiExecPro from a folder that contains project subfolders." -Fg $c.Dim
                Write-Styled "  Example:  cd D:\my-projects  then  multiExecPro" -Fg $c.Dim
                Write-Styled ''
                Write-Styled "  Press any key to exit..." -Fg $c.Dim
                [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                break
            }

            $cmd = Get-UserCommand
            if ([string]::IsNullOrWhiteSpace($cmd)) { continue }

            $indices = @(Show-Menu -Options $projects)
            if ($indices.Count -eq 0) { continue }

            Clear-Host
            Write-Banner -Hints @("Running: $cmd")
            Invoke-MultiExec -CommandLine $cmd -ProjectIndices $indices -ProjectNames $projects -RootPath $rootPath

            Write-Styled "  Press any key to run again, or Ctrl+C to exit..." -Fg $c.Dim
            [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

        }
        catch [System.Management.Automation.PipelineStoppedException] {
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
