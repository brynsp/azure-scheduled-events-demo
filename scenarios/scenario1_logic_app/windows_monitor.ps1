<#
.SYNOPSIS
    Azure Scheduled Events Demo - Scenario 1: Logic App Alerting (PowerShell)

.DESCRIPTION
    This script monitors Azure Scheduled Events and sends notifications to an 
    Azure Logic App when events are detected. This scenario is designed for 
    human response workflows on Windows systems.

.PARAMETER ConfigPath
    Path to the JSON configuration file containing the Logic App URL.
    Default: "config.json"

.PARAMETER PollInterval
    Interval in seconds between polling for scheduled events.
    Default: 30

.PARAMETER Once
    Run the script once and exit instead of continuous monitoring.

.EXAMPLE
    .\windows_monitor.ps1
    Monitor for scheduled events using default settings.

.EXAMPLE
    .\windows_monitor.ps1 -ConfigPath "myconfig.json" -PollInterval 60
    Monitor with custom configuration file and 60-second polling interval.

.EXAMPLE
    .\windows_monitor.ps1 -Once
    Check for scheduled events once and exit.

.NOTES
    Requirements:
    - PowerShell 5.1 or later
    - Azure VM with Instance Metadata Service access
    - Configured Azure Logic App with HTTP trigger

.LINK
    https://docs.microsoft.com/en-us/azure/virtual-machines/windows/scheduled-events
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Path to the JSON configuration file")]
    [string]$ConfigPath = "config.json",
    
    [Parameter(HelpMessage = "Polling interval in seconds")]
    [ValidateRange(1, 3600)]
    [int]$PollInterval = 30,
    
    [Parameter(HelpMessage = "Run once and exit instead of continuous monitoring")]
    [switch]$Once
)

# Function to get scheduled events from IMDS
function Get-ScheduledEvents {
    $uri = "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"
    $headers = @{"Metadata" = "true" }
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -TimeoutSec 5
        return $response
    }
    catch {
        Write-Error "Error polling scheduled events: $($_.Exception.Message)"
        return $null
    }
}

# Function to acknowledge an event
function Confirm-ScheduledEvent {
    param([string]$EventId)
    
    $uri = "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"
    $headers = @{
        "Metadata"     = "true"
        "Content-Type" = "application/json"
    }
    $body = @{
        StartRequests = @(
            @{ EventId = $EventId }
        )
    } | ConvertTo-Json -Depth 3
    
    try {
        $null = Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -Body $body -TimeoutSec 5
        Write-Host "Successfully acknowledged event $EventId" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Error acknowledging event ${EventId}: $($_.Exception.Message)"
        return $false
    }
}

# Function to send notification to Logic App
function Send-LogicAppNotification {
    param(
        [string]$LogicAppUrl,
        [hashtable]$Payload
    )
    
    $headers = @{
        "Content-Type" = "application/json"
        "User-Agent"   = "AzureScheduledEvents-Demo/1.0"
    }
    
    try {
        Write-Host "Sending notification to Logic App… " -ForegroundColor Yellow
        Write-Host "POST $LogicAppUrl" -ForegroundColor Gray
        Write-Host "Payload: $(ConvertTo-Json $Payload -Depth 5)" -ForegroundColor Gray
        
        $response = Invoke-RestMethod -Uri $LogicAppUrl -Headers $headers -Method POST -Body (ConvertTo-Json $Payload -Depth 5) -TimeoutSec 10
        
        Write-Host "Successfully sent notification to Logic App" -ForegroundColor Green
        Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor Gray
        return $true
    }
    catch {
        Write-Error "Error sending to Logic App: $($_.Exception.Message)"
        return $false
    }
}

# Function to create minimal payload for Logic App
function New-LogicAppPayload {
    param([object]$EventsData)
    
    $eventSummaries = @()
    foreach ($scheduledEvent in $EventsData.Events) {
        $eventSummaries += @{
            eventId     = $scheduledEvent.EventId
            eventType   = $scheduledEvent.EventType
            eventStatus = $scheduledEvent.EventStatus
            notBefore   = $scheduledEvent.NotBefore
            resources   = $scheduledEvent.Resources
        }
    }
    
    return @{
        scenario       = "Logic App Alerting"
        timestamp      = $EventsData.DocumentIncarnation
        eventCount     = $EventsData.Events.Count
        events         = $eventSummaries
        alertType      = "scheduled_event_detected"
        severity       = "medium"
        description    = "Detected $($EventsData.Events.Count) scheduled event(s) requiring attention"
        actionRequired = "Review events and coordinate maintenance window"
    }
}

# Function to load configuration
function Get-Configuration {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Error "Configuration file not found: $Path"
        Write-Host "Please copy the .example file and configure it with your settings." -ForegroundColor Yellow
        return $null
    }
    
    try {
        $config = Get-Content $Path | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Error "Error parsing configuration file: $($_.Exception.Message)"
        return $null
    }
}

# Function to validate configuration
function Test-Configuration {
    param(
        [object]$Config,
        [string[]]$RequiredKeys
    )
    
    $missingKeys = @()
    foreach ($key in $RequiredKeys) {
        if (-not $Config.$key -or $Config.$key -eq "") {
            $missingKeys += $key
        }
    }
    
    if ($missingKeys.Count -gt 0) {
        Write-Error "Missing required configuration keys: $($missingKeys -join ', ')"
        return $false
    }
    
    return $true
}

# Main execution
function Main {
    Write-Host "=== Azure Scheduled Events Demo - Scenario 1: Logic App Alerting ===" -ForegroundColor Cyan
    Write-Host "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "Working directory: $(Get-Location)" -ForegroundColor Gray
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Load configuration
    $config = Get-Configuration -Path $ConfigPath
    if (-not $config) {
        exit 1
    }
    
    # Validate required configuration
    $requiredKeys = @("logic_app_url")
    if (-not (Test-Configuration -Config $config -RequiredKeys $requiredKeys)) {
        Write-Host "`nExample configuration:" -ForegroundColor Yellow
        Write-Host (@{
                logic_app_url = "https://your-logic-app.azurewebsites.net/api/your-trigger-url"
            } | ConvertTo-Json) -ForegroundColor Gray
        exit 1
    }
    
    Write-Host "Monitoring for scheduled events (polling every $PollInterval seconds)" -ForegroundColor Yellow
    Write-Host "Logic App URL: $($config.logic_app_url)" -ForegroundColor Gray
    Write-Host "Press Ctrl+C to stop monitoring`n" -ForegroundColor Yellow
    
    try {
        do {
            $eventsData = Get-ScheduledEvents
            
            if ($eventsData -and $eventsData.Events -and $eventsData.Events.Count -gt 0) {
                Write-Host "`n[$((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'))] Found $($eventsData.Events.Count) scheduled event(s):" -ForegroundColor Green
                
                foreach ($scheduledEvent in $eventsData.Events) {
                    Write-Host "  Event $($scheduledEvent.EventId): $($scheduledEvent.EventType) ($($scheduledEvent.EventStatus))" -ForegroundColor White
                    Write-Host "    Scheduled for: $($scheduledEvent.NotBefore)" -ForegroundColor Gray
                    Write-Host "    Affected resources: $($scheduledEvent.Resources -join ', ')" -ForegroundColor Gray
                }
                
                # Create payload and send to Logic App
                $payload = New-LogicAppPayload -EventsData $eventsData
                $success = Send-LogicAppNotification -LogicAppUrl $config.logic_app_url -Payload $payload
                
                if ($success) {
                    Write-Host "Logic App notification sent successfully" -ForegroundColor Green
                }
                else {
                    Write-Host "Failed to send Logic App notification" -ForegroundColor Red
                }
                
                if ($Once) {
                    break
                }
            }
            else {
                Write-Host "[$((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'))] No scheduled events detected" -ForegroundColor Gray
                
                if ($Once) {
                    Write-Host "No events found, exiting" -ForegroundColor Yellow
                    break
                }
            }
            
            if (-not $Once) {
                Start-Sleep -Seconds $PollInterval
            }
            
        } while (-not $Once)
    }
    catch [System.Exception] {
        Write-Error "Error in main loop: $($_.Exception.Message)"
        exit 1
    }
}

# Execute main function
Main