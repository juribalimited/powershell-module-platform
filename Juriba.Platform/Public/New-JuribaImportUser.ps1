#Requires -Version 7
function New-JuribaImportUser {
    [alias("New-DwImportUser")]
    <#
        .SYNOPSIS
        Creates a new Dashworks user using the import API.

        .DESCRIPTION
        Creates a new Dashworks user using the import API.
        Takes the ImportId and JsonBody as an input.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ImportId

        ImportId for the user.

        .PARAMETER JsonBody

        Json payload with updated user details.

        .EXAMPLE
        PS> New-JuribaImportUser -ImportId 1 -JsonBody $jsonBody -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [ValidateScript({
            ((Test-Json $_) -and (($_ | ConvertFrom-Json).username))
        },
        ErrorMessage = "JsonBody is not valid json or does not contain a username"
        )]
        [parameter(Mandatory=$true)]
        [string]$JsonBody
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId
        $headers = @{'x-api-key' = $APIKey}
    
        try {
            if ($PSCmdlet.ShouldProcess(($JsonBody | ConvertFrom-Json).username)) {
                $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body $jsonBody
                return $result
            }
        }
        catch {
            Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}