<# Synopsis ####################################################
        Get-UpdatePkgInfo.ps1

# Description
        Displays the Software Update Name, Content Source, Package Name, Package ID, and Package Source size for all Software Update members of a specified Software Update Group

# Notes
    Version: 3.1
    Author: Joseph Hopper
    Creation Date: 1/22/2020
    Modified Date 5/22/2020
    Purpose/Change: 

        3.0-Added the SourceSize column and converted the data to readable values
            Added a GUI to display the resulting SUG list 
            Replaced the Get-CMSoftwareUpdateGroup Cmdlet with Get-WMIObject to speed up the processing
            Adding the Output of the results to Out-GridView and auto-save a copy to C:\Windows\Temp\PkgResults.txt
            Added progress bar to show current status
            Added script parameter to specify the Software Update Group name
            Added script parameter to show the saved output txt file
            Added the ability to query a remote SQL server when the CM database is hosted on another site server

        3.1-Fixed UI issue when manually resizing the SUG list window
            Resized the SUG List UI for aesthetics
            Added Exit to the cancel button handler to quit the script
            Added the Package name to the list of returned items


# Example
        Use the following syntax on the Primary or CAS Site Server

        Example 1) Displays the Name, Content Source, Package ID, and Package Source size for all Software Update members of a specified Software Update Group
        
            .\Get-UpdatePkgInfo.ps1

        Example 2) Provide the name of the Software Update Group with the -SoftwareUpdateGroup parameter
        
            .\Get-UpdatePkgInfo.ps1 -SoftwareUpdateGroup mySUGName

        Example 3) To display the saved output after the command completes

            .\Get-UpdatePkgInfo.ps1 -ShowOutput $true


# Disclaimer
# This module and it's scripts are not supported under any Microsoft standard support program or service.
# The scripts are provided AS IS without warranty of any kind.
# Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability
# or of fitness for a particular purpose.
# The entire risk arising out of the use or performance of the scripts and documentation remains with you.
# In no event shall Microsoft, its authors, or anyone else involved in the creation, production,
# or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages
# for loss of business profits, business interruption, loss of business information, or other pecuniary loss)
# arising out of the use of or inability to use the sample scripts or documentation,
# even if Microsoft has been advised of the possibility of such damages.
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [string]$SoftwareUpdateGroup,
    [Parameter(Mandatory = $false)]
    [bool]$ShowOutput = $false
    )
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Delete the previous output file if it exist
Remove-Item -Path C:\Windows\Temp\PkgResults.txt -ErrorAction SilentlyContinue

# Setup the ConfigMgr variables
$SiteCode = (Get-WmiObject -Class "SMS_ProviderLocation" -ComputerName $env:COMPUTERNAME -Namespace "ROOT\SMS").SiteCode
$namespace = "ROOT\SMS\site_" + $SiteCode
$DatabaseName = "CM_" + $SiteCode
$ProviderMachineName = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
$initParams = @{}

# Load ConfigMgr module if it isn't loaded already
if (-not(Get-Module -name ConfigurationManager)) {
        Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
   }

# Add site servers PSdrive if it doesn't exist, then Connect to the PSdrive
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}
Set-Location ${SiteCode}: 

#----------------------------------------------------------[Variables]----------------------------------------------------------
# Setup the script variables
$Global:ListOfSUGs = @()
$ListOfUpdates = @()
$Global:UpdatesNotDownloaded = @()
$Global:SelectedSUG  = @()
$Global:SQLResultsCopy = @()
$Global:OutGridViewData = @()

# Create an empty object to store the specific properties of the resulting software update
$UpdateName = New-Object psobject -Property @{
UpdateName = ''
}
# Get the CM SQL Server
$Global:ServerName = (Get-WmiObject -Class "SMS_SCI_SiteDefinition" -ComputerName $env:COMPUTERNAME -Namespace $namespace | Where-Object {$_.SiteCode -eq $SiteCode}).SQLServerName.ToString()
#-----------------------------------------------------------[Functions]------------------------------------------------------------
# List the Software Update Groups
function Get-SUGList {
# https://docs.microsoft.com/en-us/powershell/scripting/samples/selecting-items-from-a-list-box?view=powershell-7

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Sofware Update Group List'
$form.Size = New-Object System.Drawing.Size(360,240)
$form.StartPosition = 'CenterScreen'
$form.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$form.MinimumSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]360,[System.Int32]240))

$okButton = New-Object System.Windows.Forms.Button
$okButton.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right)
$okButton.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]175,[System.Int32]170))
$okButton.Size = New-Object System.Drawing.Size(75,23)
$okButton.MaximumSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$okButton.MinimumSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right)
$cancelButton.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]260,[System.Int32]170))
$cancelButton.Size = New-Object System.Drawing.Size(75,23)
$cancelButton.MaximumSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$cancelButton.MinimumSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75,[System.Int32]23))
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$label = New-Object System.Windows.Forms.Label
$label.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$label.Location = New-Object System.Drawing.Point(10,10)
$label.Size = New-Object System.Drawing.Size(280,20)
$label.Text = 'Please select a Software Update Group:'
$form.Controls.Add($label)

$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom)
$listBox.Location = New-Object System.Drawing.Point(10,30)
$listBox.Size = New-Object System.Drawing.Size(325,20)
$listBox.Height = 133

# Retrieve a list of all SUG's
$Global:ListOfSUGs = (Get-WmiObject -Class "SMS_AuthorizationList" -ComputerName $env:COMPUTERNAME -Namespace $namespace | Select-Object -Property LocalizedDisplayName | Sort-Object -Property LocalizedDisplayName).LocalizedDisplayname

# Add the results to the listbox - Display a progress bar
for ($j = 0; $j -le ($Global:ListOfSUGs.Count -1); $j++){
[void] $listBox.Items.Add($Global:ListOfSUGs[$j])
}

$form.Controls.Add($listBox)
$form.Topmost = $true
$result = $form.ShowDialog()

# Display the list of all SUG's when the OK button is pressed.
if ($result -eq [System.Windows.Forms.DialogResult]::OK){
    $Global:SelectedSUG  = $listBox.SelectedItem
    } # Exit if the cancel button is pressed
    elseif ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
    # Set the PS-Drive back to C:\
    Set-Location C:\ 
    $form.Close()
    Exit
    }
}

# SQL function that queries the DB based on a list of ArticleIDs and CI_UID's
function Invoke-SQL {
   [CmdletBinding()]
   param(
        [Parameter()]
        [string]$ArticleID,
        [string]$CIUID
   )
# Build the SQL query. ArticleID and CIUID will be provided later
$Query1 = "select PkgID, ContentSource, SourceSize from v_Content 
		where Content_ID in 
		(select Content_ID FROM v_CIContents_All where CI_ID in 
		(select CI_ID from v_UpdateInfo where ArticleID = '$($ArticleID)' and CI_UniqueID = '$($CIUID)'))"

#Timeout parameters
$QueryTimeout = 120
$ConnectionTimeout = 30

# Create SQL Connection String
$SQLConnection=New-Object System.Data.SqlClient.SQLConnection
$ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $Global:ServerName,$DatabaseName,$ConnectionTimeout
$SQLConnection.ConnectionString=$ConnectionString

# Connect to the database
$SQLConnection.Open()
# Run the Query
$SQLCommand=New-Object system.Data.SqlClient.SqlCommand($Query1,$SQLConnection)
$SQLCommand.CommandTimeout=$QueryTimeout
$SQLDataSet=New-Object system.Data.DataSet
$SQLDataAdapter=New-Object system.Data.SqlClient.SqlDataAdapter($SQLCommand)
# Add the results to the $SQLDataSet variable
[void]$SQLDataAdapter.fill($SQLDataSet)
# Close the SQL Connection
$SQLConnection.Close()
# Copy results to new array to access the row data
$SQLDatasetRows = $SQLDataSet.Tables[0]
$k = 0
# Check for updates that do not have a PkgID
foreach($row in $SQLDatasetRows){
    if (($row.PkgID.ToString()).Length -eq 0){
        # If there is no PkgId, write the update name to the $Global:UpdatesNotDownloaded variable
       $Global:UpdatesNotDownloaded += "$($UpdateName.UpdateName)"
    }else{
        $SourceSize = $row.SourceSize
        # Calculate SourceSize based on the length of its string value: 10 = GB, 7-9 = MB 5-6 = KB
        if ($SourceSize.ToString().Length -eq 10){
                    $SourceSize = $SourceSize/1GB
                    $ConvertedSize = "$([Math]::Round($SourceSize,2,[MidPointRounding]::AwayFromZero)) GB"
            }elseif ($SourceSize.ToString().Length -gt 6 -and $SourceSize.ToString().Length -lt 10 ){
                    $SourceSize = $SourceSize/1MB
                    $ConvertedSize = "$([Math]::Round($SourceSize,2,[MidPointRounding]::AwayFromZero)) MB"
                }elseif ($SourceSize.ToString().Length -le 7){
                    $SourceSize = $SourceSize/1KB
                    $ConvertedSize = "$([Math]::Round($SourceSize,2,[MidPointRounding]::AwayFromZero)) KB"
                    }

                # Store the PkgName value from WMI
                $PkgName = (Get-WmiObject -Class "SMS_SoftwareUpdatesPackage" -ComputerName $env:COMPUTERNAME -Namespace $namespace | Where-Object {$_.PackageID -eq $row.pkgID}).Name

                # Create a new object to store the specific update info needed
                $SQLResults = New-Object psobject -Property @{
                    Name = $UpdateName.UpdateName
                    PackageID = $row.PkgID
                    PackageName = $PkgName
                    ContentSource = $row.ContentSource
                    SourceSize = $ConvertedSize
                    }

            # Writes the results to the output file everytime the Invoke-SQL function is called
            Write-Output $SQLResults | Format-List -Property Name, ContentSource, PackageName, PackageID, SourceSize | Out-File -FilePath c:\Windows\Temp\PkgResults.txt -Append
            # Copies the $SQLResults to the $Global:SQLResultsCopy variable
            $Global:SQLResultsCopy += $SQLResults
            Write-Progress -Activity "Gathering the update info..." -Status "Progress: $([math]::Round($k/$ListOfUpdates.Count*100))%" -PercentComplete ($k/$ListOfUpdates.Count*100)
            if ($k -lt $ListOfUpdates.Count){$k++}
        # Reset the SQL variables
        $SQLDatasetRows = ""
        $SQLResults = @()
        $row = @()
        $ConvertedSize = @()
        $SourceSize = @()
        }
    }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------
# Call the Get-SUGList function to display the SUG list
if (!$SoftwareUpdateGroup){
    Get-SUGList
}else{
    $Global:SelectedSUG = $SoftwareUpdateGroup
}

# Get a list of CI_ID's from the selcted / provided SUG
$ListOfCIIDs = (Get-CMSoftwareUpdateGroup -Name $Global:SelectedSUG.ToString()).Updates

# Build the list of updates based on the CI_ID's from the returned SUG
$ListOfCIIDs | ForEach-Object -Begin {
        $i = 0
    } -Process {
        $ListOfUpdates += Get-CMSoftwareUpdate -Id $ListOfCIIDs[$i] -Fast
        $i++
            Write-Progress -Activity "Building a list of the software updates..." -Status "Progress: $([math]::Round($i/$ListOfCIIDs.Count*100))%" -PercentComplete ($i/$ListOfCIIDs.Count*100)
    } -End {
}
# Loop through every update in the $ListOfUpdates variable
foreach ($Update in $ListOfUpdates){
    # Store the name of the current update
    $UpdateName.UpdateName = $Update.LocalizedDisplayName

    # Run the Invoke-SQL function to return the remaining update info
    Invoke-SQL -ArticleID $Update.ArticleID -CIUID $Update.CI_UniqueID
}
#-----------------------------------------------------------[Output]---------------------------------------------------------------
# output the software update names that are not downloaded to a package
Write-Output "Software Updates that are not downloaded:" $Global:UpdatesNotDownloaded | Select-Object -Unique | Out-File -FilePath c:\Windows\Temp\PkgResults.txt -Append

# Copy $Global:SQLResultsCopy to $Global:OutGridViewData
$Global:OutGridViewData = $Global:SQLResultsCopy
# Store the missing update info
foreach ($MissingUpdate in $Global:UpdatesNotDownloaded){
    $Global:NotDownloadedForOutGridView = New-Object psobject -Property @{
    Name = $MissingUpdate
    ContentSource = 'is Not downloaded'
    }
# Add the $NowDownloadedForOutGridView to $Global:OutGridViewData
$Global:OutGridViewData += $Global:NotDownloadedForOutGridView
}
#Sort the results and send to Out-GridView
$Global:OutGridViewData | Select-Object -Property Name, ContentSource, PackageName, PackageID, SourceSize -Unique | Sort-Object -Property PackageID -Descending | Out-GridView -Title "Software Update Group: $($Global:SelectedSUG)"

# Open the output file with Notepad
if ($ShowOutput -eq $true){
    notepad.exe c:\Windows\Temp\PkgResults.txt
}

# Set the PS-Drive back to C:\
Set-Location C:\ 

#-------------------------------------------------------------[END]----------------------------------------------------------------
