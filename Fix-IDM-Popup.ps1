# IDM (Internet Download Manager) Annoying Pop-up Fix
# This script disables the update check popup by modifying the registry

param(
    [switch]$WhatIf,
    [switch]$Force
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

Write-Host "IDM Pop-up Fix Script" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host ""

# Registry path and value
$registryPath = "HKCU:\Software\DownloadManager"
$valueName = "CheckUpdtVM"
$newValue = 0

if ($WhatIf) {
    Write-Host "WHAT-IF MODE: No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

try {
    # Check if the registry path exists
    if (Test-Path $registryPath) {
        Write-Host "✓ Found IDM registry path: $registryPath" -ForegroundColor Green
        
        # Check current value
        $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
        
        if ($currentValue) {
            Write-Host "Current value of '$valueName': $($currentValue.$valueName)" -ForegroundColor Yellow
            
            if ($currentValue.$valueName -eq $newValue) {
                Write-Host "✓ Value is already set correctly!" -ForegroundColor Green
                Write-Host "IDM popup should already be disabled." -ForegroundColor Green
            } else {
                if (!$WhatIf) {
                    # Backup current value
                    $backupFile = "IDM_Registry_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
                    "Registry Backup - $(Get-Date)" | Out-File $backupFile
                    "Path: $registryPath" | Out-File $backupFile -Append
                    "Value: $valueName" | Out-File $backupFile -Append
                    "Original Value: $($currentValue.$valueName)" | Out-File $backupFile -Append
                    Write-Host "✓ Created backup file: $backupFile" -ForegroundColor Green
                    
                    # Set the new value
                    Set-ItemProperty -Path $registryPath -Name $valueName -Value $newValue
                    Write-Host "✓ Successfully changed '$valueName' to $newValue" -ForegroundColor Green
                    Write-Host "✓ IDM popup has been disabled!" -ForegroundColor Green
                } else {
                    Write-Host "WOULD CHANGE: '$valueName' from $($currentValue.$valueName) to $newValue" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "Value '$valueName' not found. Creating it..." -ForegroundColor Yellow
            if (!$WhatIf) {
                New-ItemProperty -Path $registryPath -Name $valueName -Value $newValue -PropertyType DWORD
                Write-Host "✓ Created '$valueName' with value $newValue" -ForegroundColor Green
                Write-Host "✓ IDM popup has been disabled!" -ForegroundColor Green
            } else {
                Write-Host "WOULD CREATE: '$valueName' with value $newValue" -ForegroundColor Yellow
            }
        }
        
    } else {
        Write-Host "✗ IDM registry path not found: $registryPath" -ForegroundColor Red
        Write-Host "This usually means IDM is not installed or has never been run." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please:" -ForegroundColor Yellow
        Write-Host "1. Make sure IDM is installed" -ForegroundColor Yellow
        Write-Host "2. Run IDM at least once" -ForegroundColor Yellow
        Write-Host "3. Try this script again" -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-Host "✗ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Script completed successfully!" -ForegroundColor Green

if (!$WhatIf) {
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "- Restart IDM for changes to take effect" -ForegroundColor Yellow
    Write-Host "- If you need to revert, restore from the backup file created" -ForegroundColor Yellow
    Write-Host "- You can re-enable updates by setting the value back to 1" -ForegroundColor Yellow
}