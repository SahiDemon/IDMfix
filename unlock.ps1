$pass = Read-Host "Enter password to restore system"

if ($pass -ne "SorrySahindu") {
    Write-Host "Wrong password."
    exit
}

$base = "$env:ProgramData\WinGuard"

# Restore wallpaper
if (Test-Path "$base\backup.txt") {
    $orig = Get-Content "$base\backup.txt"
    Set-ItemProperty "HKCU:\Control Panel\Desktop" Wallpaper $orig
    rundll32.exe user32.dll, UpdatePerUserSystemParameters
}

# Remove tasks
"WinGuard","WinGuard-Heal","WinGuard-Notice" | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_ -Confirm:$false -ErrorAction SilentlyContinue
}

Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "System restored."
