<# 
# AIO_ADUsers_Password_Management

## About
- Designed for Administror use for the management of AD Users, quickly.
- Work in process, will eventually feature all items from the feature list below.


## Features
- [ ] Active Directory user password management
    - [x] Display, Select and Reset users based on OU
    - [x] Reset users based on external files (SAM Name)
    - [x] Export Users for resets
    - [x] Export Users with set flags (PasswordNeverExpires, ChangePasswordAtLogon)
    - [x] Export Users by Group Memberships (Domain Admins, Service Accounts, General Users)
    - [ ] Edit "PasswordNeverExpires, ChangePasswordAtLogon" flags based on OU or Files.
    - [x] Set users passwords via either: Set String (All Users the same), Random String (All Users different, output to current directory).
    - [ ] Display and export users passwords NOT changed today.
    - [ ] Display and export users with LastChagnedDate attribute.
- [ ] krbtgt reset, with ability to add a scheduled task for a second reset (prompt for user confirmation)

## To Do
- [x] Design user menu, sub-menus and return options.
- [ ] Design error handling
- [x] Design functions, input and output schema
- [ ] ImportByGroup
- [X] Standardise formatting for menus.
- [ ] Replace "Press enter to continue" with start-sleep at some point.
- [x] ExportUsersWithPasswordNeverExpires
- [ ] Find alternative to ExportUsersWithChangePasswordAtLogon
- [ ] ExportUsersChangedToday
- [X] DisplayAndExportLastPasswordChange
- [X] ExportAllUsersWithAttributes
- [X] ExportAllUsersFullData
- [ ] Link script to external krbtgt script.
- [ ] Test "Run Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1"
- [ ] Check Clear-Host locations.
- [ ] Add "Add Single User to Dataset" feature.
- [X] Add an exclusion for the currently logged in users password reset requirement.
- [ ] Code in an additional check window for the dataset when doing a file import.




## Changelog
- **0.1.0** - Project initialization

## Issue list:
    - [X] I've removed the $_SamAccount.name / SamAccount.User arguement from multiple areas. If storing dataset as an object, this will break.
    - [X] Test RemoveUsersFromDatasetMenu
    - [X] ResetDatasetUserPasswords_identical broken
    - [X] ResetDatasetUserPasswords_unique broken.
    - [X] Set-PasswordNeverExpiresFlag broken
    - [X] Set-ChangePasswordAtLogonFlag is broken.
    - [ ] Fix krbtgt scheduled reset functions.
    - [X] Import users by OU is importing the Canonical Name, not the SamName.
    - [X] ResetDatasetUserPasswords_identical Menu is broken and doesn't display correctly. Review.
    - [X] ResetDatasetUserPasswords_unique also probably has a broken menu. Review.
    - [X] Set-ChangePasswordAtLogonFlag - Error when account has "PasswordNeverExpires" set to False.
    - [ ] === Users whose Passwords were changed today === returns empty data.
    - [ ] 
    - [ ] 
    - [ ] 
    - [ ] 


#>

# Global flag for jumping back to main menu from any depth
$global:BackToMain = $false
$global:CurrentDataset = @()
$global:CurrentDatasetName = "None"
#$global:DatasetMenu = "Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
$global:DisplayAndSelectName = ""
$global:DisplayAndSelectFilteredItem = @()


$global:words = @(
	"Apple", "Banana", "Cherry", "Date", "Elderberry",
	"Fruit", "Grape", "Honeydew", "Kiwi", "Lemon",
	"Mango", "Orange", "Peach", "Quince", "Raspberry",
	"Strawberry", "Tangerine", "Watermelon", "Apricot", "Blueberry",
	"Cantaloupe", "Dragonfruit", "Guava", "Jackfruit", "Kumquat",
	"Limes", "Nectarine", "Olive", "Papaya", "Pineapple",
	"Pomegranate", "Raisin", "Satsuma", "Tomato", "Ugli",
	"Valley", "Walnut", "Xigua", "Yukon", "Zucchini",
	"Angel", "Beast", "Camel", "Dwarf", "Elephant",
	"Flame", "Giraffe", "Horse", "Iguana", "Jaguar",
	"Kangaroo", "Llama", "Monkey", "Newt", "Owlet",
	"Panda", "Quail", "Rabbit", "Snake", "Tiger",
	"Unicorn", "Vulture", "Whale", "Xenop", "Yak",
	"Zebra", "Airbus", "Barge", "Cargo", "Diesel",
	"Engine", "Ferry", "Garage", "Highway", "Inlet",
	"Junction", "Kiosk", "Lance", "Motor", "Naval",
	"Ocean", "Pilot", "Quake", "Route", "Sight",
	"Train", "Urban", "Vessel", "Wheel", "Yacht",
	"Zipper", "Books", "Canto", "Diary", "Essay",
	"Fable", "Genre", "Haiku", "Index", "Journal",
	"Knowledge", "Lyric", "Manuscript", "Novel", "Octave",
	"Poetry", "Quote", "Reader", "Story", "Title",
	"Volume", "Vegan", "Writing", "Xenophobic", "Yearly", "Zoned"
)
$global:specialChars = @("@", "%", "!", ".")

$Time = Get-Date -Format "yyyyMMdd-HHmmss"

## Import necessary modules
# Ensure Active Directory module is loaded
if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
	Import-Module ActiveDirectory
}

# Import .NET assembly
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Windows.Forms
# ---Main Menu Functions---

## Initial Checks
# Check if running as Administrator
# Check if AD module is available
# Check if computer is domain joined
# Check connectivity to a Domain Controller
# May add checks to see if the NIC is physically connected to the network later


if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
	Write-Host "This script must be run as an Administrator. Please restart PowerShell with elevated privileges."
	exit
}
elseif (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
	Write-Host "The Active Directory module is not available. Please install the RSAT tools and try again."
	exit
}
elseif (-not (Get-ADDomain -ErrorAction SilentlyContinue)) {
	Write-Host "This computer is not joined to a domain. Please join a domain and try again."
	exit
}
else {
	try {
		Get-ADDomainController -Discover -ErrorAction Stop | Out-Null
	}
 catch {
		Write-Host "Cannot connect to a Domain Controller. Please ensure you are connected to the domain and try again."
		exit
	}
}


# Menu 0
function Show-MainMenu {
	do {
		Clear-Host
		Write-Host "=== PBR AD Users Management === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. Manage Dataset"
		Write-Host "2. Manage Users"
		Write-Host "3. Global Reports"
		Write-Host "4. krbtgt Password Resets..."
		Write-Host "0. Exit"
        
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { Show-ManageDatasetMenu }
			2 { Show-ManageUsersMenu }
			3 { Show-ReportsMenu }
			4 { Show-KrbtgtResetMenu }
			0 { Check-ExitConfirmation }  # Exit the script
			default {
				Write-Host "Invalid option. Please try again."; #Start-Sleep -Seconds 2
			}
		}
	} while ($true)
}
# Menu 1 - Datasets
# Manage Dataset Menu and Sub-menus
function Show-ManageDatasetMenu {
	do {
		Clear-Host
		Write-Host "=== Manage Dataset === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
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
			default { Write-Host "Invalid option. Please try again."; Start-Sleep -Seconds 2; Read-Host "Press Enter to continue" }
		}
	} while ($true)
}
# Menu 1.1 - Import Users into Dataset
function Show-ImportUserDatasetMenu {
	do {
		Clear-Host
		Write-Host "=== Import User Dataset === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. Import by OU (Append)"
		Write-Host "2. Import by Group Membership (Append) (TBI)"
		Write-Host "3. Import by File"
		Write-Host "4. Import by Username (TBI)"
		Write-Host "9. Back to Previous Menu"
		Write-Host "0. Back to Main Menu"
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { DisplaySelectImportByOUs }
			2 { ImportByGroup } #ImportByGroup
			3 { ImportByFile }
			4 { Write-Host "Feature not yet implemented" }
			9 { return }
			0 { Show-MainMenu }
			default {
				Write-Host "Invalid option. Please try again."; #Start-Sleep -Seconds 2
				Read-Host "Press Enter to continue" 
			}
		}
	} while ($true)
}
# Menu 1.2 - Remove Users from Dataset

# Menu 2 - Users
# No Submenus - All functions called directly
function Show-ManageUsersMenu {
	do {
		Clear-Host
		Write-Host "=== Manage Users === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. Set User Passwords to Same String"
		Write-Host "2. Set User Passwords to Random Strings"
		Write-Host "3. Reset "PasswordNeverExpires" Flag for Users in Dataset"
		Write-Host "4. Reset "ChangePasswordAtLogon" Flag for Users in Dataset"
		Write-Host "0. Back to Main Menu"
        
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { ResetDatasetUserPasswords_identical }
			2 { ResetDatasetUserPasswords_unique }
			3 { Set-PasswordNeverExpiresFlag }
			4 { Set-ChangePasswordAtLogonFlag }
			0 { Show-MainMenu }
			default {
				Write-Host "Invalid option. Please try again."; #Start-Sleep -Seconds 2
				Read-Host "Press Enter to continue" 
			}
		}
	} while ($true)
}

# Menu 3 - Reports
function Show-ReportsMenu {
	do {
		Clear-Host
		Write-Host "=== Global Reports === Current Dataset Name: $($global:CurrentDatasetName) | Users: $($global:CurrentDataset.Count) ==="
		Write-Host "1. View/Export All Users with "PasswordNeverExpires" Flag set to True (Testing)"
		Write-Host "2. View/Export All Users with "ChangePasswordAtLogon" Flag set to True (Testing)"
		Write-Host "3. View/Export All Users whose Passwords were NOT changed today (Testing)"
		Write-Host "4. View/Export All Users whose Passwords were changed today (Testing)"
		Write-Host "5. View/Export All Users with their password change dates (Testing)"
		Write-Host "6. View/Export All Users with SamName, LastLogon, PasswordLastSet, PasswordNeverExpires, ChangePasswordAtLogon to CSV (Testing)"
		Write-Host "7. Export All Users & All User Data to CSV (Testing)"
		Write-Host "9. Back to Previous Menu"
		Write-Host "0. Back to Main Menu"
        
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { ExportUsersWithPasswordNeverExpires }
			2 { Read-Host "This is currently not possible due to how the variable is stored." } #ExportUsersWithChangePasswordAtLogon
			3 { DisplayAndExportNotChangedToday }
			4 { ExportUsersChangedToday }
			5 { DisplayAndExportLastPasswordChange }
			6 { ExportAllUsersWithAttributes } 
			7 { ExportAllUsersFullData }
			9 { return }
			0 { Show-MainMenu }
			default {
				Write-Host "Invalid option. Please try again."; #Start-Sleep -Seconds 2
				Read-Host "Press Enter to continue" 
			}
		}
	} while ($true)
}

# Menu 4 - krbtgt Resets
function Show-KrbtgtResetMenu {
	do {
		Clear-Host
		Write-Host "=== krbtgt Password Resets ==="
		Write-Host "1. Reset krbtgt Password Now"
		Write-Host "2. Schedule krbtgt Password Reset (TBC)"
		Write-Host "3. Run Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1"
		Write-Host "9. Back to Previous Menu"
		Write-Host "0. Back to Main Menu"
        
		$choice = Read-Host "Enter your choice"
        
		switch ($choice) {
			1 { ResetkrbtgtPasswordNow } # Done, may be expanded/changed later.
			2 { ResetkrbtgtPasswordScheduleSecond } # Done, but needs testing.
			3 { Start-Process powershell "$pwd/Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1" }
			9 { return }
			0 { Show-MainMenu }
			default { Write-Host "Invalid option. Please try again." } #Start-Sleep -Seconds 2
		}
	} while ($true)
}

# ---End of Main Menu Functions---

function ApplySelectionToDataset {
	Clear-Host
	# Set the CurrentDatasetName
	if ($global:CurrentDatasetName -eq "None") {
		$global:CurrentDatasetName = $global:DisplayAndSelectName
	} elseif ($global:CurrentDatasetName -ne "None" -and $global:CurrentDatasetName -ne "Multiple") {
		$global:CurrentDatasetName = "Multiple"
	}
	
	# Filter out users already in CurrentDataset, then add new users and remove duplicates
	$global:CurrentDataset += $global:DisplayAndSelectFilteredItem
	# $global:CurrentDataset = $global:CurrentDataset | Sort-Object -Property SamAccountName | Select-Object -Unique # is this causing the problem with removing the duplicates?
	
	Write-Host "Dataset loaded with new users from $global:DisplayAndSelectName."
	Write-Host "Total users imported into dataset: $($global:DisplayAndSelectFilteredItem.Count)"
	Write-Host "Duplicates have NOT been removed."
	Write-Host "Total users now in the dataset: $($global:CurrentDataset.Count)"

	$global:DisplayAndSelectFilteredItem = $null
	$global:DisplayAndSelectName = $null
	#Start-Sleep -Seconds 2
	Read-Host "Press Enter to continue"
}
function ImportByFile {
	Clear-Host
	Write-Host "=== Import by File ==="
	Write-Host "Please ensure that the file contains only usernames, with no headers."
	Read-Host "Please select the CSV file containing user data. `nPress Enter to continue."
	$file = New-Object System.Windows.Forms.OpenFileDialog -Property @{
		InitialDirectory = [Environment]::GetFolderPath('Desktop')
		Filter           = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
		Title            = "Select CSV File"
	}
	$dialogResult = $file.ShowDialog()
    
	if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
		Write-Host "Importing users from $($file.FileName)..."
		Read-Host "Press Enter to continue"
		$filePath = $file.FileName
		# Check if file is empty
		$lines = Get-Content $filePath
		if ($lines.Count -eq 0) {
			Write-Host "The file is empty. No users imported."
			Read-Host "Press Enter to continue"
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
        
		# Validate users exist in AD
		$validUsers = @()
		foreach ($user in $users) {
			try {
				$adUser = Get-ADUser -Identity $user.SamAccountName -ErrorAction Stop
				$validUsers += [PSCustomObject]@{SamAccountName = $user.SamAccountName}
			}
			catch {
				Write-Host "Warning: User '$($user.SamAccountName)' not found in Active Directory. Skipping."
			}
		}
        
		if ($validUsers.Count -eq 0) {
			Write-Host "No valid users were found in the file. Please check the file and try again."
			Read-Host "Press Enter to continue"
			return
		}
        
		# Filter and add to dataset
		$newUsers = $validUsers

		if ($newUsers.Count -gt 0) {
			$global:DisplayAndSelectFilteredItem += $newUsers
			$global:DisplayAndSelectName = Split-Path $filePath -Leaf
			ApplySelectionToDataset
			}
		else {
			Write-Host "No valid users were imported after filtering. Please check the file and try again."
			Read-Host "Press Enter to continue"
		}
	}
}
function ExportDataset { 
	if ($global:CurrentDataset.Count -eq 0) {
		Write-Host "The dataset is empty. Please select users first."
		#Start-Sleep -Seconds 2
		Read-Host "Press Enter to continue"
		return
	}
 else {
		$global:CurrentDataset | Select-Object -ExpandProperty SamAccountName | Out-File "$PWD\DatasetExport-$Time.csv"
		Write-Host "Users exported to $PWD\DatasetExport-$Time.csv"
		Write-Host "Total users exported: $($global:CurrentDataset.Count)."
		Read-Host "Press Enter to continue"
	}      
}

function ExportUsersWithPasswordNeverExpires {
	Clear-Host
	Write-Host "=== Uses with PasswordNeverExpires set to True ==="
	$users = Get-ADUser -Filter { PasswordNeverExpires -eq $true } -Properties SamAccountName, PasswordNeverExpires
	if ($users.Count -eq 0) {
		Write-Host "No users found."
		Read-Host "Press Enter to Continue"
		return
	}
 else {
		Write-Host "Users whose PasswordNeverExpires is True"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "PasswordNeverExpires"; Expression = { $_.PasswordNeverExpires } } -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue."
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersPasswordNeverExpiresTrue-$Time.csv"
		$users | Select-Object SamAccountName, PasswordNeverExpires | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath"
	}
	Read-Host "Press Enter to continue"
}

### Broken, can not return data.
function ExportUsersWithChangePasswordAtLogon {
	Clear-Host
	Write-Host "=== Uses with ChangePasswordAtLogon set to True ==="
	$users = Get-ADUser -Filter * -Properties SamAccountName, ChangePasswordAtLogon:$true
	$users | Select-Object SamAccountName, @{Name = 'ChangePasswordAtLogon'; Expression = { ($_.ChangePasswordAtLogon -eq $true) } }
	if ($users.Count -eq 0) {
		Write-Host "No users found."
		Read-Host "Press Enter to Continue"
		return
	}
 else {
		Write-Host "Users whose ChangePasswordAtLogon is True"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "ChangePasswordAtLogon"; Expression = { $_.ChangePasswordAtLogon } } -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue."
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersChangePasswordAtLogonTrue-$Time.csv"
		$users | Select-Object SamAccountName, ChangePasswordAtLogon | Out-File $ExportPath -Encoding UTF8
		Write-Host "Users exported to $ExportPath"
	}
	Read-Host "Press Enter to continue"
}

function ImportByGroup {
	Clear-Host
	# Get all AD Groups
	$groups = Get-ADGroup -Filter * -Properties Members | Sort-Object Name
	
	if ($groups.Count -eq 0) {
		Write-Host "No groups found in the environment."
		Read-Host "Press Enter to continue"
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
		Read-Host "Press Enter to continue"
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
		Read-Host "Press Enter to continue"
		return
	}
	
	$index = [int]$selection - 1
	
	if ($index -lt 0 -or $index -ge $groupData.Count) {
		Write-Host "Invalid selection. Number out of range." -ForegroundColor Red
		Read-Host "Press Enter to continue"
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
		Read-Host "Press Enter to continue"
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
		$IncludeDisabled = Read-Host "Do you want to include disabled users in the dataset? `n1. Yes `n2. No `nEnter choice (1-2)"
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
	
	$importChoice = Read-Host "Do you want to import these $($filteredUsers.Count) users into the dataset? `n1. Yes `n2. No `nEnter choice (1-2)"
	if ($importChoice -eq "1") {
		$global:DisplayAndSelectName = $groupName
		$global:DisplayAndSelectFilteredItem = $filteredUsers
		ApplySelectionToDataset
	}
	elseif ($importChoice -eq "2") {
		Write-Host "Import cancelled."
		Read-Host "Press Enter to continue"
	}
	else {
		Write-Host "Invalid choice. Import cancelled."
		Read-Host "Press Enter to continue"
	}
}

# function ExportUsersByGroup { 
# 	Read-Host "Select a group from the below options"
# 	Get-ADGroup -Filter * | Select-Object Name | ForEach-Object { Write-Host $_.Name }
# 	$groupName = Read-Host "Enter the group name to export users from"
# 	if ($groupName -eq "") {
# 		Write-Host "No group name entered. Returning to previous menu."
# 		Read-Host "Press Enter to continue"
# 		return
# 	}
#  elseif (-not (Get-ADGroup -Identity $groupName -ErrorAction SilentlyContinue)) {
# 		Write-Host "Group '$groupName' not found. Please check the name and try again."
# 		Read-Host "Press Enter to continue"
# 		return
# 	}
#  elseif ($null -ne $groupName) {
# 		Get-ADGroupMember -Identity $groupName | Where-Object { $_.objectClass -eq 'user' } | Select-Object -ExpandProperty SamAccountName | Out-File "$PWD\UsersInGroup-$groupName-$Time.csv" -Encoding UTF8
# 		Write-Host "Users in group '$groupName' exported to $PWD\UsersInGroup-$groupName-$Time.csv"
# 		Read-Host "Press Enter to continue"
# 	}
# }

function ResetDatasetVariables {
	$ResetCheck = Read-Host "Are you sure you want to clear the current dataset?`n 1. Yes`n 2. No`n Choice"
	if ($ResetCheck -eq "2") {
		return
	}
 else { 
		$global:CurrentDataset = @()
		$global:CurrentDatasetName = "None"
		Write-Host "Currently loaded dataset has been reset to empty."
		Start-Sleep -Seconds 2
	}
}
function Show-LoadedDatasetSummary {
	Clear-Host
	Write-Host "=== Loaded Dataset Summary ==="
	if ($global:CurrentDataset.Count -eq 0) {
		Write-Host "No users currently loaded in the dataset."
	}
 else {
		$activeCount = ($global:CurrentDataset | Where-Object { $_.Enabled -eq $true }).Count
		$disabledCount = ($global:CurrentDataset | Where-Object { $_.Enabled -eq $false }).Count
		Write-Host "Total Users in Dataset: $($global:CurrentDataset.Count)"
		Write-Host "Active Users: $activeCount" -ForegroundColor Green
		Write-Host "Disabled Users: $disabledCount" -ForegroundColor Red
	}
	Read-Host "Press Enter to continue"
}
function Show-LoadedDatasetEntries {
	Clear-Host
	Write-Host "=== Loaded Dataset Users ==="
	if ($global:CurrentDataset.Count -eq 0) {
		Write-Host "No users currently loaded in the dataset."
	}
 else {
		Write-Host "SAM Names in the current dataset:"
		Show-UserStatus
	}
	#Start-Sleep -Seconds 2
	Read-Host "Press Enter to continue"
}
# Add more functions as needed for deeper menus

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

function RemoveUsersFromDatasetMenu {
	do {
		Clear-Host
        
		# Check if dataset is empty
		if ($global:CurrentDataset.Count -eq 0) {
			Write-Host "=== Remove Users from Dataset ===" -ForegroundColor Cyan
			Write-Host ""
			Write-Host "The dataset is empty. Please load users first." -ForegroundColor Yellow
			Read-Host "Press Enter to continue"
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
			Start-Sleep -Seconds 2
			continue
		}
        
		$index = [int]$selection - 1
        
		# Validate range
		if ($index -lt 0 -or $index -ge $global:CurrentDataset.Count) {
			Write-Host "Invalid selection. Number out of range." -ForegroundColor Red
			Start-Sleep -Seconds 2
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
				Read-Host "Press Enter to continue"
				return
			}
		}
		else {
			Write-Host "Removal cancelled." -ForegroundColor Gray
			Start-Sleep -Seconds 1
		}
        
		# Loop continues to show updated list
        
	} while ($true)
}

function ResetDatasetUserPasswords_unique {
	Clear-Host
	Check-DatasetPopulated
	$currentUser = $env:USERNAME
	$dataset = $global:CurrentDataset | Where-Object { $_.SamAccountName -ne $currentUser }
	if ($dataset.Count -eq 0) {
		Write-Host "The dataset is empty after excluding the current user ($currentUser). Unable to continue."
		Read-Host "Press Enter to Continue."
		return
	}
	Write-Host "=== Reset User to Unique Strings ==="
	Write-Host "Please note that the following Changes will be made to each user: `n	- ChangePasswordAtLogon flag will be set to True`n	- PasswordNeverExpires will be set to False`n	- All User passwords in the current dataset will be reset.`n 	- The current user "$currentUser" will be excluded."
	$Time = Get-Date -Format "yyyyMMdd-HHmmss"
	$OutputFile = "$PWD\NewPasswordsPlain-$Time.csv"
	do {
		Write-Host "Please select one of the following options to continue:"
		$choice = Read-Host "1. View Users in dataset `n2. Continue with Reset `n0. Cancel"
		switch ($choice) {
			"0" {
				return
			}
			"1" {
				Clear-Host
				Write-Host "=== Reset User to Unique Strings ==="
				Write-Host "The following users will have their passwords reset:"
				foreach ($user in $dataset) {
					Write-Host "	- $($user.SamAccountName)"
				}
				Read-Host "Press Enter to Continue"
				Clear-Host
				continue
			}
			"2" {
				foreach ($user in $dataset) {
					$NewPasswordPlain = GeneratePassword
					$NewPassword = ConvertTo-SecureString -String $NewPasswordPlain -AsPlainText -Force
					try {
						Set-ADAccountPassword -Identity $user.SamAccountName -NewPassword $NewPassword -Reset
						Set-ADUser -Identity $user.SamAccountName -PasswordNeverExpires $false -ChangePasswordAtLogon $true
						Write-Host "	- Password for user $($user.SamAccountName) has been set to a unique password."
						"$($user.SamAccountName),$NewPasswordPlain" | Out-File -FilePath $OutputFile -Append
					}
					catch {
						Write-Host "	- Failed to reset password for user $($user.SamAccountName): $_"
					}
				}
				Write-Host "`n$OutputFile has been created with unique passwords for each user."
				Write-Host -BackgroundColor Red -ForegroundColor Black "Ensure that this file is stored securely and deleted after use.`n"
				Read-Host "Press Enter to Continue."
				Clear-Host
				return
			}
			default {
				Write-Host "Invalid option. Please try again."
				Start-Sleep -Seconds 2
				continue
			}
		}
	} while ($true)
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

function Check-DatasetPopulated {
	if ($global:CurrentDataset.Count -eq 0) {
		Write-Host "The current dataset is empty. Unable to continue."
		Read-Host "Press Enter to Continue."
	}
 else {
		return
	}
}

function ResetDatasetUserPasswords_identical {
	Clear-Host
	Check-DatasetPopulated
	$currentUser = $env:USERNAME
	$dataset = $global:CurrentDataset | Where-Object { $_.SamAccountName -ne $currentUser }
	if ($dataset.Count -eq 0) {
		Write-Host "The dataset is empty after excluding the current user ($currentUser). Unable to continue."
		Read-Host "Press Enter to Continue."
		return
	}
	do {
		Write-Host "=== Reset Users to Same String ==="
		$NewPasswordPlain = GeneratePassword
		Write-Host "Please note that the following Changes will be made to each user: `n	- ChangePasswordAtLogon flag will be set to True`n	- PasswordNeverExpires will be set to False`n	- All User passwords in the current dataset will be reset.`n 	- The current user "$currentUser" will be excluded."
		Write-Host "The new password to be set for all users in the dataset is: $NewPasswordPlain"
		$NewPassword = ConvertTo-SecureString -String $NewPasswordPlain -AsPlainText -Force
		Write-Host "Please select one of the following options to continue:"

		$SetSameStringbyOUConfirmRead = Read-Host "1. View Users in dataset `n2. Continue with Reset `n3. Regenerate Password `n0. Cancel"
		Read-Host "Please ensure the password has been documented, as it will not be shown again.`nPress Enter to Continue"
		
		switch ($SetSameStringbyOUConfirmRead) {
			"0" {
				return
			}
			"1" {
				Clear-Host
				Write-Host "=== Reset Users to Same String ==="
				Write-Host "The following users will have their passwords reset:"
				foreach ($user in $dataset) {
					Write-Host "	- $($user.SamAccountName)"
				}
				Read-Host "Press Enter to Continue"
				Clear-Host
				continue
			}
			"2" {
				Clear-Host
				Write-Host "=== Reset Users to Same String ==="
				Write-Host "Proceeding with password reset..."
				foreach ($user in $dataset) {
					try {
						Set-ADAccountPassword -Identity $($user.SamAccountName) -NewPassword $NewPassword -Reset
						Set-ADUser -Identity $($user.SamAccountName) -PasswordNeverExpires $false -ChangePasswordAtLogon $true
						Write-Host "	- Password for user $($user.SamAccountName) has been reset."
					}
					catch {
						Write-Host "	- Failed to reset password for user $($user.SamAccountName): $_"
					}
				}
				Write-Host "`nAll Users within the dataset have had the same password set."
				Read-Host "`nPress Enter to Continue."
				Clear-Host
				return
			}
			"3" {
				# Regenerate password, continue loop
				continue
			}
			default {
				Write-Host "Invalid option. Please try again."
				Start-Sleep -Seconds 2
				continue
			}
		}
	} while ($true)
}

function DisplaySelectImportByOUs {
	Clear-Host
	# Get all OUs and count users in each
	$ous = Get-ADOrganizationalUnit -Filter * | Sort-Object DistinguishedName
    
	if ($ous.Count -eq 0) {
		Write-Host "No Organizational Units found in the environment."
		Read-Host "Press Enter to continue"
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
		Read-Host "Press Enter to continue"
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
			Read-Host "Press Enter to continue"
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
			$IncludeDisabled = Read-Host "Do you want to include disabled users in the dataset? `n1. Yes `n2. No `nEnter choice (1-2)"
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
        
		$importChoice = Read-Host "Do you want to import these $($filteredUsers.Count) users into the dataset? `n1. Yes `n2. No `nEnter choice (1-2)"
		if ($importChoice -eq "1") {
			ApplySelectionToDataset
		}
		elseif ($importChoice -eq "2") {
			Write-Host "Import cancelled."
			Read-Host "Press Enter to continue"
		}
		else {
			Write-Host "Invalid choice. Import cancelled."
			Read-Host "Press Enter to continue"
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
		Read-Host "Press Enter to continue"
		return
	}
    
	Clear-Host
	$index = [int]$selection - 1
    
	if ($index -lt 0 -or $index -ge $ouData.Count) {
		Write-Host "Invalid selection. Number out of range." -ForegroundColor Red
		Read-Host "Press Enter to continue"
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
		Read-Host "Press Enter to continue"
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
		$IncludeDisabled = Read-Host "Do you want to include disabled users in the dataset? `n1. Yes `n2. No `nEnter choice (1-2)"
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
    
	$importChoice = Read-Host "Do you want to import these $($filteredUsers.Count) users into the dataset? `n1. Yes `n2. No `nEnter choice (1-2)"
	if ($importChoice -eq "1") {
		$global:DisplayAndSelectName = $topLevelOU
		$global:DisplayAndSelectFilteredItem = $filteredUsers
		ApplySelectionToDataset
	}
 elseif ($importChoice -eq "2") {
		Write-Host "Import cancelled."
		Read-Host "Press Enter to continue"
	}
 else {
		Write-Host "Invalid choice. Import cancelled."
		Read-Host "Press Enter to continue"
	}
}
function ViewUsersWithPasswordNeverExpires {
	Clear-Host
	Write-Host "=== Users with PasswordNeverExpires Flag ==="
	$users = Get-ADUser -Filter { PasswordNeverExpires -eq $true } -Properties SamAccountName
	if ($users.Count -eq 0) {
		Write-Host "No users found with PasswordNeverExpires flag set."
		Read-Host "Press Enter to continue"
	}
 else {
		Write-Host "Users with PasswordNeverExpires flag set:"
		$users | ForEach-Object { Write-Host $_.SamAccountName }
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue."
	if ($ViewUserExport -eq "1") {
		Clear-Host
		Write-Host "Exporting users with PasswordNeverExpires flag..."
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersWithPasswordNeverExpires-$Time.csv"
		$users | Select-Object -ExpandProperty SamAccountName | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath"
		##Start-Sleep -Seconds 2
		Read-Host "Press Enter to continue"

	}
    
}

function ViewUsersWithChangePasswordAtLogon {
	Clear-Host
	Write-Host "=== Users with ChangePasswordAtLogon Flag ==="
	$users = Get-ADUser -Filter { ChangePasswordAtLogon -eq $true } -Properties SamAccountName
	if ($users.Count -eq 0) {
		Write-Host "No users found with ChangePasswordAtLogon flag set."
	}
 else {
		Write-Host "Users with ChangePasswordAtLogon flag set:"
		$users | ForEach-Object { Write-Host $_.SamAccountName }
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue."
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersWithChangePasswordAtLogon-$Time.csv"
		$users | Select-Object -ExpandProperty SamAccountName | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath"
	}
	Read-Host "Press Enter to continue"
}

function DisplayAndExportLastPasswordChange {
	Clear-Host
	Write-Host "=== All Users with LastPasswordChange Date ==="
	$users = Get-ADUser -Filter * -Properties SamAccountName, PasswordLastSet
	if ($users.Count -eq 0) {
		Write-Host "No users found."
		Read-Host "Press Enter to continue"
		return
	}
 else {
		Write-Host "Users and their LastPasswordChange dates:"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "PasswordLastSet"; Expression = { $_.PasswordLastSet } } -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue."
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\AllUsersWithLastPasswordChangeDate-$Time.csv"
		$users | Select-Object SamAccountName, PasswordLastSet | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "NOTE: Blank data typically means the account has ChangePasswordAtLogon set to True" -BackgroundColor yellow -ForegroundColor Black
		Write-Host "Users exported to $ExportPath"
	}
	Read-Host "Press Enter to continue"
}

function DisplayAndExportNotChangedToday {
	Clear-Host
	Write-Host "=== Users whose Passwords were NOT changed today ==="
	$today = (Get-Date).Date
	$users = Get-ADUser -Filter * -Properties SamAccountName, PasswordLastSet | Where-Object { $_.PasswordLastSet -lt $today }
	if ($users.Count -eq 0) {
		Write-Host "All users have changed their passwords today."
		Read-Host "Press Enter to Continue"
		return
	}
 else {
		Write-Host "Users whose passwords were NOT changed today:"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "PasswordLastSet"; Expression = { $_.PasswordLastSet } } -AutoSize
	}
	Write-Host "NOTE: Blank data typically means the account has ChangePasswordAtLogon set to True" -BackgroundColor yellow -ForegroundColor Black
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue."
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersNotChangedToday-$Time.csv"
		$users | Select-Object SamAccountName, PasswordLastSet | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath"
	}
	Read-Host "Press Enter to continue"
}

function ExportUsersChangedToday {
	Clear-Host
	Write-Host "=== Users whose Passwords were changed today ==="
	$today = (Get-Date).Date
	$users = Get-ADUser -Filter * -Properties SamAccountName, PasswordLastSet | Where-Object { $_.PasswordLastSet -eq $today }
	$today
	$users
	if ($users.Count -eq 0) {
		Write-Host "No users have changed their passwords today."
		Read-Host "Press Enter to Continue"
		return
	}
 else {
		Write-Host "Users whose passwords were changed today:"
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "PasswordLastSet"; Expression = { $_.PasswordLastSet } } -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue."
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\UsersChangedToday-$Time.csv"
		$users | Select-Object SamAccountName, PasswordLastSet | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath"
	}
	Read-Host "Press Enter to continue"
}

function ExportAllUsersWithAttributes {
	Clear-Host
	Write-Host "=== Users whose Passwords were NOT changed today ==="
	Read-Host "This will export the following user attributes:`n		- SamName`n		- Last Logon`n		- PasswordLastSet`n		- PasswordNeverExpires`n		- ChangePasswordAtNextLogon`n"
    
	$today = (Get-Date).Date
	$users = Get-ADUser -Filter * -Properties SamAccountName, LastLogon, PasswordLastSet, PasswordNeverExpires, ChangePasswordAtLogo
	if ($users.Count -eq 0) {
		Write-Host "No users have been found."
		Read-Host "Press Enter to Continue"
		return
	}
 else {
		$users | Format-Table -Property @{Name = "SamAccountName"; Expression = { $_.SamAccountName } }, @{Name = "Last Logon"; Expression = { $_.LastLogon } }, @{Name = "PasswordLastSet"; Expression = { $_.PasswordLastSet } }, @{Name = "PasswordNeverExpires"; Expression = { $_.PasswordNeverExpires } }, @{Name = "ChangePasswordAtNextLogon"; Expression = { $_.ChangePasswordAtLogon } } -AutoSize
	}
	$ViewUserExport = Read-Host "Press 1 to export this list to CSV, or Enter to continue."
	if ($ViewUserExport -eq "1") {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\AllUsersCommonAttributes-$Time.csv"
		$users | Select-Object SamAccountName, LastLogon, PasswordLastSet, PasswordNeverExpires, ChangePasswordAtLogon | Export-Csv -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath"
	}
	Read-Host "Press Enter to continue"
}

function ExportAllUsersFullData {
	Clear-Host
	Write-Host "=== Export All Users & Data ==="
	Read-Host "This will export all Users & All User attributes. This may take a while."
	$today = (Get-Date).Date
	$users = Get-ADUser -Filter * -Properties *
	if ($users.Count -eq 0) {
		Write-Host "No users have been found."
		Read-Host "Press Enter to Continue"
		return
	}
 else {
		$Time = Get-Date -Format "yyyyMMdd-HHmmss"
		$ExportPath = "$PWD\AllUsersAllAttributes-$Time.csv"
		$users | Export-CSV -Path $ExportPath -Encoding UTF8 -NoTypeInformation
		Write-Host "Users exported to $ExportPath"
		Read-Host "Press Enter to Continue"
	}
}

function ResetkrbtgtPasswordNow {
	Clear-Host
	$LastResetTime = (Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet).PasswordLastSet
	Write-Host "=== krbtgt Password Reset Now ==="
	Write-Host "This is a basic krbtgt password reset script."
	Write-Host "It currently does not support checks such as DC sync status or replication status."
	Write-Host "Ensure you have reviewed the environment status before proceeding, `nor utilise an alternative script with such checks."
	Write-Host "This action will reset the krbtgt account password immediately upon confirmation."
	Write-Host "Proceed with caution." -backgroundcolor yellow -ForegroundColor red
	write-host "==="
	Write-Host "The last krbtgt password reset was at $LastResetTime"
	$confirmation = Read-Host "Are you sure you want to reset the krbtgt account password now? `n1. Yes `n2. No `nEnter choice (1-2)"
	if ($confirmation -eq "1") {
		try {
			$newPassword = [System.Web.Security.Membership]::GeneratePassword(24, 3) | ConvertTo-SecureString -AsPlainText -Force
			Set-ADAccountPassword -Identity "krbtgt" -NewPassword $newPassword -Reset
			Write-Host "krbtgt account password has been reset successfully."
			Write-Host "krbtgt account password last set: $($(Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet).PasswordLastSet)"
		}
		catch {
			Write-Host "Failed to reset krbtgt password: $_"
		}
	}
 else {
		Write-Host "Operation cancelled by user."
	}
	Read-Host "Press Enter to continue"
}

function ResetkrbtgtPasswordScheduleSecond {
	Clear-Host
	Write-Host "=== Schedule Second krbtgt Password Reset ==="
	$confirmation = Read-Host "Are you sure you want to schedule a second krbtgt password reset? `n1. Yes `n2. No `nEnter choice (1-2):"
	if ($confirmation -eq "1") {
		$ResetDelay = Read-Host "Enter the delay in hours before the scheduled task runs (Max 99 hours)"
        
		if ($ResetDelay -notmatch '^\d{1,2}$' -or $ResetDelay -lt 10 -or $ResetDelay -gt 99) {
			Write-Host "Invalid input. Please enter a valid number of hours between 10 and 99."
			##Start-Sleep -Seconds 2
			Read-Host "Press Enter to continue"
			return
		}
		elseif ($ResetDelay -lt 10 -or $ResetDelay -gt 99) {
			Write-Host "You should select a value between 10 and 99 for best practice."
			return
		}
		else {
			$lastReset = (Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet).PasswordLastSet
			$nextReset = (Get-Date).AddHours([int]$ResetDelay)
			$countdownScript = @"
try {
    Import-Module ActiveDirectory
    Add-Type -AssemblyName System.Web
    Clear-Host
Write-Host "=== krbtgt Second Reset Monitor ==="
Write-Host "This window monitors the delay for the second krbtgt password reset."
Write-Host "Last krbtgt reset: $lastReset"
Write-Host "Delay entered: $ResetDelay hours"
Write-Host "Next reset due at: $nextReset"
Write-Host "Countdown starting..."
`$remainingSeconds = [int]$ResetDelay * 3600
while (`$remainingSeconds -gt 0) {
    `$hours = [math]::Floor(`$remainingSeconds / 3600)
    `$minutes = [math]::Floor((`$remainingSeconds % 3600) / 60)
    `$seconds = `$remainingSeconds % 60
    Write-Host ("Time remaining: {0:D2}:{1:D2}:{2:D2} -f `$hours, `$minutes, `$seconds") -NoNewline
    Start-Sleep -Seconds 1
    `$remainingSeconds--
    Write-Host "`r" -NoNewline
}
Write-Host "Timer complete. Proceeding with krbtgt password reset..."
Write-Host "Last krbtgt reset was at: $lastReset."
`$confirm = Read-Host "Do you want to proceed with the krbtgt reset now? `n1. Yes `n2. No `nEnter choice (1-2):"
if (`$confirm -eq '1') {
    Write-Host "Proceeding with krbtgt reset..."
    `$newPassword = [System.Web.Security.Membership]::GeneratePassword(24,3) | ConvertTo-SecureString -AsPlainText -Force
    try {
        Set-ADAccountPassword -Identity "krbtgt" -NewPassword `$newPassword -Reset
        Write-Host "krbtgt password reset completed successfully."
    } catch {
        Write-Host "Failed to reset krbtgt password: `$_"
    }
} else {
    Write-Host "krbtgt reset cancelled by user."
}
} catch {
    Write-Host "An error occurred in the krbtgt reset script: `$_"
    Read-Host "Press Enter to close this window"
}
"@
			Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $countdownScript" -WindowStyle Normal
			Read-Host "New Powershell Window Created for Schedule Second krbtgt Reset. Press Enter to continue"
		}
		Read-Host "Function complete. Press Enter to continue"
	}
}
function Set-PasswordNeverExpiresFlag {
	do {
		Clear-Host
		Write-Host "=== Set PasswordNeverExpires Flag ==="
		Check-DatasetPopulated
		
		if ($global:CurrentDataset.Count -eq 0) {
			return
		}

		Write-Host "Set PasswordNeverExpires flag to True or False for the current users in the dataset?"
		Write-Host "Users in dataset: $($global:CurrentDataset.Count)"
		Write-Host ""
		Write-Host "1. Set to True"
		Write-Host "2. Set to False"
		Write-Host "3. View Users in Dataset"
		Write-Host "0. Cancel"
		Write-Host ""
		
		$choice = Read-Host "Select an option (0-3)"
		
		switch ($choice) {
			"1" {
				$flagValue = $true
				Clear-Host
				Write-Host "=== Setting PasswordNeverExpires to True ==="
				Write-Host "Processing users..."
				Write-Host ""
				
				$successCount = 0
				$failureCount = 0
				$failedUsers = @()
				
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADUser -Identity $user.SamAccountName -PasswordNeverExpires $flagValue -ErrorAction Stop
						Write-Host "	- ✓ Flag set to $flagValue for $($user.SamAccountName)" -ForegroundColor Green
						$successCount++
					} 
					catch {
						Write-Host "	- ✗ Failed to set flag for $($user.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
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
				
				Read-Host "Press Enter to continue"
			}
			
			"2" {
				$flagValue = $false
				Clear-Host
				Write-Host "=== Setting PasswordNeverExpires to False ==="
				Write-Host "Processing users..."
				Write-Host ""
				
				$successCount = 0
				$failureCount = 0
				$failedUsers = @()
				
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADUser -Identity $user.SamAccountName -PasswordNeverExpires $flagValue -ErrorAction Stop
						Write-Host "  ✓ Flag set to $flagValue for $($user.SamAccountName)" -ForegroundColor Green
						$successCount++
					} 
					catch {
						Write-Host "  ✗ Failed to set flag for $($user.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
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
				
				Read-Host "Press Enter to continue"
			}
			
			"3" {
				Clear-Host
				Write-Host "=== Users in Current Dataset ===" -ForegroundColor Cyan
				Write-Host ""
				$global:CurrentDataset | ForEach-Object { Write-Host "  - $($_.SamAccountName)" }
				Write-Host ""
				Read-Host "Press Enter to continue"
			}
			
			"0" {
				return
			}
			
			default {
				Write-Host "Invalid option. Please try again." -ForegroundColor Red
				Start-Sleep -Seconds 2
			}
		}
	} while ($true)
}

function Set-ChangePasswordAtLogonFlag {
	do {
		Clear-Host
		Write-Host "=== Set ChangePasswordAtLogon Flag ==="
		Check-DatasetPopulated
		
		if ($global:CurrentDataset.Count -eq 0) {
			return
		}

		Write-Host "Set ChangePasswordAtLogon flag to True or False for the current users in the dataset?"
		Write-Host "Users in dataset: $($global:CurrentDataset.Count)"
		Write-Host "WARNING: This will not apply if the account has 'PasswordNeverExpires' set to 'True'" -BackgroundColor Red -ForegroundColor Black
		Write-Host ""
		Write-Host "1. Set to True"
		Write-Host "2. Set to False"
		Write-Host "3. View Users in Dataset"
		Write-Host "0. Cancel"
		Write-Host ""
		
		$choice = Read-Host "Select an option (0-3)"
		
		switch ($choice) {
			"1" {
				$flagValue = $true
				Clear-Host
				Write-Host "=== Setting ChangePasswordAtLogon to True ==="
				Write-Host "Processing users..."
				Write-Host ""
				
				$successCount = 0
				$failureCount = 0
				$failedUsers = @()
				
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADUser -Identity $user.SamAccountName -ChangePasswordAtLogon $flagValue -ErrorAction Stop
						Write-Host "  ✓ Flag set to $flagValue for $($user.SamAccountName)" -ForegroundColor Green
						$successCount++
					} 
					catch {
						Write-Host "  ✗ Failed to set flag for $($user.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
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
					Write-Host "Note: Failures are often due to 'PasswordNeverExpires' being set to 'True'" -ForegroundColor Yellow
				}
				
				Read-Host "Press Enter to continue"
			}
			
			"2" {
				$flagValue = $false
				Clear-Host
				Write-Host "=== Setting ChangePasswordAtLogon to False ==="
				Write-Host "Processing users..."
				Write-Host ""
				
				$successCount = 0
				$failureCount = 0
				$failedUsers = @()
				
				foreach ($user in $global:CurrentDataset) {
					try {
						Set-ADUser -Identity $user.SamAccountName -ChangePasswordAtLogon $flagValue -ErrorAction Stop
						Write-Host "  ✓ Flag set to $flagValue for $($user.SamAccountName)" -ForegroundColor Green
						$successCount++
					} 
					catch {
						Write-Host "  ✗ Failed to set flag for $($user.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
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
					Write-Host "Note: Failures are often due to 'PasswordNeverExpires' being set to 'True'" -ForegroundColor Yellow
				}
				
				Read-Host "Press Enter to continue"
			}
			
			"3" {
				Clear-Host
				Write-Host "=== Users in Current Dataset ===" -ForegroundColor Cyan
				Write-Host ""
				$global:CurrentDataset | ForEach-Object { Write-Host "  - $($_.SamAccountName)" }
				Write-Host ""
				Read-Host "Press Enter to continue"
			}
			
			"0" {
				return
			}
			
			default {
				Write-Host "Invalid option. Please try again." -ForegroundColor Red
				Start-Sleep -Seconds 2
			}
		}
	} while ($true)
}

function CurrentAccountRemovalCheck {
	
}

Show-MainMenu

