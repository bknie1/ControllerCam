# Links the HUD's module folders into the game's AddOns folder, for playing from this checkout.
# The game reads addons one folder deep, so each module (ControllerCam_HUD_Fishing and the others) needs a
# junction of its own beside the ControllerCam and ControllerCam_HUD ones. Makes only the ones missing; touches
# nothing else (an existing folder or junction of that name is left as it is, and said).
#
#   powershell -ExecutionPolicy Bypass -File docs\link_modules.ps1 -AddOns "D:\World of Warcraft\_forever_\Interface\AddOns"
#
# -AddOns: the game's Interface\AddOns folder. -WhatIf: only say what would be made.
param(
    [Parameter(Mandatory = $true)][string]$AddOns,
    [switch]$WhatIf
)

$repo = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $AddOns -PathType Container)) {
    Write-Error "No such folder: $AddOns"
    exit 1
}

$modules = Get-ChildItem -LiteralPath $repo -Directory -Filter "ControllerCam_HUD_*" |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName ($_.Name + ".toc")) }
foreach ($m in $modules) {
    $link = Join-Path $AddOns $m.Name
    if (Test-Path -LiteralPath $link) {
        $item = Get-Item -LiteralPath $link -Force
        if ($item.LinkType -eq "Junction" -and $item.Target -contains $m.FullName) {
            Write-Output "already linked: $($m.Name)"
        } else {
            Write-Output "left as it is (a folder or link of that name is already there): $link"
        }
        continue
    }
    if ($WhatIf) {
        Write-Output "would link: $link -> $($m.FullName)"
    } else {
        New-Item -ItemType Junction -Path $link -Target $m.FullName | Out-Null
        Write-Output "linked: $link -> $($m.FullName)"
    }
}
