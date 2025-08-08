<#
.SYNOPSIS
    Azure Scheduled Events Demo - Scenario 3: Automated Handling + ServiceNow Record (PowerShell)

.DESCRIPTION
    This script monitors Azure Scheduled Events, executes automated drain hooks,
    performs early acknowledgment to shorten impact windows, and creates ServiceNow
    records documenting the automation taken.

.PARAMETER ConfigPath
    Path to the configuration JSON file containing ServiceNow and automation settings.
    Default: "config.json"

.PARAMETER PollInterval
    Interval in seconds between scheduled event polls.
    Default: 30

.PARAMETER Once
    Run the check once and exit instead of continuous monitoring.

.PARAMETER DryRun
    Run in dry-run mode where no actual changes are made, only simulated.

.EXAMPLE
    .\windows_monitor.ps1
    
    Runs with default settings, monitoring every 30 seconds using config.json

.EXAMPLE
    .\windows_monitor.ps1 -ConfigPath "prod-config.json" -PollInterval 60
    
    Uses custom config file and polls every 60 seconds

.EXAMPLE
    .\windows_monitor.ps1 -Once -DryRun
    
    Runs once in dry-run mode for testing

.NOTES
    Requirements:
    - PowerShell 5.1 or later
    - Azure VM with Instance Metadata Service access
    - ServiceNow instance with Table API access (optional)
    - Appropriate permissions for drain operations

.LINK
    https://docs.microsoft.com/en-us/azure/virtual-machines/windows/scheduled-events
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Path to the configuration JSON file")]
    [string]$ConfigPath = "config.json",
    
    [Parameter(HelpMessage = "Interval in seconds between scheduled event polls")]
    [ValidateRange(1, 3600)]
    [int]$PollInterval = 30,
    
    [Parameter(HelpMessage = "Run the check once and exit instead of continuous monitoring")]
    [switch]$Once,
    
    [Parameter(HelpMessage = "Run in dry-run mode where no actual changes are made")]
    [switch]$DryRun
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

# Function to acknowledge an event (early ACK)
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
        Write-Host "  Successfully acknowledged event $EventId" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "  Error acknowledging event ${EventId}: $($_.Exception.Message)"
        return $false
    }
}

# Function to execute drain hooks based on event type
function Invoke-DrainHooks {
    param(
        [object]$ScheduledEvent,
        [bool]$DryRunMode = $false
    )
    
    $eventType = $ScheduledEvent.EventType.ToLower()
    $eventId = $ScheduledEvent.EventId
    
    Write-Host "  Executing drain hooks for event type: $eventType" -ForegroundColor Yellow
    
    $results = @()
    
    try {
        # Execute specific hooks based on event type
        switch ($eventType) {
            "reboot" {
                $result = Invoke-RebootPreparation -DryRun $DryRunMode
                $results += $result
            }
            "redeploy" {
                $result = Invoke-RedeployPreparation -DryRun $DryRunMode
                $results += $result
            }
            "preempt" {
                $result = Invoke-PreemptPreparation -DryRun $DryRunMode
                $results += $result
            }
            default {
                $result = Invoke-GenericPreparation -DryRun $DryRunMode
                $results += $result
            }
        }
        
        # Always run generic preparation steps
        $genericResult = Invoke-GenericPreparationSteps -DryRun $DryRunMode
        $results += $genericResult
        
        Write-Host "    Drain hooks completed successfully for event $eventId" -ForegroundColor Green
        return @{ Success = $true; Results = $results }
    }
    catch {
        Write-Error "    Drain hooks failed for event ${eventId}: $($_.Exception.Message)"
        $results += "  Drain hooks failed: $($_.Exception.Message)"
        return @{ Success = $false; Results = $results }
    }
}

# Function to prepare for reboot events
function Invoke-RebootPreparation {
    param([bool]$DryRun = $false)
    
    Write-Host "    Executing reboot preparation hooks…" -ForegroundColor Cyan
    
    if ($DryRun) {
        return "  [DRY RUN] Reboot preparation completed"
    }
    
    # Example reboot preparations:
    # 1. Gracefully stop applications
    # 2. Flush application caches  
    # 3. Sync databases
    # 4. Notify load balancers to drain traffic
    
    # Stub implementations:
    Start-Sleep -Seconds 1  # Simulate application shutdown
    Write-Host "      - Applications gracefully stopped" -ForegroundColor Gray
    
    Start-Sleep -Milliseconds 500  # Simulate cache flush
    Write-Host "      - Caches flushed" -ForegroundColor Gray
    
    Start-Sleep -Milliseconds 500  # Simulate database sync
    Write-Host "      - Database synchronized" -ForegroundColor Gray
    
    return "  Reboot preparation completed successfully"
}

# Function to prepare for redeploy events
function Invoke-RedeployPreparation {
    param([bool]$DryRun = $false)
    
    Write-Host "    Executing redeploy preparation hooks…" -ForegroundColor Cyan
    
    if ($DryRun) {
        return "  [DRY RUN] Redeploy preparation completed"
    }
    
    # Example redeploy preparations:
    # 1. Backup critical data
    # 2. Export application state
    # 3. Notify monitoring systems
    # 4. Prepare for potential data loss
    
    # Stub implementations:
    Start-Sleep -Seconds 1  # Simulate backup
    Write-Host "      - Critical data backed up" -ForegroundColor Gray
    
    Start-Sleep -Milliseconds 500  # Simulate state export
    Write-Host "      - Application state exported" -ForegroundColor Gray
    
    Start-Sleep -Milliseconds 500  # Simulate monitoring notification
    Write-Host "      - Monitoring systems notified" -ForegroundColor Gray
    
    return "  Redeploy preparation completed successfully"
}

# Function to prepare for preemption events
function Invoke-PreemptPreparation {
    param([bool]$DryRun = $false)
    
    Write-Host "    Executing preemption preparation hooks…" -ForegroundColor Cyan
    
    if ($DryRun) {
        return "  [DRY RUN] Preemption preparation completed"
    }
    
    # Example preemption preparations:
    # 1. Save work in progress
    # 2. Move workload to other instances
    # 3. Update job queues
    # 4. Quick cleanup
    
    # Stub implementations:
    Start-Sleep -Milliseconds 500  # Simulate work save
    Write-Host "      - Work in progress saved" -ForegroundColor Gray
    
    Start-Sleep -Seconds 1  # Simulate workload migration
    Write-Host "      - Workload migrated to other instances" -ForegroundColor Gray
    
    Start-Sleep -Milliseconds 500  # Simulate queue update
    Write-Host "      - Job queues updated" -ForegroundColor Gray
    
    return "  Preemption preparation completed successfully"
}

# Function to prepare for generic events
function Invoke-GenericPreparation {
    param([bool]$DryRun = $false)
    
    Write-Host "    Executing generic event preparation hooks…" -ForegroundColor Cyan
    
    if ($DryRun) {
        return "  [DRY RUN] Generic preparation completed"
    }
    
    # Generic preparations for unknown events:
    # 1. Save current state
    # 2. Basic application shutdown
    # 3. Log event for analysis
    
    # Stub implementations:
    Start-Sleep -Milliseconds 500  # Simulate state save
    Write-Host "      - Current state saved" -ForegroundColor Gray
    
    Start-Sleep -Milliseconds 500  # Simulate graceful shutdown
    Write-Host "      - Basic application shutdown" -ForegroundColor Gray
    
    return "  Generic preparation completed successfully"
}

# Function for generic preparation steps
function Invoke-GenericPreparationSteps {
    param([bool]$DryRun = $false)
    
    Write-Host "    Executing generic preparation steps…" -ForegroundColor Cyan
    
    if ($DryRun) {
        return "  [DRY RUN] Generic steps completed"
    }
    
    # Common preparation steps:
    # 1. Log the event
    # 2. Notify monitoring
    # 3. Update health checks
    
    # Stub implementations:
    Start-Sleep -Milliseconds 300  # Simulate logging
    Write-Host "      - Event logged" -ForegroundColor Gray
    
    Start-Sleep -Milliseconds 300  # Simulate monitoring notification
    Write-Host "      - Monitoring systems updated" -ForegroundColor Gray
    
    Start-Sleep -Milliseconds 300  # Simulate health check update
    Write-Host "      - Health checks updated" -ForegroundColor Gray
    
    return "  Generic preparation steps completed"
}

# Function to create ServiceNow automation record
function New-ServiceNowAutomationRecord {
    param(
        [object]$SnowConfig,
        [object]$EventsData,
        [object]$AutomationResults
    )
    
    # Use incidents table, but mark as informational/resolved
    $url = "$($SnowConfig.instance_url)/api/now/table/incident"
    
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
    
    # Format automation results
    $automationSummary = @()
    foreach ($result in $AutomationResults.drain_results) {
        $automationSummary += "- $result"
    }
    
    $shortDescription = "Azure Scheduled Event(s) Automated - $($events.Count) event(s)"
    $description = @"
Azure Scheduled Events automatically handled by automation system.

Event Count: $($events.Count)
Automation Time: $((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'))
Early ACK Status: $(if ($AutomationResults.early_ack_success) { '  Success' } else { '  Failed' })

Event Details:
$($eventDetails -join "`n")

Automation Actions Taken:
$($automationSummary -join "`n")

Impact Window: $(if ($AutomationResults.early_ack_success) { 'Shortened via early acknowledgment' } else { 'Standard maintenance window' })

This record was automatically created to document successful automation handling of Azure Scheduled Events. No manual intervention was required.
"@
    
    $payload = @{
        short_description    = $shortDescription
        description          = $description
        category             = "Infrastructure"
        subcategory          = "Automation"
        urgency              = "4"  # Low urgency - automated handling
        impact               = "4"   # Low impact - automation succeeded
        priority             = "4" # Low priority - informational
        state                = "6"    # Resolved state
        close_code           = "Solved (Permanently)"
        close_notes          = "Azure Scheduled Events handled automatically. No issues detected."
        u_event_count        = $events.Count.ToString()
        u_automation_success = "true"
    }
    
    # Add optional fields if present
    if ($SnowConfig.assignment_group) { $payload.assignment_group = $SnowConfig.assignment_group }
    if ($SnowConfig.caller_id) { $payload.caller_id = $SnowConfig.caller_id }
    if ($SnowConfig.vm_identifier) { $payload.u_azure_vm = $SnowConfig.vm_identifier }
    
    # Prepare authentication headers
    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
        "User-Agent"   = "AzureScheduledEvents-Demo/1.0"
    }
    
    # Basic Authentication
    if ($SnowConfig.auth_type -eq "basic" -or -not $SnowConfig.auth_type) {
        $credentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($SnowConfig.username):$($SnowConfig.password)"))
        $headers["Authorization"] = "Basic $credentials"
    }
    
    try {
        Write-Host "Creating ServiceNow automation record…" -ForegroundColor Yellow
        Write-Host "POST $url" -ForegroundColor Gray
        
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method POST -Body (ConvertTo-Json $payload -Depth 3) -TimeoutSec 30
        
        $recordNumber = $response.result.number
        $recordSysId = $response.result.sys_id
        
        Write-Host "  Successfully created ServiceNow automation record: $recordNumber" -ForegroundColor Green
        Write-Host "  Record sys_id: $recordSysId" -ForegroundColor Gray
        Write-Host "  URL: $($SnowConfig.instance_url)/nav_to.do?uri=incident.do?sys_id=$recordSysId" -ForegroundColor Gray
        
        return $true
    }
    catch {
        Write-Error "  Error creating ServiceNow automation record: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-Host "  Response status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
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

# Main execution function
function Main {
    Write-Host "=== Azure Scheduled Events Demo - Scenario 3: Automated Handling + ServiceNow Record ===" -ForegroundColor Cyan
    Write-Host "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "Working directory: $(Get-Location)" -ForegroundColor Gray
    if ($DryRun) {
        Write-Host " Running in DRY-RUN mode - no actual changes will be made" -ForegroundColor Yellow
    }
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Load configuration
    $config = Get-Configuration -Path $ConfigPath
    if (-not $config) {
        exit 1
    }
    
    # Override dry-run setting if specified
    if ($DryRun) {
        if (-not $config.automation) {
            $config | Add-Member -NotePropertyName "automation" -NotePropertyValue @{}
        }
        $config.automation | Add-Member -NotePropertyName "dry_run" -NotePropertyValue $true -Force
    }
    
    Write-Host "Monitoring for scheduled events (polling every $PollInterval seconds)" -ForegroundColor Yellow
    if ($config.servicenow) {
        Write-Host "ServiceNow instance: $($config.servicenow.instance_url)" -ForegroundColor Gray
    }
    if ($DryRun) {
        Write-Host "Mode: DRY-RUN (no actual changes will be made)" -ForegroundColor Yellow
    }
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
                
                # Initialize automation results
                $automationResults = @{
                    drain_results             = @()
                    early_ack_success         = $false
                    servicenow_record_success = $false
                }
                
                # Step 1: Execute drain hooks
                Write-Host "`n=== Step 1: Executing Drain Hooks ===" -ForegroundColor Magenta
                $overallDrainSuccess = $true
                
                foreach ($scheduledEvent in $eventsData.Events) {
                    Write-Host "`nProcessing event $($scheduledEvent.EventId) ($($scheduledEvent.EventType))…" -ForegroundColor Yellow
                    
                    $hookResult = Invoke-DrainHooks -ScheduledEvent $scheduledEvent -DryRunMode $DryRun
                    $automationResults.drain_results += $hookResult.Results
                    
                    if (-not $hookResult.Success) {
                        $overallDrainSuccess = $false
                    }
                }
                
                # Step 2: Early acknowledge events if drain was successful
                Write-Host "`n=== Step 2: Early Acknowledgment ===" -ForegroundColor Magenta
                if ($overallDrainSuccess -and -not $DryRun) {
                    Write-Host "Drain hooks successful - proceeding with early acknowledgment…" -ForegroundColor Yellow
                    
                    $ackSuccessCount = 0
                    foreach ($scheduledEvent in $eventsData.Events) {
                        if (Confirm-ScheduledEvent -EventId $scheduledEvent.EventId) {
                            $ackSuccessCount++
                        }
                        Start-Sleep -Seconds 1  # Brief delay between ACKs
                    }
                    
                    if ($ackSuccessCount -eq $eventsData.Events.Count) {
                        $automationResults.early_ack_success = $true
                        Write-Host "  Successfully acknowledged all $($eventsData.Events.Count) event(s)" -ForegroundColor Green
                        Write-Host "Impact window has been shortened via early acknowledgment!" -ForegroundColor Green
                    }
                    else {
                        Write-Host "  Only acknowledged $ackSuccessCount/$($eventsData.Events.Count) event(s)" -ForegroundColor Red
                    }
                }
                elseif ($DryRun) {
                    Write-Host "  [DRY RUN] Early acknowledgment would be performed" -ForegroundColor Yellow
                    $automationResults.early_ack_success = $true
                }
                else {
                    Write-Host "  Skipping early acknowledgment due to drain hook failures" -ForegroundColor Red
                    $automationResults.drain_results += "  Early acknowledgment skipped due to drain failures"
                }
                
                # Step 3: Create ServiceNow automation record
                Write-Host "`n=== Step 3: ServiceNow Documentation ===" -ForegroundColor Magenta
                if ($config.servicenow -and -not $DryRun) {
                    $recordSuccess = New-ServiceNowAutomationRecord -SnowConfig $config.servicenow -EventsData $eventsData -AutomationResults $automationResults
                    $automationResults.servicenow_record_success = $recordSuccess
                    
                    if ($recordSuccess) {
                        Write-Host "  ServiceNow automation record created successfully" -ForegroundColor Green
                    }
                    else {
                        Write-Host "  Failed to create ServiceNow automation record" -ForegroundColor Red
                    }
                }
                elseif ($DryRun) {
                    Write-Host "  [DRY RUN] ServiceNow automation record would be created" -ForegroundColor Yellow
                }
                else {
                    Write-Host "ServiceNow configuration not found - skipping record creation" -ForegroundColor Yellow
                }
                
                # Summary
                Write-Host "`n=== Automation Summary ===" -ForegroundColor Magenta
                Write-Host "Events processed: $($eventsData.Events.Count)" -ForegroundColor White
                Write-Host "Drain hooks: $(if ($overallDrainSuccess) { '  Success' } else { '  Failed' })" -ForegroundColor $(if ($overallDrainSuccess) { 'Green' } else { 'Red' })
                Write-Host "Early acknowledgment: $(if ($automationResults.early_ack_success) { '  Success' } else { '  Failed' })" -ForegroundColor $(if ($automationResults.early_ack_success) { 'Green' } else { 'Red' })
                Write-Host "ServiceNow record: $(if ($automationResults.servicenow_record_success -or $DryRun) { '  Success' } else { '  Failed/Skipped' })" -ForegroundColor $(if ($automationResults.servicenow_record_success -or $DryRun) { 'Green' } else { 'Red' })
                
                if ($automationResults.early_ack_success) {
                    Write-Host "`n Automation completed successfully! Impact window shortened." -ForegroundColor Green
                }
                else {
                    Write-Host "`n  Automation partially completed. Manual review may be required." -ForegroundColor Yellow
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