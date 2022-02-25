
Function Get-AzAccessToken{
    Param (
        [parameter(Mandatory=$True)]
        [string]$TenantId,

        [parameter(Mandatory=$True)]
        [string]$ClientId,

        [Parameter(Mandatory=$True)]
        [string]$ClientSecret,

        [Parameter(Mandatory=$false)]
        [string]$Scope
    )

    $OAuthURI = "https://login.microsoftonline.com/$TenantId/oauth2/token"

    $OAuthBody=@{}
    $OAuthBody.Add('grant_type','client_credentials')
    $OAuthBody.Add('client_id',$ClientId)
    $OAuthBody.Add('client_secret',$ClientSecret)
    if ($scope)
    {
        $OAuthBody.Add('scope',$scope)
    }
    else
    {
        $OAuthBody.Add('resource','https://graph.microsoft.com')
    }

    $OAuthheaders =
    @{
        "content-type" = "application/x-www-form-urlencoded"
    }

    $accessToken = Invoke-RESTMethod -Method 'POST' -URI $OAuthURI -Body $OAuthBody -Headers $OAuthheaders

    return $accessToken.access_Token
    <#
    .Synopsis
    Gets a session bearer token for the Azure credentials provided.

    .Description
    Takes the three required Azure credentials and returns the OAuth2 access token provided by the Microsoft Graph authentication provider.

    .Parameter TenantId
    The Directory or tenant ID of the Azure system being connected to.

    .Parameter ClientId
    The Client Id or Application ID connecting.

    .Parameter ClientSecret
    The client secret of the client / application being used to connect.

    .Outputs
    Output type [string]
    The text string containing the OAuth2 accessToken returned from the Azure authentication provider.

    .Example
    # Get the AccessToken for the credentials passed.
    $accessToken = Get-AzAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
    #>
}
Export-Modulemember -function Get-AzAccessToken

Function Get-AzureUserTable([string]$accessToken){
    <#
    .Synopsis
    Get a datatable containing all Azure user data.

    .Description
    Uses the /users Graph endpoint to pull all user information into a data table for insersion into a SQL database.

    .Parameter accessToken
    The access token for the session you are pulling information from.

    .Outputs
    Output type [system.data.datatable]
    A datatable containing all of the rows returned by the /users Graph API Endpoint.

    .Notes
    Any nested data returned by Azure will be pushed into the data table as a string containing the nested JSON.

    .Example
    # Get the user data for the access token passed.
    $dtAzureUserData = Get-AzureUsers -accessToken $AccessToken
    #>

    $uri='https://graph.microsoft.com/v1.0/users?$select=id,accountEnabled,ageGroup,assignedLicenses,assignedPlans,businessPhones,city,companyName,consentProvidedForMinor,country,createdDateTime,creationType,deletedDateTime,department,displayName,employeeHireDate,employeeId,employeeOrgData,employeeType,externalUserState,externalUserStateChangeDateTime,faxNumber,givenName,id,identities,imAddresses,isResourceAccount,jobTitle,lastPasswordChangeDateTime,legalAgeGroupClassification,licenseAssignmentStates,mail,mailNickname,mobilePhone,officeLocation,onPremisesDistinguishedName,onPremisesDomainName,onPremisesExtensionAttributes,onPremisesImmutableId,onPremisesLastSyncDateTime,onPremisesProvisioningErrors,onPremisesSamAccountName,onPremisesSecurityIdentifier,onPremisesSyncEnabled,onPremisesUserPrincipalName,otherMails,passwordPolicies,passwordProfile,postalCode,preferredDataLocation,preferredLanguage,provisionedPlans,proxyAddresses,refreshTokensValidFromDateTime,showInAddressList,signInSessionsValidFromDateTime,state,streetAddress,surname,usageLocation,userPrincipalName,userType'

    $FirstRun = $True

    Do
    {
        $users = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)" } -Uri $uri -Method Get

        if($FirstRun)
        {
            $dtResults = New-Object System.Data.DataTable
            $ScriptBlock=$null

            foreach($object_properties in $($users.Value[0] | Get-Member | where-object{$_.MemberType -eq "NoteProperty"}))
            {

                $DataType = switch ($object_properties.Definition.substring(0,$object_properties.Definition.IndexOf(' ')))
                {
                    'datetime' {'datetime'}
                    'bool' {'boolean'}
                    'long' {'int64'}
                    'string' {'string'}
                    'object' {'string'}
                    default {'string'}
                }
                $dtResults.Columns.Add($object_properties.Name,$datatype) | Out-Null

                $ScriptBlock += 'if ($entry.' + $object_properties.Name + ' -ne $null) {if ($entry.' + $object_properties.Name + '.Value -ne $null) { $DataRow.' + $object_properties.Name + ' = $entry.' + $object_properties.Name + '.Value }else{ if ($entry.' + $object_properties.Name + '.GetType().Name -eq "Object[]") { $DataRow.' + $object_properties.Name + ' = ($entry.' + $object_properties.Name + ' | ConvertTo-JSON).ToString() } else { $DataRow.' + $object_properties.Name + ' = $entry.' + $object_properties.Name + ' } } } else {$DataRow.' + $object_properties.Name + " = [DBNULL]::Value}`n"
            }
        }

        $FirstRun = $False #After the first iteration, don't try to add the data columns

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)

        foreach($entry in $users.Value)
        {
            $DataRow = $dtResults.NewRow()

            & $ScriptBlock

            $dtResults.Rows.Add($DataRow)
        }

        $uri = $users.'@odata.nextLink'
    }
    while ($null -ne $users.'@odata.nextLink')

    return @(,($dtResults))

}
Export-Modulemember -function Get-AzureUserTable

Function Get-IntuneDeviceTable([string]$accessToken){

    <#
    .Synopsis
    Get a datatable containing all InTune device data.

    .Description
    Uses the /deviceManagement/managedDevices Graph endpoint to pull all device information into a data table for insersion into a SQL database.

    .Parameter accessToken
    The access token for the session you are pulling information from.

    .Outputs
    Output type [system.data.datatable]
    A datatable containing all of the rows returned by the /deviceManagement/managedDevices Graph API Endpoint.

    .Notes
    Any nested data returned by Azure will be pushed into the data table as a string containing the nested JSON.

    .Example
    # Get the InTune data for the access token passed.
    $dtInTuneData = Get-IntuneDevices -accessToken $AccessToken
    #>

    $dtResults = New-Object System.Data.DataTable

    $uri='https://graph.microsoft.com/v1.0/deviceManagement/managedDevices'

    $CreateTable = $True

    Do
    {
        $devices = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)" } -Uri $uri -Method Get

        $ScriptBlock=$null

        foreach($object_properties in $($devices.Value[0] | Get-Member | where-object{$_.MemberType -eq "NoteProperty"}))
        {
            if($CreateTable)
            {
                $DataType = switch ($object_properties.Definition.substring(0,$object_properties.Definition.IndexOf(' ')))
                {
                    'datetime' {'datetime'}
                    'bool' {'boolean'}
                    'long' {'int64'}
                    'string' {'string'}
                    'object' {'string'}
                    default {'string'}
                }
                $dtResults.Columns.Add($object_properties.Name,$datatype) | Out-Null
            }

            $ScriptBlock += 'if ($entry.' + $object_properties.Name + ' -ne $null) {if ($entry.' + $object_properties.Name + '.Value -ne $null) { $DataRow.' + $object_properties.Name + ' = $entry.' + $object_properties.Name + '.Value }else{ if ($entry.' + $object_properties.Name + '.GetType().Name -eq "Object[]") { $DataRow.' + $object_properties.Name + ' = ($entry.' + $object_properties.Name + ' | ConvertTo-JSON).ToString() } else { $DataRow.' + $object_properties.Name + ' = $entry.' + $object_properties.Name + ' } } } else {$DataRow.' + $object_properties.Name + " = [DBNULL]::Value}`n"
        }

        $CreateTable = $False #After the first iteration, don't try to add the data columns

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)

        foreach($entry in $devices.Value)
        {
            $DataRow = $dtResults.NewRow()

            & $ScriptBlock

            $dtResults.Rows.Add($DataRow)
        }

        #$devicesDatatable = $devices.value | Out-DataTable
        #$devicesDatatable.Columns.Add("DistHierId", [int], $DistHierId) | Out-Null

        $uri = $devices.'@odata.nextLink'
    }
    while ($null -ne $users.'@odata.nextLink')

    return @(,($dtResults))
}
Export-Modulemember -function Get-IntuneDeviceTable

Function Convert-DwAPIDeviceFromInTune($IntuneDataTable){

    $dataTable = New-Object System.Data.DataTable

    $dataTable.Columns.Add("uniqueComputerIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("hostname", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemName", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemVersion", [string]) | Out-Null
    $dataTable.Columns.Add("computerManufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("computerModel", [string]) | Out-Null
    $dataTable.Columns.Add("firstSeenDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("lastSeenDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("serialNumber", [string]) | Out-Null
    $dataTable.Columns.Add("memoryKb", [string]) | Out-Null
    $dataTable.Columns.Add("macAddress", [string]) | Out-Null
    $dataTable.Columns.Add("totalHDDSpaceMb", [string]) | Out-Null
    $dataTable.Columns.Add("targetDriveFreeSpaceMb", [string]) | Out-Null


    foreach($Row in $dtInTuneData.Rows)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()

        $NewRow.uniqueComputerIdentifier = $Row.id
        $NewRow.hostname = $Row.deviceName
        $NewRow.operatingSystemName = $Row.operatingSystem
        $NewRow.operatingSystemVersion = $Row.osVersion
        $NewRow.computerManufacturer = $Row.manufacturer
        $NewRow.computerModel = $Row.model
        if ($Row.enrolledDateTime -gt '1753-01-01'){$NewRow.firstSeenDate = $Row.enrolledDateTime}
        if ($Row.lastSyncDateTime -gt '1753-01-01'){$NewRow.lastSeenDate = $Row.lastSyncDateTime}
        $NewRow.serialNumber = $Row.serialNumber
        $NewRow.memoryKb = if($Row.physicalMemoryInBytes){($Row.physicalMemoryInBytes)/1024}else{[DBNULL]::Value}
        $NewRow.macAddress = If($Row.ethernetMacAddress){$Row.ethernetMacAddress}elseif($Row.wiFiMacAddress){$Row.wiFiMacAddress}else{[DBNULL]::Value}
        $NewRow.totalHDDSpaceMb = If($Row.totalStorageSpaceInBytes){$Row.totalStorageSpaceInBytes/(1024*1024)}else{[DBNULL]::Value}
        $NewRow.targetDriveFreeSpaceMb = If($Row.freeStorageSpaceInBytes){$Row.freeStorageSpaceInBytes/(1024*1024)}else{[DBNULL]::Value}

        $dataTable.Rows.Add($NewRow)
    }

    Return ,$dataTable

    <#
    .Synopsis
    Return a datatable in the DWAPI Computers data format from the Get-IntuneDevices return table

    .Description
    Takes in a datatable returned from the Get-IntuneDevices and strips the fields required for insertion into the Dashworks Computer API.

    .Parameter IntuneDataTable
    A System.Data.DataTable object returned from the Get-IntuneDevices function in the DWAzure module

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Computers API calls populated with the provided data from InTune.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DWDeviceFromInTune -IntuneDataTable $dtInTuneData
    #>
}
Export-Modulemember -function Convert-DwAPIDeviceFromInTune

Function Convert-DwAPIUserFromAzure($AzureDataTable){

    $dataTable = New-Object System.Data.DataTable

    $dataTable.Columns.Add("username", [string]) | Out-Null
    $dataTable.Columns.Add("commonObjectName", [string]) | Out-Null
    $dataTable.Columns.Add("displayName", [string]) | Out-Null
    $dataTable.Columns.Add("objectGuid", [string]) | Out-Null
    $dataTable.Columns.Add("lastLogonDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("disabled", [string]) | Out-Null
    $dataTable.Columns.Add("surname", [string]) | Out-Null
    $dataTable.Columns.Add("givenName", [string]) | Out-Null
    $dataTable.Columns.Add("emailAddress", [string]) | Out-Null
    $dataTable.Columns.Add("userPrincipalName", [string]) | Out-Null


    foreach($Row in $AzureDataTable.Rows)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()

        $NewRow.username = $Row.userPrincipalName
        $NewRow.commonObjectName = $Row.userPrincipalName
        $NewRow.displayName = $Row.displayName
        $NewRow.objectGuid = $Row.id
        if ($Row.refreshTokensValidFromDateTime -gt '1753-01-01'){$NewRow.lastLogonDate = $Row.refreshTokensValidFromDateTime}
        $NewRow.disabled = -not $Row.accountEnabled
        $NewRow.surname = $Row.surname
        $NewRow.givenName = $Row.givenName
        $NewRow.emailAddress = $Row.userPrincipalName
        $NewRow.userPrincipalName = $Row.userPrincipalName

        $dataTable.Rows.Add($NewRow)
    }

    Return ,$dataTable

    <#
    .Synopsis
    Return a datatable in the DWAPI User data format from the Get-AzureUsers return table

    .Description
    Takes in a datatable returned from the Get-AzureUsers and strips the fields required for insertion into the Dashworks User API.

    .Parameter IntuneDataTable
    A System.Data.DataTable object returned from the Get-AzureUsers function in the DWAzure module

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Users API calls populated with the provided data from Azure.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIUserFromAzure -AzureDataTable $dtAzureUserData
    #>
}
Export-Modulemember -function Convert-DwAPIUserFromAzure

function Invoke-DwAPIUploadDeviceFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI device. Inserts these devices one at a time.

    .Parameter APIUri
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter FeedId
    The id of the device feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW Device API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the device feed id for the named feed.
    Write-DeviceFeedData -APIUri $uriRoot -DWDataTable $dtDashworksInput -FeedId $DeviceImportID -APIKey $APIKey
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [parameter(Mandatory=$True)]
        [string]$APIUri,
        
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DWDataTable,

        [Parameter(Mandatory=$True)]
        [string]$APIKey,

        [parameter(Mandatory=$False)]
        [string[]]$FeedName = $null,

        [parameter(Mandatory=$False)]
        [string[]]$FeedId
    )

    $RowCount = 0

    if (-not $FeedId)
    {
        if (-not $FeedName)
        {
            return 'Device feed not found by name or ID'
        }

        $FeedId = Get-DwAPIDeviceFeed -APIUri $APIUri -ApiKey $APIKey -FeedName $FeedName

        if (-not $FeedId)
        {
            return 'Device feed not found by name or ID'
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "$APIUri/apiv2/imports/devices/$FeedId/items"

    foreach($Row in $DWDataTable)
    {
        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        try {
            if ($PSCmdlet.ShouldProcess($UniqueComputerIdentifier)) {
                Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null
            }
        }
        catch {
            Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, ($_ | ConvertFrom-Json).details)
            break
        }
        $RowCount++
    }

    Return "$RowCount devices added"
}
Export-Modulemember -function Invoke-DwAPIUploadDeviceFeedDataTable

function Invoke-DwAPIAUploadUserFeedDataTable {

    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI device. Inserts these devices one at a time.

    .Parameter APIUri
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter FeedId
    The id of the device feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW Device API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the device feed id for the named feed.
    Write-DeviceFeedData -APIUri $uriRoot -DWDataTable $dtDashworksInput -FeedId $DeviceImportID -APIKey $APIKey
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [parameter(Mandatory=$True)]
        [string]$APIUri,
        
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DWDataTable,

        [Parameter(Mandatory=$True)]
        [string]$APIKey,

        [parameter(Mandatory=$False)]
        [string[]]$FeedName = $null,

        [parameter(Mandatory=$False)]
        [string[]]$FeedId
    )
    $RowCount = 0

    if (-not $FeedId)
    {
        if (-not $FeedName)
        {
            return 'Device feed not found by name or ID'
        }

        $FeedId = Get-DwAPIUserFeed -APIUri $APIUri -ApiKey $APIKey -FeedName $FeedName

        if (-not $FeedId)
        {
            return 'Device feed not found by name or ID'
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "$APIUri/apiv2/imports/users/$FeedId/items"

    
    WRITE-OUTPUT "Got here with $($DWDataTable.Rows.Count) Rows to process"

    foreach($Row in $DWDataTable)
    {   
        WRITE-OUTPUT "Got here"
        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        try {
            if (-not $PSCmdlet.ShouldProcess($Row.Username)) {
                WRITE-OUTPUT "Got here also"
                Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null
            }
        }
        catch {
            Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, ($_ | ConvertFrom-Json).details)
            break
        }
        $RowCount++
    }

    Return "$RowCount users added"

}
Export-Modulemember -function Invoke-DwAPIAUploadUserFeedDataTable

function Invoke-DwAPIAUploadUserFeedFromAD {
    <#
    .Synopsis
    Pulls user data from Get-ADUser and upload to a DW User feed

    .Description
    Takes all users from Get-ADUser (optional server/cred parameters) transforms the fields into a datatable in the format required
    for the DW API and then uploads that user data to a named or numbered data feed.

    .Parameter APIUri
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter FeedId
    The id of the device feed to be used.

    .Parameter ADServer
    The name of a DC to connect Get-ADUser to.

    .Parameter Credentials
    The credentials to use when calling Get-ADUser

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the device feed id for the named feed.
    Write-DeviceFeedData -APIUri $uriRoot -DWDataTable $dtDashworksInput -FeedId $DeviceImportID -APIKey $APIKey
    #>

    Param (
        [parameter(Mandatory=$True)]
        [string]$APIUri,

        [Parameter(Mandatory=$True)]
        [string]$APIKey,

        [parameter(Mandatory=$False)]
        [string]$FeedName = $null,

        [parameter(Mandatory=$False)]
        [string]$FeedId,

        [parameter(Mandatory=$False)]
        [string]$ADServer,

        [parameter(Mandatory=$False)]
        [PSCredential]$Cred
    )

    $Properties = @("lastlogontimestamp","description","homeDirectory","homeDrive","mail","CanonicalName")
    
    if ($ADServer)
    {
        if ($Cred)
        {
            $ADUsers = get-aduser -Filter * -Properties $properties -Server $ADServer -Credential $Cred
        }
        else
        {
            $ADUsers = get-aduser -Filter * -Properties $properties -Server $ADServer 
        }
    }else{
        if ($Cred)
        {
            $ADUsers = get-aduser -Filter * -Properties $properties -Credential $Cred
        }
        else
        {
            $ADUsers = get-aduser -Filter * -Properties $properties
        }
    }

    $dataTable = New-Object System.Data.DataTable

    $dataTable.Columns.Add("username", [string]) | Out-Null
    $dataTable.Columns.Add("commonObjectName", [string]) | Out-Null
    $dataTable.Columns.Add("displayName", [string]) | Out-Null
    $dataTable.Columns.Add("objectSid", [string]) | Out-Null
    $dataTable.Columns.Add("objectGuid", [string]) | Out-Null
    $dataTable.Columns.Add("lastLogonDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("disabled", [string]) | Out-Null
    $dataTable.Columns.Add("surname", [string]) | Out-Null
    $dataTable.Columns.Add("givenName", [string]) | Out-Null
    $dataTable.Columns.Add("description", [string]) | Out-Null
    $dataTable.Columns.Add("homeDirectory", [string]) | Out-Null
    $dataTable.Columns.Add("homeDrive", [string]) | Out-Null
    $dataTable.Columns.Add("emailAddress", [string]) | Out-Null
    $dataTable.Columns.Add("userPrincipalName", [string]) | Out-Null
    $dataTable.Columns.Add("adCanonicalName", [string]) | Out-Null

    foreach($User in $ADUsers)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()

        $NewRow.username = $User.SamAccountName
        $NewRow.commonObjectName = $User.CN
        $NewRow.displayName = $User.Name
        $NewRow.objectSid = $User.sid
        $NewRow.objectGuid = $User.objectGuid
        $NewRow.lastLogonDate = if ([datetime]::FromFileTime($User.lastlogontimestamp) -gt '1753-01-01'){[datetime]::FromFileTime($User.lastlogontimestamp)}else{[DBNull]::Value}
        $NewRow.disabled = -not $User.Enabled
        $NewRow.surname = $User.surname
        $NewRow.givenName = $User.givenName
        $NewRow.description = $User.Description
        $NewRow.homeDirectory = $User.homeDirectory
        $NewRow.homeDrive = $User.homeDrive
        $NewRow.emailAddress = $User.mail
        $NewRow.userPrincipalName = $User.userPrincipalName
        $NewRow.adCanonicalName = $User.CanonicalName

        $dataTable.Rows.Add($NewRow)
    }


    $RowCount = 0

    if (-not ($FeedId))
    {
        if (-not ($FeedName))
        {
            throw 'Device feed not found by name or ID'
        }

        $FeedId = Get-DwAPIUserFeed -APIUri $APIUri -ApiKey $APIKey -FeedName $FeedName

        if (-not $FeedId)
        {
            throw 'Device feed not found by name or ID'
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "$APIUri/apiv2/imports/users/$FeedId/items"

    foreach($Row in $dataTable)
    {
        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null
        $RowCount++
    }

    Return "$RowCount users added"
}