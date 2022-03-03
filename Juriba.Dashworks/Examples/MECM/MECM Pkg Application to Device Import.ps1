<#

.SYNOPSIS
A sample script to query the MECM database for Packages (Packaged Applications) and related devices and import
those relationships into Dashworks.

.DESCRIPTION
A sample script to query the MECM database for Packages (Packaged Applications) and related devices and import
those relationships into Dashworks.
Script assumes the applications and devices already exist and will skip thsoe which do not exist.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$DwInstance,
    [Parameter(Mandatory=$false)]
    [int]$DwPort = 8443,
    [Parameter(Mandatory=$true)]
    [string]$DwAPIKey,
    [Parameter(Mandatory=$true)]
    [string]$DwFeedName,
    [Parameter(Mandatory=$true)]
    [string]$MecmServerInstance,
    [Parameter(Mandatory=$true)]
    [string]$MecmDatabaseName,
    [Parameter(Mandatory=$true)]
    [pscredential]$MecmCredentials
)

#Requires -Version 7
#Requires -Module SqlServer
#Requires -Module @{ ModuleName = 'Juriba.Dashworks'; ModuleVersion = '0.0.14' }

$DashworksParams = @{
    Instance = $DwInstance
    Port = $DwPort
    APIKey = $DwAPIKey
}

$MecmParams = @{
    ServerInstance = $MecmServerInstance
    Database = $MecmDatabaseName
    Credential = $MecmCredentials
}

# Get DW feed
$feed = Get-DwImportDeviceFeed @DashworksParams -FeedName $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-DwImportDeviceFeed @DashworksParams -Name $DwFeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Run query against MECM database
$table = Invoke-Sqlcmd @MecmParams -InputFile "$PSScriptRoot\MECM Pkg Application to Device Query.sql"

Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue

$i = 0
$groupedTable = ($table | Group-Object DeviceUniqueIdentifier)

foreach ($device in $groupedTable) {
    $i++
    $deviceUniqueIdentifier = $device.Name

    Write-Progress -Activity "Importing Device/Application Relationships to Dashworks" -Status ("Processing device: {0}" -f $deviceUniqueIdentifier) -PercentComplete ($i/$groupedTable.Count*100)

    $existingDevice = Get-DwImportDevice @DashworksParams -ImportId $importId -UniqueIdentifier $deviceUniqueIdentifier
    if ($existingDevice) {
        # build json payload from grouped table results
        $jsonBody = @{applications = @($device.Group | Select-Object @{Name='applicationDistHierId'; Expression={$importId}}, @{Name='applicationBusinessKey'; Expression={$_.ApplicationUniqueIdentifier}}, @{Name='installed'; Expression={$true}})} | ConvertTo-Json
        # post to api
        $result = Set-DwImportDevice @DashworksParams -ImportId $importId -UniqueIdentifier $deviceUniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        Write-Verbose ("device not found {0}" -f $deviceUniqueIdentifier)
    }
}
