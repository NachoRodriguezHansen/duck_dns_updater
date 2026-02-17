<#
.SYNOPSIS
    Updates the IP address of your Duck DNS domain(s).
.DESCRIPTION
    Updates the IP address of your Duck DNS domain(s) via the Duck DNS API.
    Can use parameters, environment variables, or a config.json file for credentials.
    Intended to be run as a scheduled task.
.PARAMETER Domains
    Comma-separated list of Duck DNS domains to update (e.g., "foo,bar").
    Can also use DUCKDNS_DOMAINS environment variable.
.PARAMETER Token
    Your Duck DNS API token.
    Can also use DUCKDNS_TOKEN environment variable for security.
.PARAMETER IP
    IP address to update. If blank, Duck DNS will detect your public gateway IP.
    Can also use DUCKDNS_IP environment variable.
.PARAMETER ConfigPath
    Path to config.json file with domains and token (alternative to parameters).
.INPUTS
    None. You cannot pipe objects to this script.
.OUTPUTS
    Log entries to output.txt in the script directory.
.EXAMPLE
    .\update_duck_dns.ps1 -Domains "foo,bar" -Token my-token
    .\update_duck_dns.ps1 -ConfigPath "./config.json"
    .\update_duck_dns.ps1  # Uses DUCKDNS_DOMAINS and DUCKDNS_TOKEN from environment
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$False, HelpMessage="Comma-separated domain names")]
    [String]$Domains,
    
    [Parameter(Mandatory=$False, HelpMessage="Duck DNS API token")]
    [String]$Token,
    
    [Parameter(Mandatory=$False, HelpMessage="IP address to update (optional)")]
    [String]$IP,
    
    [Parameter(Mandatory=$False, HelpMessage="Path to config.json file")]
    [String]$ConfigPath
)


# Script variables
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "output.txt"
$ConfigFile = if ($ConfigPath) { $ConfigPath } else { Join-Path $ScriptDir "config.json" }
$DuckDnsUrl = "https://www.duckdns.org/update"
$ConsoleHostNames = @('ConsoleHost', 'Windows PowerShell ISE Host', 'Visual Studio Code Host')

# Color-coded logging function
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet("Info", "Error", "Success", "Warning")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy.MM.dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to file
    Add-Content -Path $LogFile -Value $logEntry -Force
    
    # Also write to console if running interactively
    foreach ($hostName in $ConsoleHostNames) {
        if ($host.name -eq $hostName) {
            $colors = @{
                "Info"    = "White"
                "Error"   = "Red"
                "Success" = "Green"
                "Warning" = "Yellow"
            }
            Write-Host $logEntry -ForegroundColor $colors[$Level]
            break
        }
    }
}

# Load configuration from file
function Get-Configuration {
    if (Test-Path $ConfigFile) {
        try {
            $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            Write-Log "Configuration loaded from $ConfigFile" "Info"
            return $config
        }
        catch {
            Write-Log "Error reading config.json: $($_.Exception.Message)" "Error"
            return $null
        }
    }
    return $null
}

# Validate and get credentials
function Get-Credentials {
    param(
        [string]$DomainsParam,
        [string]$TokenParam,
        [string]$IpParam
    )
    
    # Priority: Parameters > Environment Variables > Config File
    
    # Get Domains
    $domains = $DomainsParam
    if (-not $domains) {
        $domains = $env:DUCKDNS_DOMAINS
    }
    if (-not $domains) {
        $config = Get-Configuration
        if ($config -and $config.domains) {
            $domains = $config.domains
        }
    }
    
    # Get Token
    $token = $TokenParam
    if (-not $token) {
        $token = $env:DUCKDNS_TOKEN
    }
    if (-not $token) {
        $config = Get-Configuration
        if ($config -and $config.token) {
            $token = $config.token
        }
    }
    
    # Get IP (optional)
    $ip = $IpParam
    if (-not $ip) {
        $ip = $env:DUCKDNS_IP
    }
    if (-not $ip) {
        $config = Get-Configuration
        if ($config -and $config.ip) {
            $ip = $config.ip
        }
    }
    
    # Validate mandatory fields
    if (-not $domains) {
        Write-Log "ERROR: Domains not provided. Use -Domains, DUCKDNS_DOMAINS environment variable, or config.json" "Error"
        exit 1
    }
    
    if (-not $token) {
        Write-Log "ERROR: Token not provided. Use -Token, DUCKDNS_TOKEN environment variable, or config.json" "Error"
        exit 1
    }
    
    return @{
        Domains = $domains
        Token   = $token
        IP      = $ip
    }
}

# Main update function
function Update-DuckDns {
    param(
        [string]$Domains,
        [string]$Token,
        [string]$IP
    )
    
    try {
        # Build request URL with proper encoding
        $uriBuilder = "$DuckDnsUrl`?"
        $uriBuilder += "domains=$([System.Uri]::EscapeDataString($Domains))"
        $uriBuilder += "&token=$([System.Uri]::EscapeDataString($Token))"
        
        if ($IP) {
            $uriBuilder += "&ip=$([System.Uri]::EscapeDataString($IP))"
        }
        
        Write-Log "Sending update request for domain(s): $Domains" "Info"
        
        # Make the request and normalize to string (some hosts return byte[] in .Content)
        if ($PSVersionTable.PSVersion.Major -gt 2) {
            $raw = (Invoke-WebRequest $uriBuilder -UseBasicParsing -TimeoutSec 10).Content
            if ($raw -is [byte[]]) {
                try {
                    $response = [System.Text.Encoding]::UTF8.GetString($raw).Trim()
                }
                catch {
                    $response = [System.Text.Encoding]::Default.GetString($raw).Trim()
                }
            }
            elseif ($null -ne $raw) {
                $response = $raw.ToString().Trim()
            }
            else {
                $response = ""
            }
        }
        else {
            $response = (New-Object System.IO.StreamReader ([System.Net.WebRequest]::Create($uriBuilder).GetResponse().GetResponseStream())).ReadToEnd().Trim()
        }
        
        # Validate response
        if ($response -like "*OK*") {
            Write-Log "SUCCESS: Duck DNS updated. Response: $response" "Success"
        }
        elseif ($response -like "*NOTOK*") {
            Write-Log "Duck DNS response indicates failure: $response" "Warning"
        }
        else {
            Write-Log "Duck DNS response: $response" "Info"
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "ERROR: Failed to update Duck DNS - $errorMsg" "Error"
        exit 1
    }
}

# Main execution
try {
    Write-Log "Duck DNS Updater started" "Info"
    
    # Get credentials from various sources
    $creds = Get-Credentials -DomainsParam $Domains -TokenParam $Token -IpParam $IP
    
    # Perform the update
    Update-DuckDns -Domains $creds.Domains -Token $creds.Token -IP $creds.IP
    
    Write-Log "Duck DNS Updater completed successfully" "Success"
}
catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" "Error"
    exit 1
}
