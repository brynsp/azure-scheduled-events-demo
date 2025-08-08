<#
.SYNOPSIS
    Monitors Azure Scheduled Events and creates incidents directly in ServiceNow.

.DESCRIPTION
    This script monitors Azure Scheduled Events and creates incidents directly 
    in ServiceNow when events are detected. This scenario demonstrates direct 
    ITSM integration for human response workflows on Windows systems.

.PARAMETER ConfigPath
    Path to the JSON configuration file containing ServiceNow settings.
    Default: "config.json"

.PARAMETER PollInterval
    Interval in seconds between polling for scheduled events.
    Default: 30 seconds

.PARAMETER Once
    Run once and exit instead of continuous monitoring.

.EXAMPLE
    .\windows_monitor.ps1
    Runs with default settings, monitoring every 30 seconds using config.json

.EXAMPLE
    .\windows_monitor.ps1 -ConfigPath "prod-config.json" -PollInterval 60
    Uses custom config file and polls every 60 seconds

.EXAMPLE
    .\windows_monitor.ps1 -Once
    Runs once and exits after checking for events

.NOTES
    Requirements:
    - Azure VM with Instance Metadata Service access
    - ServiceNow instance with Table API access
    - ServiceNow credentials (Basic Auth or OAuth2)

.LINK
    https://docs.microsoft.com/en-us/azure/virtual-machines/windows/scheduled-events
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = "config.json",
    [int]$PollInterval = 30,
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

# Function to create ServiceNow incident
function New-ServiceNowIncident {
    param(
        [object]$SnowConfig,
        [object]$EventsData
    )
    
    # ServiceNow Table API endpoint for incidents
    $url = "$($SnowConfig.instance_url)/api/now/table/incident"
    
    # Create incident payload
    $events = $EventsData.Events
    $eventDetails = @()
    
    foreach ($scheduledEvent in $events) {
        $eventDetails += "Event ID: $($scheduledEvent.EventId)"
        $eventDetails += "Type: $($scheduledEvent.EventType)"
        $eventDetails += "Status: $($scheduledEvent.EventStatus)"
        $eventDetails += "Scheduled: $($scheduledEvent.NotBefore)"
        $eventDetails += "Resources: $($scheduledEvent.Resources -join ', ')"
        $eventDetails += ""
    }
    
    $shortDescription = "Azure Scheduled Event(s) Detected - $($events.Count) event(s)"
    $description = @"
Azure Scheduled Events detected requiring attention.

Event Count: $($events.Count)
Detection Time: $((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'))

Event Details:
$($eventDetails -join "`n")

Action Required:
- Review scheduled maintenance events
- Coordinate with infrastructure teams  
- Plan for service impact during maintenance window
- Communicate to stakeholders as needed

This incident was automatically created by the Azure Scheduled Events monitoring system.
"@
    
    $payload = @{
        short_description = $shortDescription
        description       = $description
        category          = "Infrastructure"
        subcategory       = "Maintenance"
        urgency           = "3"  # Medium urgency
        impact            = "3"   # Medium impact
        priority          = "3" # Medium priority
    }
    
    # Add optional fields if present
    if ($SnowConfig.assignment_group) { $payload.assignment_group = $SnowConfig.assignment_group }
    if ($SnowConfig.caller_id) { $payload.caller_id = $SnowConfig.caller_id }
    if ($SnowConfig.vm_identifier) { $payload.u_azure_vm = $SnowConfig.vm_identifier }
    $payload.u_event_count = $events.Count.ToString()
    
    # Prepare authentication headers
    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
        "User-Agent"   = "AzureScheduledEvents-Demo/1.0"
    }
    
    # Basic Authentication (demo approach)
    if ($SnowConfig.auth_type -eq "basic" -or -not $SnowConfig.auth_type) {
        $credentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($SnowConfig.username):$($SnowConfig.password)"))
        $headers["Authorization"] = "Basic $credentials"
    }
    
    # TODO: OAuth2 Client Credentials implementation
    # For production use, implement OAuth2 client credentials flow:
    # 1. Register application in ServiceNow
    # 2. Get client_id and client_secret  
    # 3. Request access token from /oauth_token.do endpoint
    # 4. Use Bearer token in Authorization header
    # Example:
    # elseif ($SnowConfig.auth_type -eq "oauth2") {
    #     $token = Get-OAuth2Token -Config $SnowConfig
    #     $headers["Authorization"] = "Bearer $token"
    # }
    
    try {
        Write-Host "Creating ServiceNow incident…" -ForegroundColor Yellow
        Write-Host "POST $url" -ForegroundColor Gray
        Write-Host "Payload: $(ConvertTo-Json $payload -Depth 3)" -ForegroundColor Gray
        
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method POST -Body (ConvertTo-Json $payload -Depth 3) -TimeoutSec 30
        
        $incidentNumber = $response.result.number
        $incidentSysId = $response.result.sys_id
        
        Write-Host "  Successfully created ServiceNow incident: $incidentNumber" -ForegroundColor Green
        Write-Host "  Incident sys_id: $incidentSysId" -ForegroundColor Gray
        Write-Host "  URL: $($SnowConfig.instance_url)/nav_to.do?uri=incident.do?sys_id=$incidentSysId" -ForegroundColor Gray
        
        return $true
    }
    catch {
        Write-Error "  Error creating ServiceNow incident: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-Host "  Response status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
            if ($_.ErrorDetails) {
                Write-Host "  Response body: $($_.ErrorDetails.Message)" -ForegroundColor Red
            }
        }
        return $false
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
        $value = $Config
        foreach ($part in $key.Split('.')) {
            if ($value -and $value.$part) {
                $value = $value.$part
            }
            else {
                $value = $null
                break
            }
        }
        if (-not $value) {
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
    Write-Host "=== Azure Scheduled Events Demo - Scenario 2: ServiceNow Direct Alerting ===" -ForegroundColor Cyan
    Write-Host "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "Working directory: $(Get-Location)" -ForegroundColor Gray
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Load configuration
    $config = Get-Configuration -Path $ConfigPath
    if (-not $config) {
        exit 1
    }
    
    # Validate required configuration
    $requiredKeys = @("servicenow.instance_url", "servicenow.username", "servicenow.password")
    if (-not (Test-Configuration -Config $config -RequiredKeys $requiredKeys)) {
        Write-Host "`nExample ServiceNow configuration:" -ForegroundColor Yellow
        Write-Host (@{
                servicenow = @{
                    instance_url     = "https://your-instance.service-now.com"
                    username         = "your-username"
                    password         = "your-password"
                    auth_type        = "basic"
                    assignment_group = "Infrastructure Team"
                    caller_id        = "system.admin"
                    vm_identifier    = "your-vm-name"
                }
            } | ConvertTo-Json -Depth 3) -ForegroundColor Gray
        exit 1
    }
    
    Write-Host "Monitoring for scheduled events (polling every $PollInterval seconds)" -ForegroundColor Yellow
    Write-Host "ServiceNow instance: $($config.servicenow.instance_url)" -ForegroundColor Gray
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
                
                # Create ServiceNow incident
                $success = New-ServiceNowIncident -SnowConfig $config.servicenow -EventsData $eventsData
                
                if ($success) {
                    Write-Host "ServiceNow incident created successfully" -ForegroundColor Green
                }
                else {
                    Write-Host "Failed to create ServiceNow incident" -ForegroundColor Red
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