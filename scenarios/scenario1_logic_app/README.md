# Scenario 1: Logic App Alerting

This scenario demonstrates how to monitor Azure Scheduled Events and send notifications to an Azure Logic App for human response workflows.

## Overview

When scheduled events are detected, this scenario:

1. Polls the Azure Instance Metadata Service (IMDS) for scheduled events
2. Creates a minimal JSON payload with event details
3. Sends an HTTP POST request to an Azure Logic App trigger
4. Continues monitoring until stopped

This approach is ideal for alerting scenarios where human intervention is required to coordinate maintenance windows or prepare for VM events.

## Files

- `linux_monitor.py` - Python implementation for Linux VMs
- `windows_monitor.ps1` - PowerShell implementation for Windows VMs  
- `config.json.example` - Example configuration file

## Setup

### Prerequisites

- Azure VM with access to Instance Metadata Service
- Azure Logic App with HTTP trigger configured
- Python 3.6+ (for Linux) or PowerShell 5.1+ (for Windows)

### Configuration

1. Copy the example configuration:

   ```bash
   cp config.json.example config.json
   ```

2. Edit `config.json` with your Logic App details:

   ```json
   {
     "logic_app_url": "https://your-logic-app.azurewebsites.net/api/your-http-trigger-url"
   }
   ```

### Azure Logic App Setup

1. Create a new Logic App in Azure
2. Add an HTTP trigger with method POST
3. Configure the trigger to accept any JSON payload
4. Add actions to process the notification (e.g., send email, Teams message, create ticket)
5. Copy the HTTP trigger URL to your configuration

## Usage

### Linux (Python)

Install dependencies:

```bash
pip install requests
```

Run the monitor:

```bash
# Continuous monitoring
python linux_monitor.py

# Custom polling interval
python linux_monitor.py --poll-interval 60

# Check once and exit
python linux_monitor.py --once

# Custom config file
python linux_monitor.py --config /path/to/config.json
```

### Windows (PowerShell)

Run the monitor:

```powershell
# Continuous monitoring
.\windows_monitor.ps1

# Custom polling interval
.\windows_monitor.ps1 -PollInterval 60

# Check once and exit  
.\windows_monitor.ps1 -Once

# Custom config file
.\windows_monitor.ps1 -ConfigPath "C:\path\to\config.json"
```

## Payload Format

The JSON payload sent to the Logic App includes:

```json
{
  "scenario": "Logic App Alerting",
  "timestamp": "1234567890",
  "eventCount": 1,
  "events": [
    {
      "eventId": "event-12345",
      "eventType": "Reboot",
      "eventStatus": "Scheduled", 
      "notBefore": "2024-01-01T12:00:00Z",
      "resources": ["vm1", "vm2"]
    }
  ],
  "alertType": "scheduled_event_detected",
  "severity": "medium",
  "description": "Detected 1 scheduled event(s) requiring attention",
  "actionRequired": "Review events and coordinate maintenance window"
}
```
