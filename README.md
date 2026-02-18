# Active Directory User Password Management Tool

A comprehensive PowerShell-based Active Directory user management and password reset tool designed for enterprise environments. This script provides a menu-driven interface for managing AD user passwords, flags, and generating detailed reports.

## Features

### 📦 Dataset Management
- **Import users from multiple sources:**
  - Organizational Units (OUs)
  - AD Groups
  - CSV files (flexible format support)
  - Individual usernames (manual entry)
- **Dataset operations:**
  - View loaded users with summary statistics
  - Export current dataset to CSV
  - Remove users from dataset (single or bulk):
    - Remove individual users
    - Bulk remove by AD Group membership
    - Bulk remove by Organizational Unit
    - Bulk remove by comma-separated list of names
  - Merge multiple import sources
  - Duplicate detection and prevention

### 🔐 Password Operations
- **Reset passwords for all users in dataset**
  - Batch password reset with unique generated passwords
  - Individual password reset with export to CSV
  - Set ChangePasswordAtLogon flag automatically
  - Secure password generation (32 characters, crypto-random)
- **Password Flag Management:**
  - Set/unset PasswordNeverExpires flag
  - Set/unset ChangePasswordAtLogon flag

### 📊 Global Reports
- Export users with PasswordNeverExpires flag
- Export users with ChangePasswordAtLogon flag
- View/export users whose passwords changed today
- View/export users whose passwords NOT changed today
- View all users with last password change dates
- Export comprehensive user attributes (SamAccountName, LastLogon, PasswordLastSet, PasswordNeverExpires, ChangePasswordAtLogon)
- Export complete user data with all AD attributes
- **View/export users by Enabled/Disabled status** (filter by enabled only, disabled only, or all users with status)
- **Export by Group:**
  - Export users with their groups (User | Groups format)
  - Export groups with their users (Group | Users format)
  - Export users with multiple groups
  - Export groups with no users
  - Export users with no groups


### 🔑 krbtgt Management
- **Reset krbtgt password immediately** with safety prompts
- **Schedule second krbtgt reset** using Windows Task Scheduler
  - Configurable delay (recommended: 10-48 hours)
  - Attended execution with user confirmation
  - Automatic cleanup after execution
- **External script integration** for advanced krbtgt management

## Requirements

- **Operating System:** Windows Server 2012 R2 or later / Windows 10/11 with RSAT
- **PowerShell:** Version 5.1 or later
- **Modules:**
  - ActiveDirectory (RSAT-AD-PowerShell)
  - System.Windows.Forms (for file dialogs)
- **Permissions:**
  - Domain Admin or equivalent rights for password resets
  - Account Operators minimum for viewing/reporting functions
- **Execution Policy:** Must allow script execution (`Set-ExecutionPolicy RemoteSigned`)

## Installation

1. **Clone or download the repository:**
   ```powershell
   git clone https://github.com/mcarroll5389/PBR_User_Manager.git
   cd PBR_User_Manager
   ```

2. **Verify Active Directory module is available:**
   ```powershell
   Get-Module -ListAvailable ActiveDirectory
   ```

3. **Run the script:**
   ```powershell
   .\PBR_ADUsers_Password_Management.ps1
   ```

## Usage

### Quick Start

1. Launch the script from PowerShell console
2. Select option `1` (Manage Dataset)
3. Choose import method (OU, Group, File, or Username)
4. View loaded dataset with option `1` (View Dataset)
5. Perform operations on loaded users (reset passwords, set flags, export reports)

### Common Workflows

#### Bulk Password Reset for Department
```
Main Menu → Manage Dataset → Import
Back to Main → Dataset Operations → Reset Passwords (All Users in Dataset)
```

#### Bulk Remove Users by Group
```
Main Menu → Manage Dataset → Remove Users from Dataset → Bulk Remove by Group
Select group → Confirm removal
```

#### Bulk Remove Users by OU
```
Main Menu → Manage Dataset → Remove Users from Dataset → Bulk Remove by OU
Select OU → Confirm removal
```

#### Generate Report of Users with Expired Passwords
```
Main Menu → Global Reports → View/Export All Users with LastPasswordChange Date
```

#### krbtgt Dual Reset Procedure (Basic, but it works)
```
Main Menu → krbtgt Password Resets → Reset krbtgt Password Now → 
Schedule krbtgt Password Reset → Enter delay (e.g., 12 hours)
```

## Key Functions

### Import Functions
- **ImportByFile** - Import from CSV with flexible column detection
- **ImportByUsername** - Manual entry with validation
- **DisplaySelectImportByOUs** - Browse and select OUs
- **ImportByGroup** - Import all members from AD group

### Password Reset Functions
- **ResetPasswordsForAllUsersInDataset** - Batch reset with shared or unique passwords
- **ResetPasswordsForAllUsersInDatasetWithUniquePW** - Individual passwords exported to CSV

### Reporting Functions
- **ExportUsersWithPasswordNeverExpires** - Find accounts with non-expiring passwords
- **ExportUsersWithChangePasswordAtLogon** - Identify accounts requiring password change
- **ExportUsersChangedToday** - Track recent password changes
- **ExportAllUsersWithAttributes** - Comprehensive user attribute export
- **ExportUsersWithGroups** - Export users with their group memberships
- **ExportGroupsWithUsers** - Export groups with their user members
- **ExportUsersWithMultipleGroups** - Find users belonging to multiple groups
- **ExportGroupsWithNoUsers** - Identify empty groups
- **ExportUsersWithNoGroups** - Find users without group memberships

### krbtgt Functions
- **ResetkrbtgtPasswordNow** - Immediate krbtgt reset with safety checks
- **ResetkrbtgtPasswordScheduleSecond** - Schedule delayed second reset (Task Scheduler)
- **Invoke-ResetKrbTgtPassword** - Advanced krbtgt reset with RWDC/RODC support

## Security Notes

⚠️ **IMPORTANT:** This script performs privileged Active Directory operations

- Always test in non-production environment first
- Review the dataset before performing bulk operations
- Password exports are saved as CSV files - **secure and delete after use**
- krbtgt resets require 10-hour minimum delay between resets for replication
- Log files are created in script directory with timestamps
- Logging is NOT thorough. If you need logging, consider contributing.
- Requires Domain Admin rights for most operations

## Configuration

### CSV File Format
The script supports multiple CSV formats:
- **With header:** `SamAccountName` or `username` column
- **Without header:** Plain list of usernames (one per line)
- **Multi-column:** Uses first column with valid header

Example CSV:
```csv
SamAccountName
jsmith
mjones
bwilliams
```

### Password Generation
Passwords are generated using:
- **Length:** 32 characters minimum (configurable)
- **Complexity:** Uppercase, lowercase, digits, special characters
- **Method:** Cryptographically secure random (Get-Random with ASCII 33-126)

## Troubleshooting

### "Cannot find Active Directory module"
```powershell
# Install RSAT tools
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

### "Insufficient permissions"
- Verify you have Domain Admin or equivalent rights
- Check if account is member of necessary security groups
- Run PowerShell as Administrator

### "Import returns no users"
- Check CSV file encoding (UTF-8 recommended)
- Verify column headers match expected format
- Ensure usernames exist in Active Directory

### "krbtgt scheduled task doesn't run"
- Verify Task Scheduler service is running
- Check task was created (Task Scheduler → Task Scheduler Library)
- Ensure user has rights to create scheduled tasks

## Logging

The script creates log files for:
- krbtgt password resets: `[timestamp]_[computername]_Reset-KrbTgt-Password.log`
- Password exports: `DatasetExport-[timestamp].csv`
- Report exports: Various CSV files with timestamps

All logs are saved to the script directory.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly in lab environment
4. Submit pull request with detailed description

## Credits

- **Invoke-ResetKrbTgtPassword function:** Based on work by Jorge de Almeida Pinto [MVP-EMS]
- **Original concept:** PBR AD User Management Framework

## License

This project is provided as-is for educational and administrative purposes. Use at your own risk.

## Version History

- **2.8** - Current version with comprehensive krbtgt management
- **2.7** - Added scheduled task support for krbtgt
- **2.6** - Enhanced CSV import with flexible format support
- **2.5** - Added duplicate detection and per-user feedback

## Support

For issues, questions, or feature requests, please open an issue on GitHub.

---

**⚠️ Always test in a non-production environment before deploying to production Active Directory!**
**⚠️ Generated through various human decisions and GitHub Copilot AI. Proceed with caution. ⚠️**
