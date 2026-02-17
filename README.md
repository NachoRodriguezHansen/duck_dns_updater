# Duck DNS Updater

PowerShell script to automatically update the public IP of your domains on [Duck DNS](https://www.duckdns.org/).

## Features

- ✅ Automatic IP updates on Duck DNS
- ✅ Response validation from Duck DNS
- ✅ Detailed timestamped logging
- ✅ Multiple configuration methods (parameters, environment variables, config.json)
- ✅ Robust error handling
- ✅ Compatible with PowerShell 2.0+
- ✅ Colored console output for readability

## Requirements

- PowerShell 2.0 or later
- A Duck DNS account (https://www.duckdns.org/)
- Duck DNS API token
- Internet access

## Installation

1. Download `update_duck_dns.ps1`
2. Place it in a convenient folder (e.g. `C:\Tools\duck_dns_updater\`)
3. (Optional) Create a `config.json` file in the same folder

## Quickstart

Follow these quick steps to get running in under a minute.

1. Get your Duck DNS token at https://www.duckdns.org/ (dashboard).

2. Quick manual run (test):

```powershell
.\update_duck_dns.ps1 -Domains "your-subdomain" -Token "your-token-here"
```

3. Or set environment variables (safer for automation):

```powershell
[Environment]::SetEnvironmentVariable("DUCKDNS_DOMAINS", "your-subdomain", "User")
[Environment]::SetEnvironmentVariable("DUCKDNS_TOKEN", "your-token-here", "User")

.\update_duck_dns.ps1
```

4. For a persistent config, copy and edit the example:

```powershell
Copy-Item config.json.example config.json
# Edit config.json with your domains and token
.\update_duck_dns.ps1
```

5. To run regularly on Windows use the helper:

```powershell
.\setup_scheduled_task.ps1
```

## Usage

There are three ways to configure the script. Priority order: parameters > environment variables > config file.

### 1. Direct parameters (recommended for manual runs)

```powershell
.\update_duck_dns.ps1 -Domains "subdomain1,subdomain2" -Token "your-token-here"
```

With a specific IP:

```powershell
.\update_duck_dns.ps1 -Domains "subdomain" -Token "your-token-here" -IP "xxx.xxx.xxx.xxx"
```

### 2. Environment variables (recommended for automation)

```powershell
$env:DUCKDNS_DOMAINS = "subdomain1,subdomain2"
$env:DUCKDNS_TOKEN = "your-token-here"
$env:DUCKDNS_IP = "203.0.113.42"  # optional

.\update_duck_dns.ps1
```

To set variables persistently for the current user:

```powershell
[Environment]::SetEnvironmentVariable("DUCKDNS_DOMAINS", "your-subdomain", "User")
[Environment]::SetEnvironmentVariable("DUCKDNS_TOKEN", "your-token", "User")
```

### 3. Config file (recommended for managed setups)

Create a `config.json` file in the same folder as the script:

```json
{
  "domains": "subdomain1,subdomain2",
  "token": "your-token-here",
  "ip": ""
}
```

Then run:

```powershell
.\update_duck_dns.ps1
```

Or specify a custom config path:

```powershell
.\update_duck_dns.ps1 -ConfigPath "C:\path\to\config.json"
```

## Scheduled Task

### Option 1: Using parameters

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\Tools\duck_dns_updater\update_duck_dns.ps1`" -Domains `"subdomain`" -Token `"your-token`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)

Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "DuckDnsUpdater" -Description "Update Duck DNS every 5 minutes"
```

### Option 2: Using environment variables

First, configure the environment variables for the user.

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\Tools\duck_dns_updater\update_duck_dns.ps1`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)

Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "DuckDnsUpdater" -Description "Update Duck DNS every 5 minutes"
```

## Logs

Results are stored in `output.txt` in the same folder as the script.

Example log:

```
[2025.02.17 14:30:15] [Info] Duck DNS Updater started
[2025.02.17 14:30:15] [Info] Sending update request for domain(s): subdomain
[2025.02.17 14:30:16] [Success] SUCCESS: Duck DNS updated. Response: OK
[2025.02.17 14:30:16] [Success] Duck DNS Updater completed successfully
```

## Troubleshooting

### Error: "Domains not provided"
- ✅ Provide `-Domains` as a parameter
- ✅ Or set the `DUCKDNS_DOMAINS` environment variable
- ✅ Or create a `config.json` with the `domains` field

### Error: "Token not provided"
- ✅ Provide `-Token` as a parameter
- ✅ Or set the `DUCKDNS_TOKEN` environment variable
- ✅ Or create a `config.json` with the `token` field

### "Access Denied" when running the script
- Run PowerShell as Administrator
- Or run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### The script does not run as a scheduled task
- Use the full path to the script
- Add `ExecutionPolicy Bypass` to the scheduled action
- Use a user account with sufficient permissions
- Check `output.txt` for the exact error

## Security

⚠️ **Important**: Do not store your token in plain files that may be committed.

**Best practices:**

1. **Use environment variables** (safer than storing tokens in files)
2. **Protect `config.json`** with restrictive permissions
3. **Do not commit tokens** to Git (use `.gitignore`)
4. **Rotate your token** periodically on Duck DNS

## Support and Contributions

For issues or suggestions, check `output.txt` for diagnostics.

## License

Free to use and modify.
