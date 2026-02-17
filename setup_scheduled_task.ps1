<#
.SYNOPSIS
    Helper script to configure Duck DNS Updater as a scheduled task on Windows
    
.DESCRIPTION
    Creates a scheduled task that runs update_duck_dns.ps1 at a chosen interval.
    Must be run as Administrator.

.EXAMPLE
    .\setup_scheduled_task.ps1
#>

# Verify running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "=== Duck DNS Updater - Scheduled Task Setup ===" -ForegroundColor Cyan

# Resolve script path
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$DuckDnsScript = Join-Path $ScriptPath "update_duck_dns.ps1"

if (-not (Test-Path $DuckDnsScript)) {
    Write-Host "ERROR: update_duck_dns.ps1 not found in $ScriptPath" -ForegroundColor Red
    exit 1
}

# Ask configuration method
Write-Host "`nHow would you like to provide credentials?" -ForegroundColor Yellow
Write-Host "1. Environment variables (recommended)" -ForegroundColor Green
Write-Host "2. Script parameters"
Write-Host "3. config.json file"
$choice = Read-Host "Select option (1-3)"

$argument = "-NoProfile -ExecutionPolicy Bypass -File `"$DuckDnsScript`""

switch ($choice) {
    "1" {
        Write-Host "`nUsing environment variables:" -ForegroundColor Cyan
        Write-Host "  DUCKDNS_DOMAINS"
        Write-Host "  DUCKDNS_TOKEN"
        Write-Host "  DUCKDNS_IP (optional)"
        Write-Host "`nMAKE SURE you have set these variables first:" -ForegroundColor Yellow
        Write-Host "  [Environment]::SetEnvironmentVariable('DUCKDNS_DOMAINS', 'your-domain', 'User')" -ForegroundColor Gray
        Write-Host "  [Environment]::SetEnvironmentVariable('DUCKDNS_TOKEN', 'your-token', 'User')" -ForegroundColor Gray
    }
    "2" {
        $domains = Read-Host "Domains (comma separated)"
        $token = Read-Host "Token (leave empty to use environment variable)" -AsSecureString
        $tokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($token))

        $argument += " -Domains `"$domains`""
        if ($tokenPlain) {
            $argument += " -Token `"$tokenPlain`""
        }
    }
    "3" {
        Write-Host "`nUsing config.json" -ForegroundColor Cyan
        $configPath = Read-Host "Path to config.json (Enter to use script folder)"
        if (-not $configPath) {
            $configPath = Join-Path $ScriptPath "config.json"
        }

        if (-not (Test-Path $configPath)) {
            Write-Host "WARNING: $configPath does not exist. Copy from config.json.example" -ForegroundColor Yellow
        }

        $argument += " -ConfigPath `"$configPath`""
    }
    default {
        Write-Host "Invalid option" -ForegroundColor Red
        exit 1
    }
}

# Ask interval
Write-Host "`nHow often should the update run?" -ForegroundColor Yellow
Write-Host "1. 5 minutes (testing)"
Write-Host "2. 15 minutes"
Write-Host "3. 30 minutes"
Write-Host "4. 1 hour (recommended)"
Write-Host "5. 6 hours"
Write-Host "6. 24 hours (daily)"
$intervalChoice = Read-Host "Select option (1-6)"

$intervals = @{
    "1" = @{ Minutes = 5 }
    "2" = @{ Minutes = 15 }
    "3" = @{ Minutes = 30 }
    "4" = @{ Hours = 1 }
    "5" = @{ Hours = 6 }
    "6" = @{ Hours = 24 }
}

if (-not $intervals.ContainsKey($intervalChoice)) {
    Write-Host "Invalid option" -ForegroundColor Red
    exit 1
}

$interval = $intervals[$intervalChoice]
$intervalDesc = if ($interval.ContainsKey("Minutes")) {
    "$($interval.Minutes) minutes"
} else {
    "$($interval.Hours) hours"
}

# Create the scheduled task
Write-Host "`nWhat name should the task use?" -ForegroundColor Yellow
$taskName = Read-Host "Name (Enter for 'DuckDnsUpdater')"
if (-not $taskName) { $taskName = "DuckDnsUpdater" }

try {
    Write-Host "`nCreating scheduled task '$taskName'..." -ForegroundColor Cyan
    
    # Create action
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument
    
    # Create trigger
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan @interval)
    
    # Create settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    # Register the task
    Register-ScheduledTask -Action $action `
                          -Trigger $trigger `
                          -Settings $settings `
                          -TaskName $taskName `
                          -Description "Update Duck DNS domains every $intervalDesc" `
                          -Force | Out-Null
    
    Write-Host "Task created successfully!" -ForegroundColor Green
    Write-Host "`nDetails:" -ForegroundColor Cyan
    Write-Host "  Name: $taskName"
    Write-Host "  Interval: $intervalDesc"
    Write-Host "  Script: $DuckDnsScript"
    Write-Host "`nYou can view the task in: Control Panel > Administrative Tools > Task Scheduler" -ForegroundColor Yellow
}
catch {
    Write-Host "ERROR: Could not create the scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
