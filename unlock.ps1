$pass = Read-Host "Enter password to restore system"

if ($pass -ne "SorrySahindu") {
    Write-Host "Wrong password."
    exit
}

$base = "$env:ProgramData\WinGuard"
$guard = "$base\guard.ps1"
$heal = "$base\heal.ps1"
$notice = "$base\notice.ps1"
$original = "$base\original_wallpaper.jpg"

# Stop guard immediately
Unregister-ScheduledTask -TaskName "WinGuard" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "WinGuard-Heal" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "WinGuard-Notice" -Confirm:$false -ErrorAction SilentlyContinue

# Kill any running guard process
Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*WinGuard*" } | Stop-Process -Force

# Restore original wallpaper if exists
if (Test-Path $original) {
    Copy-Item $original "$env:USERPROFILE\Pictures\original_wallpaper_restored.jpg" -Force
    Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value "$env:USERPROFILE\Pictures\original_wallpaper_restored.jpg"
    rundll32.exe user32.dll, UpdatePerUserSystemParameters
}

# Remove WinGuard folder
Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "System restored. You can now change wallpaper."
