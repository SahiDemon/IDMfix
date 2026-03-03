# ===== BANNER =====
Clear-Host
Write-Host ""
Write-Host "  ██╗   ██╗███╗   ██╗██╗      ██████╗  ██████╗██╗  ██╗" -ForegroundColor Magenta
Write-Host "  ██║   ██║████╗  ██║██║     ██╔═══██╗██╔════╝██║ ██╔╝" -ForegroundColor Magenta
Write-Host "  ██║   ██║██╔██╗ ██║██║     ██║   ██║██║     █████╔╝ " -ForegroundColor Magenta
Write-Host "  ██║   ██║██║╚██╗██║██║     ██║   ██║██║     ██╔═██╗ " -ForegroundColor Magenta
Write-Host "  ╚██████╔╝██║ ╚████║███████╗╚██████╔╝╚██████╗██║  ██╗" -ForegroundColor Magenta
Write-Host "   ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝" -ForegroundColor Magenta
Write-Host ""
Write-Host "          [ WinGuard v2.0  |  System Unlock Utility ]" -ForegroundColor DarkMagenta
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
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
    Write-Host " ! " -NoNewline -ForegroundColor DarkYellow
    Write-Host "]  $Message" -ForegroundColor DarkYellow
}
function Show-Fail {
    param([string]$Message)
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host " ✖ " -NoNewline -ForegroundColor Red
    Write-Host "]  $Message" -ForegroundColor Red
}

# ===== SECURE PASSWORD CHECK (SHA256) =====
Write-Host "  Enter the unlock password to continue." -ForegroundColor DarkCyan
Write-Host ""
$secureInput = Read-Host "  Password" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureInput)
$plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$bytes = [System.Text.Encoding]::UTF8.GetBytes($plain)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
$hashStr = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
$plain = $null

# SHA256 hash of the unlock password
$expectedHash = "928ed03e40e2253369a0ca144c261f6e7ad0f1d5c7d188a4589f3e5d998dbc6f"

Write-Host ""
if ($hashStr -ne $expectedHash) {
    Show-Fail "Incorrect password. Access denied."
    Write-Host ""
    exit
}

Show-OK "Password accepted. Starting WinGuard removal..."
Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$base = "$env:ProgramData\WinGuard"
$backup = "$base\backup.txt"

# ===== STOP GUARD TASKS =====
Show-Step "Deactivating scheduled tasks..."
Unregister-ScheduledTask -TaskName "WinGuard"         -Confirm:$false -ErrorAction SilentlyContinue
Show-OK  "Task removed: WinGuard"
Unregister-ScheduledTask -TaskName "WinGuard-Heal"    -Confirm:$false -ErrorAction SilentlyContinue
Show-OK  "Task removed: WinGuard-Heal"
Unregister-ScheduledTask -TaskName "WinGuard-Notice"  -Confirm:$false -ErrorAction SilentlyContinue
Show-OK  "Task removed: WinGuard-Notice"
Unregister-ScheduledTask -TaskName "WinGuard-Watchdog" -Confirm:$false -ErrorAction SilentlyContinue
Show-OK  "Task removed: WinGuard-Watchdog"

# ===== KILL RUNNING PROCESSES =====
Write-Host ""
Show-Step "Terminating active WinGuard processes..."
$procs = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*WinGuard*" }
if ($procs) {
    $procs | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Show-OK  "Killed process PID $($_.ProcessId)"
    }
} else {
    Show-Warn "No active WinGuard processes found"
}

# ===== REMOVE GROUP POLICY LOCKS =====
Write-Host ""
Show-Step "Removing Group Policy wallpaper locks..."
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name "NoChangingWallpaper" -ErrorAction SilentlyContinue
Show-OK  "Cleared: HKCU ActiveDesktop\NoChangingWallpaper"
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "Wallpaper" -ErrorAction SilentlyContinue
Show-OK  "Cleared: HKCU System\Wallpaper"
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name "NoChangingWallpaper" -ErrorAction SilentlyContinue
Show-OK  "Cleared: HKLM ActiveDesktop\NoChangingWallpaper"
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "Wallpaper" -ErrorAction SilentlyContinue
Show-OK  "Cleared: HKLM System\Wallpaper"

# ===== RESTORE ORIGINAL WALLPAPER =====
Write-Host ""
Show-Step "Restoring original wallpaper..."
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@

if (Test-Path $backup) {
    $originalPath = (Get-Content $backup -Raw).Trim()
    if ($originalPath -and (Test-Path $originalPath)) {
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $originalPath
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value 2
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value 0
        # SPI_SETDESKWALLPAPER=0x0014, SPIF_UPDATEINIFILE=0x01, SPIF_SENDCHANGE=0x02
        [Wallpaper]::SystemParametersInfo(0x0014, 0, $originalPath, 0x01 -bor 0x02)
        Show-OK  "Wallpaper restored: $originalPath"
    } else {
        Show-Warn "Backup path not found or file missing; wallpaper not restored"
    }
} else {
    Show-Warn "No backup file found; wallpaper not restored"
}

# ===== REFRESH GROUP POLICY =====
Write-Host ""
Show-Step "Refreshing Group Policy..."
gpupdate /force | Out-Null
Show-OK  "Group Policy refreshed"

# ===== REMOVE WINGUARD FOLDER =====
Write-Host ""
Show-Step "Removing WinGuard installation files..."
Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue
Show-OK  "WinGuard folder deleted: $base"

# ===== DONE =====
Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  [" -NoNewline -ForegroundColor DarkGray
Write-Host " ✔ " -NoNewline -ForegroundColor Green
Write-Host "] " -NoNewline -ForegroundColor DarkGray
Write-Host "System fully restored. You can now change your wallpaper freely." -ForegroundColor Green
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
