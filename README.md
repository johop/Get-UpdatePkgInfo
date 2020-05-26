# Get-UpdatePkgInfo
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
