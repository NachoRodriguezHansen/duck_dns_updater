<#
.SYNOPSIS
    Updates the IP address of your Duck DNS domain(s).
.DESCRIPTION
    Updates the IP address of your Duck DNS domain(s). Intended to be run as a scheduled task.
.PARAMETER Domains
    A comma-separated list of your Duck DNS domains to update.
.PARAMETER Token
    Your Duck DNS token.
.PARAMETER IP
    The IP address to use. If you leave it blank, Duck DNS will detect your gateway IP.
.INPUTS
    None. You cannot pipe objects to this script.
.OUTPUTS
    None. This script does not generate any output.
.EXAMPLE
    .\update_duck_dns.ps1 -Domains "foo,bar" -Token my-duck-dns-token
#>

Param (
    [Parameter(Mandatory=$False, HelpMessage="Comma separate the domains if you want to update more than one.")]
    [String]$Domains,
    
    [Parameter(Mandatory=$False)]
    [String]$Token,
    
    [Parameter(Mandatory=$False)]
    [String]$IP
)

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$url = "https://www.duckdns.org/update?domains=$Domains&token=$Token&ip=$IP"

try {
    if ($PSVersionTable.PSVersion.Major -gt 2) {
        $ResponseString = (Invoke-WebRequest $url -UseBasicParsing).ToString()
    }
    else {
        $ResponseString = (New-Object System.IO.StreamReader ([System.Net.WebRequest]::Create($url).GetResponse().GetResponseStream())).ReadToEnd()
    }

    $logEntry = "$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss'), response: $ResponseString."

    if (Test-Path "$dir\output.txt") {
        Add-Content "$dir\output.txt" -Value $logEntry
    }
    else {
        New-Item -Path "$dir\output.txt" -ItemType File -Force | Out-Null
        Add-Content "$dir\output.txt" -Value $logEntry
    }
}
catch {
    $errorMessage = $_.Exception.Message
    $logEntry = "$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss'), error: $errorMessage."

    if (Test-Path "$dir\output.txt") {
        Add-Content "$dir\output.txt" -Value $logEntry
    }
    else {
        New-Item -Path "$dir\output.txt" -ItemType File -Force | Out-Null
        Add-Content "$dir\output.txt" -Value $logEntry
    }
}
