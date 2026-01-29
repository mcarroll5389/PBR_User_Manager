<# 
# PBR_ADUsers_Password_Management

## About
- Designed for Administrator use for the management of AD Users, quickly.
- Work in process, will eventually feature all items from the feature list below.


## Features
	- [X] Active Directory user password management
    - [x] Display, Select and Reset users based on OU
    - [x] Reset users based on external files (SAM Name)
    - [x] Export Users for resets
    - [x] Export Users with set flags (PasswordNeverExpires, ChangePasswordAtLogon)
    - [x] Export Users by Group Memberships (Domain Admins, Service Accounts, General Users)
	- [x] Set users passwords via either: Set String (All Users the same), Random String (All Users different, output to current directory).
    - [X] Display and export users passwords NOT changed today.
    - [X] Display and export users with LastChangedDate attribute.
    - [X] Edit "PasswordNeverExpires" flags based on dataset
    - [X] Edit "ChangePasswordAtLogon" flags based on dataset
	- [X] krbtgt reset, with ability to add a scheduled task for a second reset (prompt for user confirmation)

## To Do
- [x] Design user menu, sub-menus and return options.
- [X] Add an exclusion for the currently logged in users password reset requirement.
- [X] Standardise formatting for menus.
- [x] Design functions, input and output schema
- [x] ExportUsersWithPasswordNeverExpires
- [X] DisplayAndExportLastPasswordChange
- [X] ExportAllUsersWithAttributes
- [X] ExportAllUsersFullData
- [X] ImportByGroup
- [X] Replace "Press enter to continue" with start-sleep at some point.
- [X] Find alternative to ExportUsersWithChangePasswordAtLogon
- [X] ExportUsersChangedToday
- [X] Check Clear-Host locations.
- [X] Add "Add Single User to Dataset" feature.
- [X] Code in an additional check window for the dataset when doing a file import.
- [ ] Implement error handling
- [ ] Code in logging functionality
- [ ] Add dynamic updating for user status, when called.



## Changelog
- **0.1.0** - Project initialization

## Issue list:
    - [X] I've removed the $_SamAccount.name / SamAccount.User arguement from multiple areas. If storing dataset as an object, this will break.
    - [X] Test RemoveUsersFromDatasetMenu
    - [X] ResetDatasetUserPasswords_identical broken
    - [X] ResetDatasetUserPasswords_unique broken.
    - [X] Set-PasswordNeverExpiresFlag broken
    - [X] Set-ChangePasswordAtLogonFlag is broken.
    - [X] Import users by OU is importing the Canonical Name, not the SamName.
    - [X] ResetDatasetUserPasswords_identical Menu is broken and doesn't display correctly. Review.
    - [X] ResetDatasetUserPasswords_unique also probably has a broken menu. Review.
    - [X] Set-ChangePasswordAtLogonFlag - Error when account has "PasswordNeverExpires" set to False.
    - [X] === Users whose Passwords were changed today === returns empty data.
    - [X] Fix krbtgt scheduled reset functions.

#>

############# Global Variables #############
# Global flag for jumping back to main menu from any depth
# Main Dataset Handing Functions.
$global:CurrentDataset = @()
$global:CurrentDatasetName = "None"

# Temporary Dataset Handing functions for checking and merging to Main Dataset Functions.
$global:DisplayAndSelectName = ""
$global:DisplayAndSelectFilteredItem = @()

############# Password Settings #############
# Word Options for password setting.
$global:words = @(
	"Apple", "Banana", "Cherry", "Date", "Elderberry",
	"Fruit", "Grape", "Honeydew", "Netball", "Lemon",
	"Mango", "Orange", "Peach", "Quince", "Raspberry",
	"Strawberry", "Tangerine", "Watermelon", "Apricot", "Blueberry",
	"Cantaloupe", "Dragonfruit", "Guava", "Jackfruit", "Kumquat",
	"Limes", "Nectarine", "Olive", "Papaya", "Pineapple",
	"Pomegranate", "Raisin", "Satsuma", "Tomato", "Potato",
	"Valley", "Walnut", "Xigua", "Yukon", "Zucchini",
	"Angel", "Beast", "Camel", "Steam", "Elephant",
	"Flame", "Giraffe", "Horse", "Iguana", "Jaguar",
	"Kangaroo", "Llama", "Monkey", "Newt", "Owlet",
	"Panda", "Quail", "Rabbit", "Snake", "Tiger",
	"Unicorn", "Vulture", "Whale", "Xenop", "Keeper",
	"Zebra", "Airbus", "Barge", "Cargo", "Diesel",
	"Engine", "Ferry", "Garage", "Highway", "Inlet",
	"Junction", "Kiosk", "Lance", "Motor", "Naval",
	"Ocean", "Pilot", "Quake", "Route", "Sight",
	"Train", "Urban", "Vessel", "Wheel", "Yacht",
	"Zipper", "Books", "Canto", "Diary", "Essay",
	"Fable", "Genre", "Haiku", "Index", "Journal",
	"Knowledge", "Lyric", "Manuscript", "Novel", "Octave",
	"Poetry", "Quote", "Reader", "Story", "Title",
	"Volume", "Vegan", "Writing", "Hollow", "Yearly", "Zoned"
)
# Special Character Options for password setting.
$global:specialChars = @("@", "%", "!", ".")


############# Modules Imports #############
# Ensure Active Directory module is loaded
if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
	Import-Module ActiveDirectory
}

# Import .NET assembly
Add-Type -AssemblyName System.Windows.Forms

############# Initial Checks #############
# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
	Read-Host "This script must be run as an Administrator. Please restart PowerShell with elevated privileges."
	exit
}
# Check if AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
	Read-Host "The Active Directory module is not available. Please install the RSAT tools and try again."
	exit
}
# Check if computer is domain joined
if (-not (Get-ADDomain -ErrorAction SilentlyContinue)) {
	Read-Host "This computer is not joined to a domain. Please join a domain and try again."
	exit
}
# Check connectivity to a Domain Controller
try {
		Get-ADDomainController -Discover -ErrorAction Stop | Out-Null
	}
 catch {
		Read-Host "Cannot connect to a Domain Controller. Please ensure you are connected to the domain and try again."
		exit
	}
# May add checks to see if the NIC is physically connected to the network later

############# Main and Sub Menus #############
# ---Main Menu Functions---
# Menu 0
function Show-MainMenu {
	do {
		Clear-Host
		Write-Host "=== PBR AD Users Management === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. Manage Dataset"
		Write-Host "2. Manage Users"
		Write-Host "3. Global Reports"
		Write-Host "4. krbtgt Password Resets..."
		Write-Host "9. About / Help"
		Write-Host "0. Exit"
        
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { Show-ManageDatasetMenu }
			2 { Show-ManageUsersMenu }
			3 { Show-ReportsMenu }
			4 { Show-KrbtgtResetMenu }
			9 { Show-AboutHelp }
			0 { Exit-Script }
			default {
				Write-Host "Invalid option. Please try again."
				Wait-WithDelay
			}
		}
	} while ($true)
}
# Menu 1 - Datasets
# Manage Dataset Menu and Sub-menus
# 1 Submenu - all others directly called functions.
function Show-ManageDatasetMenu {
	do {
		Clear-Host
		Write-Host "=== Main -> Manage Dataset === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. Load Users into Dataset"
		Write-Host "2. Remove Users from Dataset"
		Write-Host "3. View Dataset Summary"
		Write-Host "4. View All Dataset Entries (User SAM Names)"
		Write-Host "5. Export Dataset"
		Write-Host "6. Clear Dataset"
		Write-Host "0. Back to Main Menu"
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { Show-ImportUserDatasetMenu } # Done
			2 { RemoveUsersFromDatasetMenu } # Done
			3 { Show-LoadedDatasetSummary } # Done
			4 { Show-LoadedDatasetEntries } # Done
			5 { ExportDataset } # Done
			6 { ResetDatasetVariables } # Done
			0 { Show-MainMenu } # Done
			default { 
				Write-Host "Invalid option. Please try again."
				Wait-WithDelay
			}
		}
	} while ($true)
}
# Menu 1.1 - Import Users into Dataset
function Show-ImportUserDatasetMenu {
	do {
		Clear-Host
		Write-Host "=== Manage Dataset -> Import User Dataset === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. Import by OU"
		Write-Host "2. Import by Group Membership"
		Write-Host "3. Import by File"
		Write-Host "4. Import by Username"
		Write-Host "9. Back to Previous Menu"
		Write-Host "0. Back to Main Menu"
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { DisplaySelectImportByOUs }
			2 { ImportByGroup }
			3 { ImportByFile }
			4 { ImportByUsername }
			9 { return }
			0 { Show-MainMenu }
			default {
				Write-Host "Invalid option. Please try again."
				Wait-WithDelay
			}
		}
	} while ($true)
}

function RemoveUsersFromDatasetMenu {
	do {
		Clear-Host
        Refresh-CurrentDatasetStatus
		# Check if dataset is empty
		if ($global:CurrentDataset.Count -eq 0) {
			Write-Host "=== Remove Users from Dataset ===" -ForegroundColor Cyan
			Write-Host ""
			Write-Host "The dataset is empty. Please load users first." -ForegroundColor Yellow
			Wait-ForExplicitContinue
			return
		}
        
		Write-Host "=== Remove Users from Dataset ===" -ForegroundColor Cyan
		Write-Host "Current Dataset: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count)" -ForegroundColor Gray
		Write-Host ""
        
		# Display all users with numbers
		# for ($i = 0; $i -lt $global:CurrentDataset.Count; $i++) {
		# 	$user = $global:CurrentDataset[$i]
		# 	$status = if ($user.Enabled) { "Active" } else { "Disabled" }
		# 	$statusColor = if ($user.Enabled) { "Green" } else { "Red" }
            
		# 	Write-Host ("{0,4}. {1,-30}" -f ($i + 1), $user.SamAccountName) -NoNewline
		# 	Write-Host " [$status]" -ForegroundColor $statusColor
		# }
		Show-UserStatus
        
		Write-Host ""
		Write-Host "  0. Return to Previous Menu" -ForegroundColor Yellow
		Write-Host ""
        
		$selection = Read-Host "Enter the number of the user to remove (or 0 to return)"
        
		# Handle return
		if ($selection -eq "0") {
			return
		}
        
		# Validate numeric input
		if (-not ($selection -match '^\d+$')) {
			Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
			Wait-WithDelay
			continue
		}
        
		$index = [int]$selection - 1
        
		# Validate range
		if ($index -lt 0 -or $index -ge $global:CurrentDataset.Count) {
			Write-Host "Invalid selection. Number out of range." -ForegroundColor Red
			Wait-WithDelay
			continue
		}
        
		# Get the selected user
		$selectedUser = $global:CurrentDataset[$index]
        
		# Confirm removal
		Write-Host ""
		Write-Host "Selected user: $($selectedUser.SamAccountName)" -ForegroundColor Yellow
		$confirm = Read-Host "Are you sure you want to remove this user from the dataset? (Y/N)"
        
		if ($confirm -eq "Y" -or $confirm -eq "y") {
			# Remove the user from the dataset
			$global:CurrentDataset = $global:CurrentDataset | Where-Object { $_.SamAccountName -ne $selectedUser.SamAccountName }
            
			Write-Host "User '$($selectedUser.SamAccountName)' removed from dataset." -ForegroundColor Green
			Write-Host "Remaining users: $($global:CurrentDataset.Count)" -ForegroundColor Cyan
			Start-Sleep -Seconds 1
            
			# Check if dataset is now empty
			if ($global:CurrentDataset.Count -eq 0) {
				Write-Host ""
				Write-Host "Dataset is now empty." -ForegroundColor Yellow
				$global:CurrentDatasetName = "None"
				Wait-ForExplicitContinue
				return
			}
		}
		else {
			Write-Host "Removal cancelled." -ForegroundColor Gray
			Start-Sleep -Seconds 1
		}
	} while ($true)
}

# Menu 2 - Users
# No Submenus - All functions called directly
function Show-ManageUsersMenu {
	do {
		Clear-Host
		Write-Host "=== Main -> Manage Users === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. Set User Passwords to Same String"
		Write-Host "2. Set User Passwords to Random Strings"
		Write-Host "3. Set 'PasswordNeverExpires' Flag for Users in Dataset"
		Write-Host "4. Set 'ChangePasswordAtLogon' Flag for Users in Dataset"
		Write-Host "0. Back to Main Menu"
        
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { ResetDatasetUserPasswords_identical }
			2 { ResetDatasetUserPasswords_unique }
			3 { Set-PasswordNeverExpiresFlag }
			4 { Set-ChangePasswordAtLogonFlag }
			0 { Show-MainMenu }
			default {
				Write-Host "Invalid option. Please try again."
				Wait-WithDelay
				
			}
		}
	} while ($true)
}

# Menu 3 - Reports
function Show-ReportsMenu {
	do {
		Clear-Host
		Write-Host "=== Global Reports === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. View/Export All Users with PasswordNeverExpires Flag set to True"
		Write-Host "2. View/Export All Users with ChangePasswordAtLogon Flag set to True"
		Write-Host "3. View/Export All Users whose Passwords were NOT changed today"
		Write-Host "4. View/Export All Users whose Passwords were changed today"
		Write-Host "5. View/Export All Users with their password change dates"
		Write-Host "6. View/Export All Users with SamName, LastLogon, PasswordLastSet, PasswordNeverExpires, ChangePasswordAtLogon to CSV"
		Write-Host "7. Export All Users & All User Data to CSV"
		Write-Host "8. View/Export All Users with Enabled/Disabled Status"
		Write-Host "9. Back to Previous Menu"
		Write-Host "0. Back to Main Menu"
        
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { ExportUsersWithPasswordNeverExpires }
			2 { ExportUsersWithChangePasswordAtLogon }
			3 { DisplayAndExportNotChangedToday }
			4 { ExportUsersChangedToday }
			5 { DisplayAndExportLastPasswordChange }
			6 { ExportAllUsersWithAttributes } 
			7 { ExportAllUsersFullData }
			8 { ExportUsersWithEnabledDisabledStatus }
			9 { return }
			0 { Show-MainMenu }
			default {
				Write-Host "Invalid option. Please try again."
				Wait-WithDelay
			}
		}
	} while ($true)
}

# Menu 4 - krbtgt Resets
function Show-KrbtgtResetMenu {
	do {
		Clear-Host
		Write-Host "=== krbtgt Password Resets ===" -ForegroundColor Cyan
		Write-Host "1. Reset krbtgt Password Now"
		Write-Host "2. Schedule krbtgt Password Reset (TBC)"
		Write-Host "9. Back to Previous Menu"
		Write-Host "0. Back to Main Menu"
        
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { ResetkrbtgtPasswordNow }
			2 { ResetkrbtgtPasswordScheduleSecond } 
			9 { return }
			0 { Show-MainMenu }
			default { 
				Write-Host "Invalid option. Please try again." 
				Wait-WithDelay
			}
		}
	} while ($true)
}

function Show-AboutHelp {
	Clear-Host
	Write-Host "=== About / Help ===" -ForegroundColor Cyan
	Write-Host ""
	Write-Host "PBR AD Users Management Script"
	Write-Host ""
	Write-Host "This script is designed to help administrators manage Active Directory user passwords efficiently."
	Write-Host ""
	Write-Host "Features include:"
	Write-Host "- Importing users into a dataset by OU, group membership, file, or username."
	Write-Host "- Resetting user passwords to either a common string or unique random strings."
	Write-Host "- Setting 'PasswordNeverExpires' and 'ChangePasswordAtLogon' flags for users in the dataset."
	Write-Host "- Generating various reports on user password statuses."
	Write-Host "- Performing krbtgt password resets with scheduling options."
	Write-Host ""
	Write-Host "Please ensure that you have suitable backups of your Active Directory environment before making bulk changes."
	Write-Host "Use this tool responsibly and verify changes in a test environment if possible."
	Write-Host "Released with no warranties. Use at your own risk."
	Write-Host ""
	Write-Host "For any queries, contact the script author."
	Write-Host ""
	Wait-ForExplicitContinue
}



#################################### ---End of Main Menu Functions--- ########################################

#################################### Main Functions #########################################
# Includes core functions which are called from Menus. Sub-functions (called within functions)
# will be called elsewhere.
function Show-LoadedDatasetSummary {
	Clear-Host
	Refresh-CurrentDatasetStatus
	Write-Host "=== Loaded Dataset Summary ===" -ForegroundColor Cyan
	if ($global:CurrentDataset.Count -eq 0) {
		Write-Host "No users currently loaded in the dataset."
	}
 else {
		$activeCount = ($global:CurrentDataset | Where-Object { $_.Enabled -eq $true }).Count
		$disabledCount = ($global:CurrentDataset | Where-Object { $_.Enabled -eq $false }).Count
		Write-Host "Total Users in Dataset: $($global:CurrentDataset.Count)"
		Write-Host "Active Users: $activeCount" -ForegroundColor Green
		Write-Host "Disabled Users: $disabledCount" -ForegroundColor Red
		Write-Host "Note: User status is now dynamically updated when viewing the summary." -ForegroundColor Yellow

	}
	Wait-ForExplicitContinue
}

function Show-LoadedDatasetEntries {
	Clear-Host
	Refresh-CurrentDatasetStatus
	Write-Host "=== Loaded Dataset Users ===" -ForegroundColor Cyan
	if ($global:CurrentDataset.Count -eq 0) {
		Write-Host "No users currently loaded in the dataset."
	}
 else {
		Write-Host "SAM Names in the current dataset:"
		Show-UserStatus
	}
	Write-Host "Note: User status is now dynamically updated when viewing the summary." -ForegroundColor Yellow
	Wait-ForContinue
}

function ExportDataset { 
	$Time = Get-Date -Format "yyyyMMdd-HHmmss"
	if ($global:CurrentDataset.Count -eq 0) {
		Write-Host "The dataset is empty. Please select users first."
		Wait-ForContinue
		return
	}
 else {
		$global:CurrentDataset | Select-Object SamAccountName | Export-Csv "$PWD\DatasetExport-$Time.csv" -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $PWD\DatasetExport-$Time.csv" -ForegroundColor Green
		Write-Host "Total users exported: $($global:CurrentDataset.Count)."
		Wait-ForExplicitContinue
	}      
}

function ResetDatasetVariables {
	$ResetCheck = Read-Host "Are you sure you want to clear the current dataset?`n 1. Yes`n 2. No`n Choice"
	if ($ResetCheck -eq "2") {
		return
	}
 else { 
		$global:CurrentDataset = @()
		$global:CurrentDatasetName = "None"
		Write-Host "Currently loaded dataset has been reset to empty."
		Wait-WithDelay
	}
}

function DisplaySelectImportByOUs {
	Clear-Host
	# Get all OUs and count users in each
	$ous = Get-ADOrganizationalUnit -Filter * | Sort-Object DistinguishedName
    
	if ($ous.Count -eq 0) {
		Write-Host "No Organizational Units found in the environment."
		Wait-ForExplicitContinue
		return
	}

	# Build array with user counts
	$ouData = @()
	Write-Host "Gathering OU information, please wait..." -ForegroundColor Yellow
    
	$totalDomainUsers = 0
    
	foreach ($ou in $ous) {
		# Only count user objects, not computers or groups
		$userCount = (Get-ADUser -Filter * -SearchBase $ou.DistinguishedName -SearchScope OneLevel).Count
        
		# Only add OUs that contain users
		if ($userCount -gt 0) {
			$ouData += [PSCustomObject]@{
				Name              = $ou.Name
				UserCount         = $userCount
				DistinguishedName = $ou.DistinguishedName
				OU                = $ou
			}
			$totalDomainUsers += $userCount
		}
	}

	if ($ouData.Count -eq 0) {
		Write-Host "No Organizational Units with users found in the environment."
		Wait-ForExplicitContinue
		return
	}

	# Display OUs in a structured list
	Clear-Host
	Write-Host "=== Available Organizational Units (with users) ===" -ForegroundColor Cyan
	Write-Host ""
    
	for ($i = 0; $i -lt $ouData.Count; $i++) {
		Write-Host ("{0,3}. {1,-40} Users: {2,5} | DN: {3}" -f ($i + 1), $ouData[$i].Name, $ouData[$i].UserCount, $ouData[$i].DistinguishedName)
	}
    
	Write-Host ""
	Write-Host ("  A. Import ALL domain users (regardless of OU) - Total: {0} users" -f $totalDomainUsers) -ForegroundColor Green
	Write-Host "  0. Cancel" -ForegroundColor Red
	Write-Host ""

	# Prompt for selection
	$selection = Read-Host "Enter your choice"
    
	# Handle "All Users" option
	if ($selection -eq "A" -or $selection -eq "a") {
		Clear-Host
		Write-Host "Loading all domain users..." -ForegroundColor Yellow
        
		# Get all user objects (excluding computers and groups)
		$allUsers = Get-ADUser -Filter * -Properties SamAccountName, Enabled
        
		if ($allUsers.Count -eq 0) {
			Write-Host "No users found in the domain."
			Wait-ForExplicitContinue
			return
		}
        
		# Count active and disabled users
		$activeCount = ($allUsers | Where-Object { $_.Enabled -eq $true }).Count
		$disabledCount = ($allUsers | Where-Object { $_.Enabled -eq $false }).Count
        
		Write-Host "Total users in domain: $($allUsers.Count)" -ForegroundColor Cyan
		Write-Host "  Active: $activeCount" -ForegroundColor Green
		Write-Host "  Disabled: $disabledCount" -ForegroundColor Red
		Write-Host ""
        
		$filteredUsers = $allUsers
        
		if ($disabledCount -gt 0) {
			$IncludeDisabled = Read-Host "Do you want to include disabled users in the dataset? `n	1. Yes `n	2. No `nEnter choice (1-2)"
			if ($IncludeDisabled -eq "1") {
				Write-Host "Including both active and disabled users." -ForegroundColor Yellow
			}
			else {
				$filteredUsers = $filteredUsers | Where-Object { $_.Enabled -eq $true }
				Write-Host "Including only active users." -ForegroundColor Green
			}
		}
        
		# Display sample of SAM names
		Clear-Host
		Write-Host "Sample of SAM Names (first 20):" -ForegroundColor Cyan
		Write-Host ""
		$filteredUsers | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.SamAccountName)" }
		if ($filteredUsers.Count -gt 20) {
			Write-Host "  ... and $($filteredUsers.Count - 20) more users" -ForegroundColor Gray
		}
		Write-Host ""
        
		$global:DisplayAndSelectName = "All Domain Users"
		$global:DisplayAndSelectFilteredItem = $filteredUsers
        
		$importChoice = Read-Host "Do you want to import these $($filteredUsers.Count) users into the dataset? `n	1. Yes `n	2. No `nEnter choice (1-2)"


		if ($importChoice -eq "1") {
			ApplySelectionToDataset
		}
		elseif ($importChoice -eq "2") {
			Write-Host "Import cancelled."
			Wait-WithDelay
		}
		else {
			Write-Host "Invalid choice. Import cancelled."
			Wait-WithDelay
		}
		return
	}
    
	# Handle cancel
	if ($selection -eq "0") { 
		return 
	}
    
	# Validate numeric selection
	if (-not ($selection -match '^\d+$')) {
		Write-Host "Invalid selection. Please enter a number." -ForegroundColor Red
		Wait-WithDelay
		return
	}
    
	Clear-Host
	$index = [int]$selection - 1
    
	if ($index -lt 0 -or $index -ge $ouData.Count) {
		Write-Host "Invalid selection. Number out of range." -ForegroundColor Red
		Wait-WithDelay
		return
	}

	$selectedOUData = $ouData[$index]
	$selectedOU = $selectedOUData.OU
	$topLevelOU = $selectedOUData.Name
    
	Write-Host "Selected OU: $topLevelOU" -ForegroundColor Green
	Write-Host "Distinguished Name: $($selectedOU.DistinguishedName)" -ForegroundColor Gray
	Write-Host ""

	# Get users in the selected OU (only user objects)
	$users = Get-ADUser -Filter * -SearchBase $selectedOU.DistinguishedName -Properties SamAccountName, Enabled

	if ($users.Count -eq 0) {
		Write-Host "No users found in the selected OU." -ForegroundColor Yellow
		Wait-ForExplicitContinue
		return
	}

	# Count active and disabled users
	$activeCount = ($users | Where-Object { $_.Enabled -eq $true }).Count
	$disabledCount = ($users | Where-Object { $_.Enabled -eq $false }).Count

	$filteredUsers = $users
    
	Write-Host "Users in OU '$topLevelOU':" -ForegroundColor Cyan
	Write-Host "  Active: $activeCount" -ForegroundColor Green
	Write-Host "  Disabled: $disabledCount" -ForegroundColor Red
	Write-Host ""

	if ($disabledCount -gt 0) {
		$IncludeDisabled = Read-Host "Do you want to include disabled users in the dataset? `n	1. Yes `n	2. No `nEnter choice (1-2)"
		if ($IncludeDisabled -eq "1") {
			Write-Host "Including both active and disabled users." -ForegroundColor Yellow
		}
		else {
			$filteredUsers = $filteredUsers | Where-Object { $_.Enabled -eq $true }
			Write-Host "Including only active users." -ForegroundColor Green
		}
	}
    
	# Display SAM names
	Clear-Host
	Write-Host "SAM Names in the selected '$topLevelOU' OU:" -ForegroundColor Cyan
	Write-Host ""
	$filteredUsers | ForEach-Object { Write-Host "  $($_.SamAccountName)" }
	Write-Host ""
    
	$importChoice = Read-Host "Do you want to import these $($filteredUsers.Count) users into the dataset? `n	1. Yes `n	2. No `nEnter choice (1-2)"
	if ($importChoice -eq "1") {
		$global:DisplayAndSelectName = $topLevelOU
		$global:DisplayAndSelectFilteredItem = $filteredUsers
		ApplySelectionToDataset
	}
 elseif ($importChoice -eq "2") {
		Write-Host "Import cancelled."
		Wait-WithDelay
	}
 else {
		Write-Host "Invalid choice. Import cancelled."
		Wait-WithDelay
	}
}

function ImportByGroup {
	Clear-Host
	# Get all AD Groups
	$groups = Get-ADGroup -Filter * -Properties Members | Sort-Object Name
	
	if ($groups.Count -eq 0) {
		Write-Host "No groups found in the environment."
		Wait-ForExplicitContinue
		return
	}

	# Build array with user counts
	$groupData = @()
	Write-Host "Gathering group information, please wait..." -ForegroundColor Yellow
	
	foreach ($group in $groups) {
		# Get group members and filter for user objects only
		$groupMembers = Get-ADGroupMember -Identity $group.DistinguishedName -Recursive | Where-Object { $_.objectClass -eq 'user' }
		$userCount = $groupMembers.Count
		
		# Only add groups that contain users
		if ($userCount -gt 0) {
			$groupData += [PSCustomObject]@{
				Name              = $group.Name
				UserCount         = $userCount
				DistinguishedName = $group.DistinguishedName
				Group             = $group
			}
		}
	}

	if ($groupData.Count -eq 0) {
		Write-Host "No groups with user members found in the environment."
		Wait-ForExplicitContinue
		return
	}

	# Display groups in a structured list
	Clear-Host
	Write-Host "=== Available Groups (with user members) ===" -ForegroundColor Cyan
	Write-Host ""
	
	for ($i = 0; $i -lt $groupData.Count; $i++) {
		Write-Host ("{0,3}. {1,-40} Users: {2,5}" -f ($i + 1), $groupData[$i].Name, $groupData[$i].UserCount)
	}
	
	Write-Host ""
	Write-Host "  0. Cancel" -ForegroundColor Red
	Write-Host ""

	# Prompt for selection
	$selection = Read-Host "Enter your choice"
	
	# Handle cancel
	if ($selection -eq "0") { 
		return 
	}
	
	# Validate numeric selection
	if (-not ($selection -match '^\d+$')) {
		Write-Host "Invalid selection. Please enter a number." -ForegroundColor Red
		Wait-WithDelay
		return
	}
	
	$index = [int]$selection - 1
	
	if ($index -lt 0 -or $index -ge $groupData.Count) {
		Write-Host "Invalid selection. Number out of range." -ForegroundColor Red
		Wait-WithDelay
		return
	}

	$selectedGroupData = $groupData[$index]
	$selectedGroup = $selectedGroupData.Group
	$groupName = $selectedGroupData.Name
	
	Clear-Host
	Write-Host "Selected Group: $groupName" -ForegroundColor Green
	Write-Host "Distinguished Name: $($selectedGroup.DistinguishedName)" -ForegroundColor Gray
	Write-Host ""

	# Get users in the selected group
	$groupMembers = Get-ADGroupMember -Identity $selectedGroup.DistinguishedName -Recursive | Where-Object { $_.objectClass -eq 'user' }
	$users = $groupMembers | ForEach-Object { Get-ADUser -Identity $_.DistinguishedName -Properties SamAccountName, Enabled }

	if ($users.Count -eq 0) {
		Write-Host "No users found in the selected group." -ForegroundColor Yellow
		Wait-ForExplicitContinue
		return
	}

	# Count active and disabled users
	$activeCount = ($users | Where-Object { $_.Enabled -eq $true }).Count
	$disabledCount = ($users | Where-Object { $_.Enabled -eq $false }).Count

	$filteredUsers = $users
	
	Write-Host "Users in group '$groupName':" -ForegroundColor Cyan
	Write-Host "  Active: $activeCount" -ForegroundColor Green
	Write-Host "  Disabled: $disabledCount" -ForegroundColor Red
	Write-Host ""

	if ($disabledCount -gt 0) {
		$IncludeDisabled = Read-Host "Do you want to include disabled users in the dataset? `n	1. Yes `n	2. No `nEnter choice (1-2)"
		if ($IncludeDisabled -eq "1") {
			Write-Host "Including both active and disabled users." -ForegroundColor Yellow
		}
		else {
			$filteredUsers = $filteredUsers | Where-Object { $_.Enabled -eq $true }
			Write-Host "Including only active users." -ForegroundColor Green
		}
	}
	
	# Display SAM names
	Clear-Host
	Write-Host "SAM Names in the selected '$groupName' group:" -ForegroundColor Cyan
	Write-Host ""
	$filteredUsers | ForEach-Object { Write-Host "  $($_.SamAccountName)" }
	Write-Host ""
	
	$importChoice = Read-Host "Do you want to import these $($filteredUsers.Count) users into the dataset? `n	1. Yes `n	2. No `nEnter choice (1-2)"
	if ($importChoice -eq "1") {
		$global:DisplayAndSelectName = $groupName
		$global:DisplayAndSelectFilteredItem = $filteredUsers
		ApplySelectionToDataset
	}
	elseif ($importChoice -eq "2") {
		Write-Host "Import cancelled."
		Wait-WithDelay
	}
	else {
		Write-Host "Invalid choice. Import cancelled."
		Wait-WithDelay
	}
}

function ImportByFile {
	Clear-Host
	Write-Host "=== Import by File ===" -ForegroundColor Cyan
	Write-Host "File Importing supports CSV files with either a single column of usernames `nor multiple columns with a 'SamAccountName' or 'username' header." -ForegroundColor Yellow
	Read-Host "Please select the CSV file containing user data. `nPress Enter to continue"
	$file = New-Object System.Windows.Forms.OpenFileDialog -Property @{
		InitialDirectory = [Environment]::GetFolderPath('Desktop')
		Filter           = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
		Title            = "Select CSV File"
	}
	$dialogResult = $file.ShowDialog()
    
	if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
		Write-Host "Importing users from $($file.FileName)..."
		Wait-WithDelay
		$filePath = $file.FileName
		# Check if file is empty
		$lines = Get-Content $filePath
		if ($lines.Count -eq 0) {
			Write-Host "The file is empty. No users imported." -ForegroundColor Red
			Wait-WithDelay
			return
		}
        
		$users = @()
		#CSV Parsing
		try {
			# Try to import as CSV first
			$csvData = Import-Csv $filePath
			
			if ($csvData -and $csvData[0].PSObject.Properties.Name -contains 'SamAccountName') {
				# Multi-column CSV with SamAccountName header
				$users = $csvData | Select-Object -ExpandProperty SamAccountName | ForEach-Object { [PSCustomObject]@{SamAccountName = $_ } }
			}
			elseif ($csvData -and $csvData[0].PSObject.Properties.Name -contains 'username') {
				# Multi-column CSV with username header (like userlist.csv)
				$users = $csvData | Select-Object -ExpandProperty username | ForEach-Object { [PSCustomObject]@{SamAccountName = $_ } }
			}
			else {
				# Check if it's a single column file
				$firstLine = $lines[0].Trim()
				if ($firstLine -eq 'SamAccountName' -or $firstLine -eq 'username') {
					# Has header, skip it
					$dataLines = $lines[1..($lines.Count - 1)]
				}
				else {
					# No header, use all lines
					$dataLines = $lines
				}
				# Create objects from single column data
				$users = $dataLines | Where-Object { $_ -and $_.Trim() } | ForEach-Object { [PSCustomObject]@{SamAccountName = $_.Trim() } }
			}
		}
		catch {
			Write-Host "Error parsing CSV file: $_"
			Write-Host "Attempting to parse as simple text file..."
			# Fallback: treat as single column
			$firstLine = $lines[0].Trim()
			if ($firstLine -eq 'SamAccountName' -or $firstLine -eq 'username') {
				$dataLines = $lines[1..($lines.Count - 1)]
			}
			else {
				$dataLines = $lines
			}
			$users = $dataLines | Where-Object { $_ -and $_.Trim() } | ForEach-Object { [PSCustomObject]@{SamAccountName = $_.Trim() } }
		}
        
		# Detect duplicates within the import file
		$seenUsers = @{}
		$usersWithoutDuplicates = @()
		foreach ($user in $users) {
			if ($seenUsers.ContainsKey($user.SamAccountName)) {
				Write-Host "   $($user.SamAccountName)" -ForegroundColor DarkYellow
			}
			else {
				$seenUsers[$user.SamAccountName] = $true
				$usersWithoutDuplicates += $user
			}
		}
		
		if ($usersWithoutDuplicates.Count -lt $users.Count) {
			Write-Host "Removed $($users.Count - $usersWithoutDuplicates.Count) duplicate(s) from import file." -ForegroundColor Yellow
		}
		
		# Validate users exist in AD
		$validUsers = @()
		foreach ($user in $usersWithoutDuplicates) {
			try {
				$adUser = Get-ADUser -Identity $user.SamAccountName -ErrorAction Stop
				Write-Host "   $($user.SamAccountName)" -ForegroundColor Green
				$validUsers += [PSCustomObject]@{SamAccountName = $user.SamAccountName }
			}
			catch {
				Write-Host "   $($user.SamAccountName)" -ForegroundColor Red
			}
		}
        
		if ($validUsers.Count -eq 0) {
			Write-Host "No valid users were found in the file. Please check the file and try again."
			Wait-ForExplicitContinue
			return
		}
        
		if ($validUsers.Count -gt 0) {
			$global:DisplayAndSelectFilteredItem += $validUsers
			$global:DisplayAndSelectName = Split-Path $filePath -Leaf
			ApplySelectionToDataset
		}
		else {
			Write-Host "No valid users were imported after filtering. Please check the file and try again."
			Wait-ForExplicitContinue
		}
	}
}

function ImportByUsername {
	Clear-Host
	Write-Host "=== Import by Username ===" -ForegroundColor Cyan
	Write-Host "Enter one or more SAM account names (comma or space separated)." -ForegroundColor Gray
	Write-Host "Type 0 to cancel." -ForegroundColor Yellow
	Write-Host ""

	$inputString = Read-Host "SAM account names"
	if ($inputString -eq "0") {
		return
	}

	# Parse and de-duplicate user input
	$rawEntries = $inputString -split "[,\s]+" | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
	$uniqueEntries = @()
	$seenEntries = @{}
	foreach ($entry in $rawEntries) {
		if (-not $seenEntries.ContainsKey($entry)) {
			$seenEntries[$entry] = $true
			$uniqueEntries += $entry
		}
	}

	if ($uniqueEntries.Count -eq 0) {
		Write-Host "No valid usernames were provided." -ForegroundColor Red
		Wait-ForExplicitContinue
		return
	}

	$validUsers = @()
	$notFound = @()
	$dupInInput = @()
	$processed = @{}

	Write-Host "Validation results:" -ForegroundColor Cyan

	foreach ($sam in $uniqueEntries) {
		# Check duplicate within input (already handled, but keep message for clarity)
		if ($processed.ContainsKey($sam)) {
			Write-Host "   $sam" -ForegroundColor DarkYellow -NoNewline
			Write-Host " (duplicate in input - skipped)" -ForegroundColor Gray
			$dupInInput += $sam
			continue
		}
		$processed[$sam] = $true

		try {
			$user = Get-ADUser -Identity $sam -Properties SamAccountName, Enabled -ErrorAction Stop
			Write-Host "   $($user.SamAccountName)" -ForegroundColor Green -NoNewline
			Write-Host " (found)" -ForegroundColor Gray
			$validUsers += $user
		}
		catch {
			Write-Host "   $sam" -ForegroundColor Red -NoNewline
			Write-Host " (not found)" -ForegroundColor Gray
			$notFound += $sam
		}
	}

	if ($validUsers.Count -eq 0) {
		Write-Host "" 
		Write-Host "No valid users were found to import." -ForegroundColor Red
		Wait-ForExplicitContinue
		return
	}

	# Stage the valid users for dataset merge
	$global:DisplayAndSelectFilteredItem = $validUsers
	$global:DisplayAndSelectName = "Manual Username Import"

	Write-Host "" 
	Write-Host "Importing validated users into dataset..." -ForegroundColor Cyan
	ApplySelectionToDataset
}

function ResetDatasetUserPasswords_identical {
	Clear-Host
	Refresh-CurrentDatasetStatus
	Test-DatasetPopulated
	Write-Host "=== Reset Users to Same String ===" -ForegroundColor Cyan
		$NewPasswordPlain = GeneratePassword
		Write-Host "Please note that the following Changes will be made to each user: `n	- ChangePasswordAtLogon flag will be set to True`n	- PasswordNeverExpires will be set to False`n	- All User passwords in the current dataset will be reset." -ForegroundColor Yellow
		Write-Host "`nThe new password to be set for all users in the dataset is: $NewPasswordPlain" -ForegroundColor Green
		$NewPassword = ConvertTo-SecureString -String $NewPasswordPlain -AsPlainText -Force
		Write-Host "`nPlease select one of the following options to continue:"
		$SetSameStringbyOUConfirmRead = Read-Host "`n 	1. Continue with Reset `n	2. Regenerate Password `n	0. Cancel`nChoice"
	do {
		switch ($SetSameStringbyOUConfirmRead) {
			"0" {
				Show-ManageUsersMenu
			}
			"1" {
				Read-Host "- Please ensure the password has been documented, as it will not be shown again."
				Clear-Host
				Write-Host "=== Reset Users to Same String ===" -ForegroundColor Cyan
				Write-Host "Proceeding with password reset..."
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADAccountPassword -Identity $($user.SamAccountName) -NewPassword $NewPassword -Reset
						Set-ADUser -Identity $($user.SamAccountName) -PasswordNeverExpires $false -ChangePasswordAtLogon $true
						Write-Host "	-  Password for user $($user.SamAccountName) has been reset." -ForegroundColor Green
					}
					catch {
						Write-Host "	-  Failed to reset password for user $($user.SamAccountName): $_" -ForegroundColor Red
					}
				}
				Write-Host "`nAll Users within the dataset have had the same password set."
				Read-Host "`nPress Enter to Continue"
				Clear-Host
				return
			}
			"2" {
				# Regenerate password, continue loop
				ResetDatasetUserPasswords_identical
			}
			default {
				Write-Host "Invalid option. Please try again."
				Wait-WithDelay
				continue
			}
		}
	} while ($true)
}

function ResetDatasetUserPasswords_unique {
	Clear-Host
	Refresh-CurrentDatasetStatus
	Test-DatasetPopulated
	Write-Host "=== Reset User to Unique Strings ===" -ForegroundColor Cyan
	Write-Host "Please note that the following Changes will be made to each user: `n	- ChangePasswordAtLogon flag will be set to True`n	- PasswordNeverExpires will be set to False`n	- All User passwords in the current dataset will be reset." -ForegroundColor Yellow
	$Time = Get-Date -Format "yyyyMMdd-HHmmss"
	$OutputFile = "$PWD\NewPasswordsPlain-$Time.csv"
	Write-Host "`nPlease select one of the following options to continue:"
	$choice = Read-Host "	1. Continue with Reset `n	0. Cancel`nChoice"
	do {
		switch ($choice) {
			"0" {
				return
			}

			"1" {
				foreach ($user in $global:CurrentDataset) {
					$NewPasswordPlain = GeneratePassword
					$NewPassword = ConvertTo-SecureString -String $NewPasswordPlain -AsPlainText -Force
					try {
						Set-ADAccountPassword -Identity $user.SamAccountName -NewPassword $NewPassword -Reset
						Set-ADUser -Identity $user.SamAccountName -PasswordNeverExpires $false -ChangePasswordAtLogon $true
						Write-Host "   Password for user $($user.SamAccountName) has been set to a unique password." -ForegroundColor Green
						[PSCustomObject]@{
							SamAccountName = $user.SamAccountName
							Password = $NewPasswordPlain
						} | Export-Csv -Path $OutputFile -Append -Encoding UTF8 -NoTypeInformation
					}
					catch {
						Write-Host "   Failed to reset password for user $($user.SamAccountName): $_" -ForegroundColor Red
					}
				}
				Write-Host "`n$OutputFile has been created with unique passwords for each user." -ForegroundColor Green
				Write-Host "Ensure that this file is stored securely and deleted after use.`n" -ForegroundColor Red
				Read-Host "Press Enter to Continue"
				Clear-Host
				return
			}
			default {
				Write-Host "Invalid option. Please try again."
				Wait-WithDelay
				continue
			}
		}
	} while ($true)
}

function Set-PasswordNeverExpiresFlag {
	do {
		Clear-Host
		Refresh-CurrentDatasetStatus
		Write-Host "=== Set PasswordNeverExpires Flag ===" -ForegroundColor Cyan
		Test-DatasetPopulated		
		if ($global:CurrentDataset.Count -eq 0) {
			return
		}

		Write-Host "Set PasswordNeverExpires flag to True or False for the current users in the dataset?"
		Write-Host "Users in dataset: $($global:CurrentDataset.Count)"
		Write-Host ""
		Write-Host "1. Set to True"
		Write-Host "2. Set to False"
		Write-Host "0. Cancel"
		Write-Host ""
		
		$choice = Read-Host "Select an option (0-2)"
		
		switch ($choice) {
			"1" {
				$flagValue = $true
				Clear-Host
				Write-Host "=== Setting PasswordNeverExpires to True ===" -ForegroundColor Cyan
				Write-Host "Processing users..."
				Write-Host ""
				
				$successCount = 0
				$failureCount = 0
				$failedUsers = @()
				
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADUser -Identity $user.SamAccountName -PasswordNeverExpires $flagValue -ErrorAction Stop
						Write-Host "   Flag set to $flagValue for $($user.SamAccountName)" -ForegroundColor Green
						$successCount++
					} 
					catch {
						Write-Host "   Failed to set flag for $($user.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
						$failureCount++
						$failedUsers += $user.SamAccountName
					}
				}
				
				Write-Host ""
				Write-Host "Summary:"
				Write-Host "  Successful: $successCount"
				Write-Host "  Failed: $failureCount"
				
				if ($failureCount -gt 0) {
					Write-Host ""
					Write-Host "Failed users:" -ForegroundColor Red
					$failedUsers | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
				}
				
				Wait-ForExplicitContinue
			}
			
			"2" {
				$flagValue = $false
				Clear-Host
				Write-Host "=== Setting PasswordNeverExpires to False ===" -ForegroundColor Cyan
				Write-Host "Processing users..."
				Write-Host ""
				
				$successCount = 0
				$failureCount = 0
				$failedUsers = @()
				
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADUser -Identity $user.SamAccountName -PasswordNeverExpires $flagValue -ErrorAction Stop
						Write-Host "   Flag set to $flagValue for $($user.SamAccountName)" -ForegroundColor Green
						$successCount++
					} 
					catch {
						Write-Host "   Failed to set flag for $($user.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
						$failureCount++
						$failedUsers += $user.SamAccountName
					}
				}
				
				Write-Host ""
				Write-Host "Summary:"
				Write-Host "  Successful: $successCount"
				Write-Host "  Failed: $failureCount"
				
				if ($failureCount -gt 0) {
					Write-Host ""
					Write-Host "Failed users:" -ForegroundColor Red
					$failedUsers | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
				}
				
				Wait-ForExplicitContinue
			}
			
			"0" {
				return
			}
			
			default {
				Write-Host "Invalid option. Please try again." -ForegroundColor Red
				Wait-WithDelay
			}
		}
	} while ($true)
}

function Set-ChangePasswordAtLogonFlag {
	do {
		Clear-Host
		Refresh-CurrentDatasetStatus
		Write-Host "=== Set ChangePasswordAtLogon Flag ===" -ForegroundColor Cyan
		Test-DatasetPopulated
		
		if ($global:CurrentDataset.Count -eq 0) {
			return
		}

		Write-Host "Set ChangePasswordAtLogon flag to True or False for the current users in the dataset? Users in dataset: $($global:CurrentDataset.Count)"
		Write-Host "### Warning: This feature will also set the PasswordNeverExpires to False." -ForegroundColor Red
		Write-Host "### ChangePasswordAtLogon can not be set to True without PasswordNeverExpires first bring set to False." -ForegroundColor Red
		Write-Host ""
		Write-Host "1. Set to True"
		Write-Host "2. Set to False"
		Write-Host "0. Cancel"
		Write-Host ""
		
		$choice = Read-Host "Select an option (0-2)"
		
		switch ($choice) {
			"1" {
				Clear-Host
				Write-Host "=== Setting ChangePasswordAtLogon to True ==="
				Write-Host "Processing users..."
				Write-Host ""
				
				$successCount = 0
				$failureCount = 0
				$failedUsers = @()
				
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADUser -Identity $user.SamAccountName -PasswordNeverExpires $false -ChangePasswordAtLogon $true -ErrorAction Stop
						Write-Host "   Flag set to True for $($user.SamAccountName)" -ForegroundColor Green
						$successCount++
					} 
					catch {
						Write-Host "   Failed to set flag for $($user.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
						$failureCount++
						$failedUsers += $user.SamAccountName
					}
				}
				Write-Host ""
				Write-Host "Summary:"
				Write-Host "  Successful: $successCount"
				Write-Host "  Failed: $failureCount"
				if ($failureCount -gt 0) {
					Write-Host ""
					Write-Host "Failed users:" -ForegroundColor Red
					$failedUsers | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
					Write-Host ""
				}
				Wait-ForExplicitContinue
				}
			
			"2" {

				Clear-Host
				Write-Host "=== Setting ChangePasswordAtLogon to False ===" -ForegroundColor Cyan
				Write-Host "Processing users..."
				Write-Host ""
				
				$successCount = 0
				$failureCount = 0
				$failedUsers = @()
				
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADUser -Identity $user.SamAccountName -ChangePasswordAtLogon $false -ErrorAction Stop
						Write-Host "   Flag set to False for $($user.SamAccountName)" -ForegroundColor Green
						$successCount++
					} 
					catch {
						Write-Host "   Failed to set flag for $($user.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
						$failureCount++
						$failedUsers += $user.SamAccountName
					}
				}
				
				Write-Host ""
				Write-Host "Summary:"
				Write-Host "  Successful: $successCount"
				Write-Host "  Failed: $failureCount"
				
				if ($failureCount -gt 0) {
					Write-Host ""
					Write-Host "Failed users:" -ForegroundColor Red
					$failedUsers | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
					Write-Host ""
				}
				
				Wait-ForExplicitContinue
			}
						
			"0" {
				return
			}
			
			default {
				Write-Host "Invalid option. Please try again." -ForegroundColor Red
				Wait-WithDelay
			}
		}
	} while ($true)
}

function ExportUsersWithPasswordNeverExpires {
	Clear-Host
	Write-Host "=== Users with PasswordNeverExpires set to True ===" -ForegroundColor Cyan
	$users = Get-ADUser -Filter { PasswordNeverExpires -eq $true } -Properties SamAccountName, PasswordNeverExpires
	if ($users.Count -eq 0) {
		Write-Host "No users found."
		Wait-ForExplicitContinue
		return
	}
	else {
		Write-Host "Users whose PasswordNeverExpires is True"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "PasswordNeverExpires"; Expression = { $_.PasswordNeverExpires } } -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue"
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersPasswordNeverExpiresTrue-$Time.csv"
		$users | Select-Object SamAccountName, PasswordNeverExpires | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath" -ForegroundColor Green
	}
	Wait-ForExplicitContinue
}

function ExportUsersWithChangePasswordAtLogon {
	Clear-Host
	Write-Host "=== Users with ChangePasswordAtLogon set to True ===" -ForegroundColor Cyan
	
	# Query users and check pwdLastSet = 0 (indicates must change password)
	$users = Get-ADUser -Filter * -Properties pwdLastSet, SamAccountName | Where-Object { $_.pwdLastSet -eq 0 }
	
	if ($users.Count -eq 0) {
		Write-Host "No users found with ChangePasswordAtLogon flag set."
		Wait-ForExplicitContinue
		return
	}
	else {
		Write-Host "Users who must change password at next logon:"
		Write-Host ""
		$users | ForEach-Object { Write-Host "  - $($_.SamAccountName)" }
		Write-Host ""
		Write-Host "Total: $($users.Count) users" -ForegroundColor Cyan
	}
	
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue"
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersWithChangePasswordAtLogon-$Time.csv"
		$users | Select-Object SamAccountName | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath" -ForegroundColor Green
	}
	Wait-ForExplicitContinue
}

function DisplayAndExportNotChangedToday {
	Clear-Host
	Write-Host "=== Users whose Passwords were NOT changed today ===" -ForegroundColor Cyan
	$today = (Get-Date).Date
	$users = Get-ADUser -Filter * -Properties SamAccountName, PasswordLastSet | Where-Object { $_.PasswordLastSet -lt $today }
	if ($users.Count -eq 0) {
		Write-Host "All users have changed their passwords today."
		Wait-ForExplicitContinue
		return
	}
 else {
		Write-Host "Users whose passwords were NOT changed today:"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "PasswordLastSet"; Expression = { $_.PasswordLastSet } } -AutoSize
		Write-Host "NOTE: Blank data typically means the account has ChangePasswordAtLogon set to True" -ForegroundColor yellow
		$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue"
		if ($ViewUserExport -eq "1") {
			$Time = Get-Date -Format "yyyyMMdd-HHmmss"
			$ExportPath = "$PWD\UsersNotChangedToday-$Time.csv"
			$users | Select-Object SamAccountName, PasswordLastSet | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
			Write-Host "Users exported to $ExportPath" -ForegroundColor Green
		}
		else {
			return
		}
	}
	Wait-ForExplicitContinue
}

function ExportUsersChangedToday {
	Clear-Host
	Write-Host "=== Users whose Passwords were changed today ===" -ForegroundColor Cyan
	$today = (Get-Date).Date
	$users = Get-ADUser -Filter * -Properties SamAccountName, PasswordLastSet | Where-Object { $_.PasswordLastSet -ge $today }
	if ($users.Count -eq 0) {
		Write-Host "No users have changed their passwords today." -ForegroundColor Yellow
		Wait-ForExplicitContinue
		return
	}
	else {
		Write-Host "Users whose passwords were changed today:"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "PasswordLastSet"; Expression = { $_.PasswordLastSet } } -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue"
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersChangedToday-$Time.csv"
		$users | Select-Object SamAccountName, PasswordLastSet | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath" -ForegroundColor Green
	}
	else {
		return
	}
	Wait-ForExplicitContinue
}

function DisplayAndExportLastPasswordChange {
	Clear-Host
	Write-Host "=== All Users with LastPasswordChange Date ===" -ForegroundColor Cyan
	$users = Get-ADUser -Filter * -Properties SamAccountName, PasswordLastSet
	if ($users.Count -eq 0) {
		Write-Host "No users found."
		Wait-ForExplicitContinue
		return
	}
 else {
		Write-Host "Users and their LastPasswordChange dates:"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "PasswordLastSet"; Expression = { $_.PasswordLastSet } } -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue"
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\AllUsersWithLastPasswordChangeDate-$Time.csv"
		$users | Select-Object SamAccountName, PasswordLastSet | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath" -ForegroundColor Green
		Write-Host "NOTE: Blank data typically means the account has ChangePasswordAtLogon set to True" -ForegroundColor Yellow
		Write-Host "NOTE: These users will have to change their password at next logon, but have not done this yet" -ForegroundColor Yellow
	}
	Wait-ForExplicitContinue
}

function ExportAllUsersWithAttributes {
	Clear-Host
	Write-Host "=== Export All Users with Selected Attributes ===" -ForegroundColor Cyan
	Read-Host "This will export the following user attributes:`n		- SamName`n		- Last Logon`n		- PasswordLastSet`n		- PasswordNeverExpires`n		- ChangePasswordAtNextLogon/pwdLastSet `n Press Enter to start."
	# Query pwdLastSet instead of ChangePasswordAtLogon (which doesn't exist as an attribute)
	$users = Get-ADUser -Filter * -Properties SamAccountName, LastLogon, PasswordLastSet, PasswordNeverExpires, pwdLastSet
	if ($users.Count -eq 0) {
		Write-Host "No users have been found."
		Wait-ForExplicitContinue
		return
	}
 else {
		# Calculate ChangePasswordAtLogon from pwdLastSet (0 = must change password)
		# Convert LastLogon from FileTime to readable DateTime
		$usersWithCalculated = $users | Select-Object SamAccountName, @{Name="LastLogon"; Expression={ if ($_.LastLogon -ne 0) { [DateTime]::FromFileTime($_.LastLogon) } else { $null }}}, PasswordLastSet, PasswordNeverExpires, @{Name="ChangePasswordAtLogon"; Expression={ $_.pwdLastSet -eq 0 }}
		$usersWithCalculated | Format-Table -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue"
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\AllUsersCommonAttributes-$Time.csv"
		# Calculate ChangePasswordAtLogon from pwdLastSet for export and convert LastLogon to readable date
		$users | Select-Object SamAccountName, @{Name="LastLogon"; Expression={ if ($_.LastLogon -ne 0) { [DateTime]::FromFileTime($_.LastLogon) } else { $null }}}, PasswordLastSet, PasswordNeverExpires, @{Name="ChangePasswordAtLogon"; Expression={ $_.pwdLastSet -eq 0 }} | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "ChangePasswordAtLogon indicates if the user must change their password at next logon." -ForegroundColor Yellow
		Write-Host "A null or blank value in PasswordLastSet typically means the account has ChangePasswordAtLogon set to True." -ForegroundColor Yellow
		Write-Host "Users exported to $ExportPath" -ForegroundColor Green
	}
	Wait-ForExplicitContinue
}

function ExportAllUsersFullData {
	Clear-Host
	Write-Host "=== Export All Users & Data ===" -ForegroundColor Cyan
	Read-Host "This will export all Users & All User attributes. This may take a while."
	$users = Get-ADUser -Filter * -Properties *
	if ($users.Count -eq 0) {
		Write-Host "No users have been found."
		Wait-WithDelay
		return
	}
 else {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\AllUsersAllAttributes-$Time.csv"
		$users | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath" -ForegroundColor Green
		Wait-ForExplicitContinue
	}
}

function ExportUsersWithEnabledDisabledStatus {
	Clear-Host
	Write-Host "=== View/Export Users by Enabled/Disabled Status ===" -ForegroundColor Cyan
	Write-Host ""
	Write-Host "Select which users to view/export:" -ForegroundColor Yellow
	Write-Host "  1. Enabled Users Only"
	Write-Host "  2. Disabled Users Only"
	Write-Host "  3. All Users with Status"
	Write-Host "  0. Back to Reports Menu"
	Write-Host ""
	
	$filterChoice = Read-Host "Enter your choice (0-3)"
	
	switch ($filterChoice) {
		0 { return }
		1 {
			# Enabled users only
			Clear-Host
			Write-Host "=== Enabled Users ===" -ForegroundColor Green
			$users = Get-ADUser -Filter { Enabled -eq $true } -Properties SamAccountName, Enabled
			if ($users.Count -eq 0) {
				Write-Host "No enabled users found." -ForegroundColor Yellow
				Wait-ForExplicitContinue
				return
			}
			Write-Host "Total Enabled Users: $($users.Count)" -ForegroundColor Green
			Write-Host ""
			$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName }}, @{Name = "Status"; Expression = { "Enabled" }} -AutoSize
		}
		2 {
			# Disabled users only
			Clear-Host
			Write-Host "=== Disabled Users ===" -ForegroundColor Red
			$users = Get-ADUser -Filter { Enabled -eq $false } -Properties SamAccountName, Enabled
			if ($users.Count -eq 0) {
				Write-Host "No disabled users found." -ForegroundColor Yellow
				Wait-ForExplicitContinue
				return
			}
			Write-Host "Total Disabled Users: $($users.Count)" -ForegroundColor Red
			Write-Host ""
			$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName }}, @{Name = "Status"; Expression = { "Disabled" }} -AutoSize
		}
		3 {
			# All users with status
			Clear-Host
			Write-Host "=== All Users with Status ===" -ForegroundColor Cyan
			$users = Get-ADUser -Filter * -Properties SamAccountName, Enabled
			if ($users.Count -eq 0) {
				Write-Host "No users found." -ForegroundColor Yellow
				Wait-ForExplicitContinue
				return
			}
			
			# Calculate counts in a single pass using Group-Object
			$groupedUsers = $users | Group-Object -Property Enabled
			$enabledCount = ($groupedUsers | Where-Object { $_.Name -eq 'True' }).Count
			if ($null -eq $enabledCount) { $enabledCount = 0 }
			$disabledCount = ($groupedUsers | Where-Object { $_.Name -eq 'False' }).Count
			if ($null -eq $disabledCount) { $disabledCount = 0 }
			
			Write-Host "Total Users: $($users.Count)" -ForegroundColor Cyan
			Write-Host "  Enabled: $enabledCount" -ForegroundColor Green
			Write-Host "  Disabled: $disabledCount" -ForegroundColor Red
			Write-Host ""
			
			# Display users with color-coded status
			$users | Sort-Object Enabled -Descending | ForEach-Object {
				$statusText = if ($_.Enabled) { "Enabled" } else { "Disabled" }
				$statusColor = if ($_.Enabled) { "Green" } else { "Red" }
				Write-Host ("{0,-30}" -f $_.SamAccountName) -NoNewline
				Write-Host " [$statusText]" -ForegroundColor $statusColor
			}
			Write-Host ""
		}
		default {
			Write-Host "Invalid option. Returning to Reports Menu." -ForegroundColor Red
			Wait-WithDelay
			return
		}
	}
	
	# Export option
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue"
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$filterName = switch ($filterChoice) {
			1 { "EnabledUsers" }
			2 { "DisabledUsers" }
			3 { "AllUsersWithStatus" }
		}
		$ExportPath = "$PWD\$filterName-$Time.csv"
		$users | Select-Object SamAccountName, @{Name="Status"; Expression={ if ($_.Enabled) { "Enabled" } else { "Disabled" }}} | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath" -ForegroundColor Green
	}
	Wait-ForExplicitContinue
}

function ResetkrbtgtPasswordNow {
	Clear-Host
	Write-Host "=== krbtgt Password Reset Now ===" -ForegroundColor Cyan
	$LastResetTime = (Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet).PasswordLastSet
	Write-Host "This is a basic krbtgt password reset script."
	Write-Host "It currently does not support checks such as DC sync status or replication status." -ForegroundColor Yellow
	Write-Host "Ensure you have reviewed the environment status before proceeding, `nor utilise an alternative script with such checks."
	Write-Host "This action will reset the krbtgt account password immediately upon confirmation."
	Write-Host "Proceed with caution." -BackgroundColor Yellow -ForegroundColor Red
	Write-Host "==="
	Write-Host "The last krbtgt password reset was at $LastResetTime" -ForegroundColor Gray
	$confirmation = Read-Host "Are you sure you want to reset the krbtgt account password now? `n  1. Yes `n  2. No `nEnter choice (1-2)"
	if ($confirmation -eq "1") {
		try {
			# Generate complex password using .NET crypto-random approach
			$password = -join ((33..126) | Get-Random -Count 32 | ForEach-Object {[char]$_})
			$newPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
			Set-ADAccountPassword -Identity "krbtgt" -NewPassword $newPassword -Reset
			Write-Host "krbtgt account password has been reset successfully." -ForegroundColor Green
			$newResetTime = (Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet).PasswordLastSet
			Write-Host "krbtgt account password last set: $newResetTime" -ForegroundColor Gray
		}
		catch {
			Write-Host "Failed to reset krbtgt password: $_" -ForegroundColor Red
		}
	}
	else {
		Write-Host "Operation cancelled by user." -ForegroundColor Yellow
	}
	Wait-ForExplicitContinue
}

function ResetkrbtgtPasswordScheduleSecond {
	Clear-Host
	Write-Host "=== Schedule Second krbtgt Password Reset ===" -ForegroundColor Cyan
	Write-Host "This will create a scheduled task to reset krbtgt password after a specified delay." -ForegroundColor Gray
	Write-Host "The task will prompt you to confirm before executing the reset.`n" -ForegroundColor Gray
	
	$lastReset = (Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet).PasswordLastSet
	Write-Host "Last krbtgt reset: $lastReset" -ForegroundColor Gray
	
	$confirmation = Read-Host "Are you sure you want to schedule a second krbtgt password reset? `n  1. Yes `n  2. No `nEnter choice (1-2)"
	if ($confirmation -ne "1") {
		Write-Host "Operation cancelled." -ForegroundColor Yellow
		Wait-ForExplicitContinue
		return
	}
	
	$ResetDelay = Read-Host "`nEnter the delay in hours before the scheduled reset (recommended: 10-48 hours)"
	
	# Validate input
	if ($ResetDelay -notmatch '^\d+$') {
		Write-Host "Invalid input. Please enter a valid number of hours." -ForegroundColor Red
		Wait-ForExplicitContinue
		return
	}
	
	$ResetDelay = [int]$ResetDelay
	if ($ResetDelay -lt 1 -or $ResetDelay -gt 168) {
		Write-Host "Delay must be between 1 and 168 hours (7 days)." -ForegroundColor Red
		Wait-ForExplicitContinue
		return
	}
	
	if ($ResetDelay -lt 10) {
		Write-Host "Warning: Less than 10 hours delay is not recommended for replication." -ForegroundColor Yellow
	}
	
	try {
		# Calculate scheduled time
		$scheduledTime = (Get-Date).AddHours($ResetDelay)
		$taskName = "krbtgt-SecondPasswordReset-$(Get-Date -Format yyyyMMddHHmmss)"
		$taskDescription = "Scheduled second krbtgt password reset task created at $(Get-Date)"
		
		# Create the script that will run at scheduled time
		$scriptPath = "$PWD\krbtgt-SecondReset-Script-$([System.IO.Path]::GetRandomFileName()).ps1"
		
		# Generate the reset script with proper escaping
		$resetScript = @"
try {
	Import-Module ActiveDirectory
	`$lastReset = (Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet).PasswordLastSet
	
	# Clear screen and show prompt
	Clear-Host
	Write-Host "=== krbtgt Second Password Reset Scheduled Execution ===" -ForegroundColor Cyan
	Write-Host "Scheduled task triggered at: \$(Get-Date)" -ForegroundColor Gray
	Write-Host "Previous reset was at: `$lastReset" -ForegroundColor Gray
	Write-Host ""
	Write-Host "This is the second password reset in the krbtgt dual-reset procedure." -ForegroundColor Yellow
	Write-Host "Proceed with caution.`n" -ForegroundColor Yellow
	
	`$proceed = Read-Host "Do you want to proceed with the krbtgt password reset now? (1=Yes, 2=No)"
	
	if (`$proceed -eq "1") {
		try {
			# Generate complex password
			`$password = -join ((33..126) | Get-Random -Count 32 | ForEach-Object {[char]`$_})
			`$newPassword = ConvertTo-SecureString -String `$password -AsPlainText -Force
			Set-ADAccountPassword -Identity "krbtgt" -NewPassword `$newPassword -Reset
			Write-Host "krbtgt password reset completed successfully." -ForegroundColor Green
			`$newResetTime = (Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet).PasswordLastSet
			Write-Host "New password last set: `$newResetTime" -ForegroundColor Gray
		}
		catch {
			Write-Host "Failed to reset krbtgt password: `$_" -ForegroundColor Red
		}
	}
	else {
		Write-Host "Reset cancelled by user." -ForegroundColor Yellow
	}
	
	Read-Host "Press Enter to close this window"
	
	# Cleanup: Remove this script file after execution
	if (Test-Path "`$PSCommandPath") {
		try {
			Remove-Item -Path "`$PSCommandPath" -Force -ErrorAction SilentlyContinue
		}
		catch {
			# Script removal failed, but don't block the user
		}
	}
}
catch {
	Write-Host "An error occurred: `$_" -ForegroundColor Red
	Read-Host "Press Enter to close this window"
	
	# Cleanup attempt even on error
	if (Test-Path "`$PSCommandPath") {
		try {
			Remove-Item -Path "`$PSCommandPath" -Force -ErrorAction SilentlyContinue
		}
		catch {
		}
	}
}
"@
		
		# Write script to file
		$resetScript | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
		
		# Create scheduled task action
		$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
		$trigger = New-ScheduledTaskTrigger -Once -At $scheduledTime
		$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
		
		# Register the scheduled task
		Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description $taskDescription -Force | Out-Null
		
		Write-Host "`n" -ForegroundColor Green
		Write-Host " Scheduled task created successfully!" -ForegroundColor Green
		Write-Host "Task Name: $taskName" -ForegroundColor Green
		Write-Host "Scheduled Time: $($scheduledTime.ToString('dddd, MMMM dd, yyyy HH:mm:ss'))" -ForegroundColor Green
		Write-Host "Delay: $ResetDelay hours from now" -ForegroundColor Green
		Write-Host "Script Path: $scriptPath" -ForegroundColor Gray
		Write-Host "`nThe task will display a prompt to confirm the reset when it runs." -ForegroundColor Gray
		Write-Host "`nNote: The script file will be automatically cleaned up after execution." -ForegroundColor Yellow
	}
	catch {
		Write-Host "Failed to create scheduled task: $_" -ForegroundColor Red
	}
	
	Wait-ForExplicitContinue
}


function ApplySelectionToDataset {
	Clear-Host
	Write-Host "=== Importing Users to Dataset ===" -ForegroundColor Cyan
	Write-Host ""
	
	# Set the CurrentDatasetName
	if ($global:CurrentDatasetName -eq "None") {
		$global:CurrentDatasetName = $global:DisplayAndSelectName
	}
	elseif ($global:CurrentDatasetName -ne "None" -and $global:CurrentDatasetName -ne "Multiple") {
		$global:CurrentDatasetName = "Multiple"
	}
	
	# Always exclude these accounts
	$currentUser = $env:USERNAME
	$excludedSamNames = @(
		"Administrator",
		"krbtgt",
		$currentUser
	)

	$excludedLookup = @{}
	foreach ($name in $excludedSamNames) {
		if ($name -and -not $excludedLookup.ContainsKey($name)) {
			$excludedLookup[$name] = $true
		}
	}

	# Get existing SAM names for quick lookup
	$existingSamNames = @{}
	foreach ($user in $global:CurrentDataset) {
		$existingSamNames[$user.SamAccountName] = $true
	}
	
	# Track statistics
	$newUsersCount = 0
	$existingUsersCount = 0
	$duplicatesInImportCount = 0
	$excludedUsersCount = 0
	$processedSamNames = @{}
	$usersToAdd = @()
	
	Write-Host "Processing users from '$global:DisplayAndSelectName':"
	Write-Host ""
	
	# Process each user in the import
	foreach ($user in $global:DisplayAndSelectFilteredItem) {
		$samName = $user.SamAccountName

		# Always exclude protected accounts
		if ($excludedLookup.ContainsKey($samName)) {
			Write-Host "   $samName" -ForegroundColor DarkYellow -NoNewline
			Write-Host " (excluded account)" -ForegroundColor Gray
			$excludedUsersCount++
			continue
		}
		
		# Check if this is a duplicate within the import itself
		if ($processedSamNames.ContainsKey($samName)) {
			Write-Host "   $samName" -ForegroundColor DarkYellow -NoNewline
			Write-Host " (duplicate in import - skipped)" -ForegroundColor Gray
			$duplicatesInImportCount++
			continue
		}
		
		# Mark as processed
		$processedSamNames[$samName] = $true
		
		# Check if user already exists in current dataset
		if ($existingSamNames.ContainsKey($samName)) {
			Write-Host "   $samName" -ForegroundColor Red -NoNewline
			Write-Host " (already in dataset)" -ForegroundColor Gray
			$existingUsersCount++
		}
		else {
			Write-Host "   $samName" -ForegroundColor Green -NoNewline
			Write-Host " (new)" -ForegroundColor Gray
			$usersToAdd += $user
			$newUsersCount++
		}
	}
	
	# Add new users to the dataset
	$global:CurrentDataset += $usersToAdd
	
	# Final duplicate check and sort
	$beforeFinalCheck = $global:CurrentDataset.Count
	$global:CurrentDataset = $global:CurrentDataset | Sort-Object -Property SamAccountName -Unique
	$afterFinalCheck = $global:CurrentDataset.Count
	$finalDuplicatesRemoved = $beforeFinalCheck - $afterFinalCheck
	
	# Display summary
	Write-Host ""
	Write-Host "=== Import Summary ===" -ForegroundColor Cyan
	Write-Host "  New users added:           $newUsersCount" -ForegroundColor Green
	Write-Host "  Already in dataset:        $existingUsersCount" -ForegroundColor Red
	Write-Host "  Duplicates in import:      $duplicatesInImportCount" -ForegroundColor DarkYellow
	Write-Host "  Excluded accounts:         $excludedUsersCount" -ForegroundColor DarkYellow
	if ($finalDuplicatesRemoved -gt 0) {
		Write-Host "  Final duplicates removed:  $finalDuplicatesRemoved" -ForegroundColor Yellow
	}
	Write-Host ""
	Write-Host "  Total users in dataset:    $($global:CurrentDataset.Count)" -ForegroundColor Cyan
	
	# Clear temporary variables
	$global:DisplayAndSelectFilteredItem = $null
	$global:DisplayAndSelectName = $null
	
	Write-Host ""
	Wait-ForContinue
}

function Show-UserStatus {
	for ($i = 0; $i -lt $global:CurrentDataset.Count; $i++) {
		$user = $global:CurrentDataset[$i]
		$status = if ($user.Enabled) { "Active" } else { "Disabled" }
		$statusColor = if ($user.Enabled) { "Green" } else { "Red" }
		Write-Host ("{0,4}. {1,-30}" -f ($i + 1), $user.SamAccountName) -NoNewline
		Write-Host " [$status]" -ForegroundColor $statusColor
	}
	return
}

function GeneratePassword {
	$word1 = $global:words | Get-Random
	$word2 = $global:words | Get-Random
	$word3 = $global:words | Get-Random
    
	$num1 = Get-Random -Minimum 0 -Maximum 9
	$num2 = Get-Random -Minimum 0 -Maximum 9
	$num3 = Get-Random -Minimum 0 -Maximum 9
    
	$special = $global:specialChars | Get-Random

	$NewPasswordPlain = "$word1$word2$word3$num1$num2$num3$special"
	return $NewPasswordPlain
}

function Test-DatasetPopulated {
	if ($global:CurrentDataset.Count -eq 0) {
		Write-Host "The current dataset is empty. Unable to continue."
		Read-Host "Press Enter to Continue"
	}
 else {
		return
	}
}

function Refresh-CurrentDatasetStatus {
    if ($global:CurrentDataset.Count -eq 0) { return }

    # Query AD for current Enabled status of all users in dataset
    $updated = @()
    $notFound = @()

    foreach ($user in $global:CurrentDataset) {
        try {
            $adUser = Get-ADUser -Identity $user.SamAccountName -Properties Enabled -ErrorAction Stop
            # Preserve original object shape but update Enabled
            $updated += $adUser
        }
        catch {
            # Keep original entry, but track not found
            $notFound += $user.SamAccountName
            $updated += $user
        }
    }

    $global:CurrentDataset = $updated

    if ($notFound.Count -gt 0) {
        Write-Host "Warning: Some users could not be refreshed and were kept as-is:" -ForegroundColor Yellow
        $notFound | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        Start-Sleep -Seconds 1
    }
}

function Wait-ForContinue {
	Read-Host "Press Enter to Continue"
	#Start-Sleep -Seconds 2
}

function Wait-ForExplicitContinue {
	Read-Host "Press Enter to Continue"
}

function Wait-WithDelay {
	Start-Sleep -Seconds 2
}



Show-MainMenu
