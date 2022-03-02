#Requires -Version 7
function Remove-DwImportApplication {
    <#
        .SYNOPSIS
        Deletes an application in the import API.

        .DESCRIPTION
        Deletes an application in the import API.
        Takes the ImportId and UniqueIdentifier as an input.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the application.

        .PARAMETER ImportId

        ImportId for the application.

        .EXAMPLE
        PS> Remove-DwImportApplication -ImportId 1 -UniqueIdentifier "app123" -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [int]$Port = 8443,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [string]$UniqueIdentifier,
        [parameter(Mandatory=$true)]
        [int]$ImportId
    )

    $uri = "https://{0}:{1}/apiv2/imports/applications/{2}/items/{3}" -f $Instance, $Port, $ImportId, $UniqueIdentifier
    $headers = @{'x-api-key' = $APIKey}

    try {
        if ($PSCmdlet.ShouldProcess($UniqueIdentifier)) {
            $result = Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers
            return $result
        }
    }
    catch {
        Write-Error $_
    }

}