# Windows Setup Guide

This guide covers setup and deployment of Azure Scheduled Events monitoring on Windows systems.

## Prerequisites

### System Requirements

- Windows Server 2016+ or Windows 10+
- PowerShell 5.1 or later (PowerShell Core 6+ recommended)
- Network access to Azure Instance Metadata Service (169.254.169.254)
- Administrator privileges for service installation

### Supported Windows Versions

- Windows Server 2019/2022
- Windows Server 2016
- Windows 10/11 (for development/testing)

## Installation

### 1. Verify PowerShell Version

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# If less than 5.1, upgrade PowerShell
# Download from: https://github.com/PowerShell/PowerShell/releases
```

### 2. Download Demo Scripts

```powershell
# Clone or download the repository
git clone https://github.com/brynsp/azure-scheduled-events-demo.git
cd azure-scheduled-events-demo
```

### 3. Verify IMDS Connectivity

```powershell
# Test basic IMDS connectivity
try {
    $response = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01" -Headers @{"Metadata"="true"} -TimeoutSec 5
    Write-Host "IMDS connectivity: OK" -ForegroundColor Green
    $response | ConvertTo-Json
} catch {
    Write-Host "IMDS connectivity: FAILED - $($_.Exception.Message)" -ForegroundColor Red
}
```

## Configuration

### 1. Scenario-Specific Setup

Choose your scenario and configure accordingly:

#### Scenario 1: Logic App Alerting

```powershell
cd scenarios\scenario1_logic_app
copy config.json.example config.json
notepad config.json  # Edit with your Logic App URL
```

#### Scenario 2: ServiceNow Direct

```powershell
cd scenarios\scenario2_servicenow_direct
copy config.json.example config.json
notepad config.json  # Edit with your ServiceNow details
```

#### Scenario 3: Automated Handling

```powershell
cd scenarios\scenario3_automated_handling
copy config.json.example config.json
notepad config.json  # Edit automation and ServiceNow settings
```

### 2. Network Configuration

Ensure the VM can reach the IMDS endpoint:

```powershell
# Test connectivity
Test-NetConnection -ComputerName 169.254.169.254 -Port 80

# Check Windows Firewall (if blocking)
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*169.254.169.254*"}

# Create firewall rule if needed (run as Administrator)
New-NetFirewallRule -DisplayName "Allow IMDS" -Direction Outbound -Protocol TCP -RemoteAddress 169.254.169.254 -RemotePort 80 -Action Allow
```

### 3. Service Account Setup (Recommended)

For production deployments, create a dedicated service account:

```powershell
# Run as Administrator
# Create local service account
$password = ConvertTo-SecureString "ComplexPassword123!" -AsPlainText -Force
New-LocalUser -Name "AzureEventsService" -Password $password -Description "Azure Scheduled Events Service Account" -UserMayNotChangePassword -PasswordNeverExpires

# Grant "Log on as a service" right
# Use Local Security Policy (secpol.msc) or:
# Computer Configuration > Windows Settings > Security Settings > Local Policies > User Rights Assignment > Log on as a service

# Create working directory
New-Item -Path "C:\AzureEvents" -ItemType Directory -Force
$acl = Get-Acl "C:\AzureEvents"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("AzureEventsService","FullControl","Allow")
$acl.SetAccessRule($accessRule)
Set-Acl -Path "C:\AzureEvents" -AclObject $acl

# Copy scripts
Copy-Item -Path "scenarios" -Destination "C:\AzureEvents\" -Recurse -Force
```

## Running the Monitors

### Manual Execution

#### Test Mode (Dry Run)

```powershell
# Test Scenario 3 without making changes
cd scenarios\scenario3_automated_handling
.\windows_monitor.ps1 -DryRun -Once
```

#### Continuous Monitoring

```powershell
# Run with default settings
.\windows_monitor.ps1

# Custom polling interval
.\windows_monitor.ps1 -PollInterval 60

# Custom configuration file
.\windows_monitor.ps1 -ConfigPath "C:\path\to\config.json"
```

### Windows Service Setup

Create a Windows Service for automatic startup:

#### 1. Install NSSM (Non-Sucking Service Manager)

```powershell
# Download NSSM from https://nssm.cc/download
# Or use Chocolatey
choco install nssm

# Or use Scoop
scoop install nssm
```

#### 2. Create Service with NSSM

```powershell
# Run as Administrator
# Create service
nssm install "AzureScheduledEvents" "powershell.exe"

# Configure service parameters
nssm set "AzureScheduledEvents" Application "powershell.exe"
nssm set "AzureScheduledEvents" AppParameters "-ExecutionPolicy Bypass -File C:\AzureEvents\scenarios\scenario3_automated_handling\windows_monitor.ps1 -ConfigPath C:\AzureEvents\config.json"
nssm set "AzureScheduledEvents" AppDirectory "C:\AzureEvents\scenarios\scenario3_automated_handling"
nssm set "AzureScheduledEvents" DisplayName "Azure Scheduled Events Monitor"
nssm set "AzureScheduledEvents" Description "Monitors Azure Scheduled Events and executes automated responses"
nssm set "AzureScheduledEvents" Start SERVICE_AUTO_START

# Configure service account
nssm set "AzureScheduledEvents" ObjectName ".\AzureEventsService" "ComplexPassword123!"

# Configure logging
nssm set "AzureScheduledEvents" AppStdout "C:\AzureEvents\logs\stdout.log"
nssm set "AzureScheduledEvents" AppStderr "C:\AzureEvents\logs\stderr.log"

# Create logs directory
New-Item -Path "C:\AzureEvents\logs" -ItemType Directory -Force

# Start service
Start-Service "AzureScheduledEvents"

# Check status
Get-Service "AzureScheduledEvents"
```

### Scheduled Task Setup (Alternative)

For simpler deployments, use Task Scheduler:

```powershell
# Create scheduled task to run every 5 minutes
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\AzureEvents\scenarios\scenario1_logic_app\windows_monitor.ps1 -Once"
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
$principal = New-ScheduledTaskPrincipal -UserID "AzureEventsService" -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -RestartCount 3

Register-ScheduledTask -TaskName "AzureScheduledEventsCheck" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Check for Azure Scheduled Events"
```

## Monitoring and Logging

### Event Log Integration

Add Windows Event Log support to your scripts:

```powershell
# Add to your monitor script
# Create custom event source (run as Administrator once)
New-EventLog -LogName Application -Source "AzureScheduledEvents"

# Log events in script

# INFO
Write-EventLog -LogName Application -Source "AzureScheduledEvents" -EventId 1001 -EntryType Information -Message "Azure Scheduled Events monitoring started"

# WARN
Write-EventLog -LogName Application -Source "AzureScheduledEvents" -EventId 2001 -EntryType Warning -Message "Scheduled event detected: $($event.EventType)"

# ERROR
Write-EventLog -LogName Application -Source "AzureScheduledEvents" -EventId 3001 -EntryType Error -Message "Failed to process event: $($_.Exception.Message)"
```

### File-Based Logging

```powershell
# Add structured logging to your script
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console
    Write-Host $logEntry
    
    # Write to file
    Add-Content -Path "C:\AzureEvents\logs\monitor.log" -Value $logEntry
}

# Usage in script
Write-LogMessage "Starting Azure Scheduled Events monitoring" "INFO"
Write-LogMessage "Event detected: $($event.EventType)" "WARN"
Write-LogMessage "Error processing event: $($_.Exception.Message)" "ERROR"
```

### Debug Mode

Enable detailed debugging:

```powershell
# Add to top of monitor script
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

# Or use debug parameters
.\windows_monitor.ps1 -Verbose -Debug
```

### Production Deployment

```powershell
# 1. Deploy in dry-run mode first
.\windows_monitor.ps1 -DryRun -Once

# 2. Install and start service
# (Follow service setup steps above)

# 3. Verify operation
Get-Service "AzureScheduledEvents"
Get-EventLog -LogName Application -Source "AzureScheduledEvents" -Newest 5
```
