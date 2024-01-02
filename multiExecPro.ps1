$primaryColor = 45
$secondaryColor = 204
$whiteBlackColor = 255
$projects = Get-ChildItem -Directory -Exclude .* | ForEach-Object { $_.Name }
$upArrow = [char]::ConvertFromUtf32(0x2191)
$downArrow = [char]::ConvertFromUtf32(0x2193)
$enterIcon = [char]::ConvertFromUtf32(0x23CE)
$spaceIcon = [char]::ConvertFromUtf32(0x0020)
$bannerText = @"
 __    __     __  __     __         ______   __     ______     __  __     ______     ______    
/\ "-./  \   /\ \/\ \   /\ \       /\__  _\ /\ \   /\  ___\   /\_\_\_\   /\  ___\   /\  ___\   
\ \ \-./\ \  \ \ \_\ \  \ \ \____  \/_/\ \/ \ \ \  \ \  __\   \/_/\_\/_  \ \  __\   \ \ \____  
 \ \_\ \ \_\  \ \_____\  \ \_____\    \ \_\  \ \_\  \ \_____\   /\_\/\_\  \ \_____\  \ \_____\ 
  \/_/  \/_/   \/_____/   \/_____/     \/_/   \/_/   \/_____/   \/_/\/_/   \/_____/   \/_____/ 

"@

$bannerInfo2 = @"

                                              [ space ] Select/deselect option      [ $enterIcon ] Execution
  Eng. Ayah Refai
                                              [ $upArrow$downArrow ] Move between options

"@

$bannerInfo1 = @"

  Eng. Ayah Refai                           [ $upArrow$downArrow ] Get pervious commands

"@

$line = @"
_o_o_o_o_o_o_o_o_o_o_o_o_o_o_o_o_o_o_o_
"@

function Show-Menu {
    param (
        [string[]]$Options
    )

    $selectedOption = 0
    $selectedItems = @{}
    $list = @();
    while ($true) {
        try {
            Clear-Host
            Write-ColorText $($bannerText+$bannerInfo2) -Color $primaryColor
            for ($i = 0; $i -lt $Options.Length; $i++) {
                if ($i -eq $selectedOption) {
                    if($selectedItems.ContainsKey($i)) {
                        Write-ColorTextBackground " [X] $($Options[$i])" -ForegroundColor 0 -BackgroundColor $secondaryColor
                    } else {
                        Write-ColorTextBackground " [ ] $($Options[$i])" -ForegroundColor 0 -BackgroundColor $secondaryColor
                    }
                } else {
                    if($selectedItems.ContainsKey($i)) {
                        Write-ColorText " [X] $($Options[$i])" -Color $secondaryColor
                    } else {
                       Write-ColorText " [ ] $($Options[$i])" -Color $whiteBlackColor
                    }
                }
            }

            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode

            switch ($key) {
                38 {
                    Clear-Host
                    if($selectedOption -ne 0) {
                        $selectedOption = ($selectedOption - 1) % $Options.Length
                    } else {
                        $selectedOption = $Options.Length - 1
                    }
                }
                40 {
                    Clear-Host
                    if($selectedOption -ne $($Options.Length-1)) {
                        $selectedOption = ($selectedOption + 1) % $Options.Length
                    } else {
                        $selectedOption = 0
                    }
                }
                13 {
                    return $list
                }
                32 {
                    Clear-Host
                    $isExist = -1;
                    $newList = @()
                    for ($j = 0; $j -lt $list.Length; $j++) {
                        if($($list[$j]) -ne $selectedOption) {
                            $newList += $($list[$j]);
                        } else {
                             $isExist = 1;
                        }
                    }
                    $list = $newList[0..($newList.Length - 1)]
                    if($isExist -eq -1) {
                        $list += $selectedOption
                    }

                    if($selectedItems.ContainsKey($selectedOption)) {
                        $selectedItems.Remove($selectedOption)
                    } else {
                        $selectedItems[$selectedOption] = $($Options[$selectedOption])
                    }
                }
            }
        } catch {
            break
        }
    }
}

function Write-ColorText {
    param (
        [string]$Text,
        [string]$Color
    )

    $ESC = [char]27
    Write-Host "$ESC[38;5;$($Color)m${Text}$ESC[0m"
}

function Write-ColorTextBackground {
    param (
        [string]$Text,
        [int]$ForegroundColor,
        [int]$BackgroundColor
    )
    $ESC = [char]27
    Write-Host "$ESC[38;5;$($ForegroundColor)m$ESC[48;5;$($BackgroundColor)m${Text}$ESC[0m"
}

function Start_Script {
    try {
        Clear-Host
        Write-ColorText $($bannerText+$bannerInfo1) -Color $primaryColor
        $userCommands = Read-Host -Prompt "Enter your commands separated with && "
        $selectedItems = Show-Menu -Options $projects
        for ($i = 0; $i -lt $selectedItems.Length; $i++) {
            Write-ColorText $($line + " $($projects[$($selectedItems[$i])]) " + $line) -Color $primaryColor
            Write-ColorText $('cd ./'+$($projects[$($selectedItems[$i])])) -Color $secondaryColor
            cd $($projects[$($selectedItems[$i])])
            ##############################################################################
            $commands =$userCommands -split "&&"
            foreach ($command in $commands) {
                $trimmedCommand = $command.Trim()
                Write-ColorText "$trimmedCommand" -Color $secondaryColor
                Invoke-Expression -Command $trimmedCommand
            }
            ##############################################################################
            Write-ColorText 'cd ../' -Color $secondaryColor
            cd ../
        }
        $userInput = Read-Host -Prompt "Do you want to continue? [N] No"
        if($userInput -eq 'N' -or $userInput -eq 'n') {
            return;
        }
        Start_Script
    } catch {
        Write-Host "Script terminated."
    }
}

Start_Script
