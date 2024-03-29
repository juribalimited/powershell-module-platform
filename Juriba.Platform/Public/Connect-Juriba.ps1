#requires -Version 7
function Connect-Juriba {
        <#
        .SYNOPSIS
        Creates a connection object and stores globally within the current PS Session to be consumed by other functions within the module

        .DESCRIPTION
        Stores a connection object with instance, SecureString API key, and connection details.

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER Instance

        Dashworks instance with specified port e.g. "https://myinstance.dashworks.app:8443

        .EXAMPLE

        PS> Connect-Juriba -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )
    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $APIKey }
    $uri = "{0}/apiv1/security/userprofile" -f $Instance

    try {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET -ContentType $contentType
        if ($result.StatusCode -eq 200) {
            [SecureString]$APIKey = ConvertTo-SecureString -String $APIKey -AsPlainText
            $global:dwConnection = $result.Content | ConvertFrom-Json
            $dwConnection | Add-Member -MemberType NoteProperty -Name "secureAPIKey" -Value $APIKey
            $dwConnection | Add-Member -MemberType NoteProperty -Name "instance" -Value $Instance
            return $dwConnection
        } 
    } catch {
        Write-Error $_
    }
}