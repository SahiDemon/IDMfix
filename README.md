# IDM Pop-up Fix

A simple PowerShell script to disable the annoying update check popup in Internet Download Manager (IDM).

## 🚀 Quick Fix (One-Line Command)

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/SahiDemon/IDMfix/main/Fix-IDM-Popup.ps1 | iex
```

Or download and run locally:

```powershell
.\Fix-IDM-Popup.ps1
```

## 📋 What This Script Does

- Modifies the registry key: `HKEY_CURRENT_USER\Software\DownloadManager`
- Changes the `CheckUpdtVM` value from `1` to `0`
- Creates a backup file before making changes
- Provides clear feedback on the operation status

## ⚠️ Important Safety Information

### Before Running:
1. **Close IDM completely** before running the script
2. **Create a system restore point** (recommended for extra safety)
3. **Run PowerShell as Administrator** for proper registry access

### What to Expect:
- The script creates a backup file with timestamp
- IDM needs to be restarted for changes to take effect
- The annoying update popup should be gone after restart

## 🛠️ Manual Steps (If You Prefer)

If you want to do this manually instead of using the script:

1. Press `Win + R`, type `regedit`, and press Enter
2. Navigate to: `Computer\HKEY_CURRENT_USER\Software\DownloadManager`
3. Find the `CheckUpdtVM` entry
4. Double-click it and change the value from `1` to `0`
5. Click OK and close Registry Editor
6. Restart IDM

## 🔧 Script Options

The script supports several parameters:

```powershell
# Preview changes without making them
.\Fix-IDM-Popup.ps1 -WhatIf

# Force execution (bypasses some confirmations)
.\Fix-IDM-Popup.ps1 -Force
```

## 🔄 How to Revert

If you want to re-enable the update checks:

1. Use the backup file created by the script, or
2. Run this PowerShell command:
   ```powershell
   Set-ItemProperty -Path "HKCU:\Software\DownloadManager" -Name "CheckUpdtVM" -Value 1
   ```

## ❓ Troubleshooting

### "Registry path not found"
- Make sure IDM is installed
- Run IDM at least once to create registry entries
- Try running the script again

### "Access denied" or permission errors
- Run PowerShell as Administrator
- Make sure IDM is completely closed

### Script execution policy issues
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 🔒 Security Notes

- This script only modifies IDM-specific registry entries
- No system-critical settings are changed
- A backup is created before any changes
- The script runs in user context (HKCU), not system-wide

## 📝 What Gets Modified

| Registry Location | Value Name | Original Value | New Value |
|------------------|------------|----------------|-----------|
| `HKCU:\Software\DownloadManager` | `CheckUpdtVM` | `1` | `0` |

## 🎯 Tested On

- Windows 10/11
- IDM versions 6.x
- PowerShell 5.1 and PowerShell 7+

## 📄 License

This project is provided "as-is" for educational and personal use. Use at your own risk.

## 🤝 Contributing

Feel free to open issues or submit pull requests if you have improvements or encounter problems.

---

**Disclaimer:** This tool modifies Windows registry. While it only changes IDM-specific settings and creates backups, please ensure you understand the risks before use. The author is not responsible for any issues that may arise from using this script.