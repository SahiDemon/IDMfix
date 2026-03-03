# ===== SECURE PASSWORD CHECK (SHA256) =====
$secureInput = Read-Host "Enter password to restore system" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureInput)
$plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$bytes = [System.Text.Encoding]::UTF8.GetBytes($plain)
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
$hashStr = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
$plain = $null

# SHA256 hash of the unlock password
$expectedHash = "99ec74260917f0203feb227404fbe40e9c738284a55d6570f2c5c8a494a76c23"

if ($hashStr -ne $expectedHash) {
    Write-Host "Wrong password."
    exit
}

$base = "$env:ProgramData\WinGuard"
$backup = "$base\backup.txt"

# ===== STOP GUARD TASKS =====
Unregister-ScheduledTask -TaskName "WinGuard" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "WinGuard-Heal" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "WinGuard-Notice" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "WinGuard-Watchdog" -Confirm:$false -ErrorAction SilentlyContinue

# Kill any running guard process (use CimInstance to access CommandLine)
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*WinGuard*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# ===== REMOVE GROUP POLICY LOCKS =====
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name "NoChangingWallpaper" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "Wallpaper" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name "NoChangingWallpaper" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "Wallpaper" -ErrorAction SilentlyContinue

# ===== RESTORE ORIGINAL WALLPAPER =====
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
        Write-Host "Original wallpaper restored."
    } else {
        Write-Host "Original wallpaper path not found or file missing; wallpaper not restored."
    }
} else {
    Write-Host "No wallpaper backup found; wallpaper not restored."
}

# Refresh Group Policy
Write-Host "Refreshing Group Policy..."
gpupdate /force | Out-Null

# ===== REMOVE WINGUARD FOLDER =====
Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "System restored. You can now change wallpaper."
