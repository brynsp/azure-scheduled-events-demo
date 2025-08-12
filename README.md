# Azure Scheduled Events Demo

A comprehensive demonstration of Azure Scheduled Events handling across three scenarios, supporting both Linux and Windows VMs.

## Overview

Azure Scheduled Events is a metadata service that provides advance notification about upcoming VM maintenance. This demo shows three implementation patterns:

1. Logic App Alerting - Human response via Azure Logic Apps
2. ServiceNow Direct Integration - ITSM integration for incident management  
3. Automated Handling - Full automation with early acknowledgment and documentation

## Project Structure

```text
├── scenarios/
│   ├── scenario1_logic_app/          # Logic App alerting scenario
│   │   ├── linux_monitor.py
│   │   ├── windows_monitor.ps1
│   │   ├── config.json.example
│   │   └── README.md
│   ├── scenario2_servicenow_direct/  # ServiceNow direct integration
│   │   ├── linux_monitor.py
│   │   ├── windows_monitor.ps1
│   │   ├── config.json.example
│   │   └── README.md
│   └── scenario3_automated_handling/ # Automated handling scenario
│       ├── linux_monitor.py
│       ├── windows_monitor.ps1
│       ├── drain_hooks.py
│       ├── config.json.example
│       └── README.md
├── common/
│   ├── imds_client.py                # Shared IMDS client library
│   └── utils.py                      # Common utility functions
├── docs/
│   ├── azure_scheduled_events_overview.md
│   ├── setup_linux.md
│   └── setup_windows.md
└── README.md
```

## Scenarios

### Scenario 1: Logic App Alerting

Use Case: Human response workflows via Azure Logic Apps

When events are detected:

1. Creates minimal JSON payload with event details
2. Posts to Azure Logic App HTTP trigger
3. Logic App handles notifications (email, Teams, etc.)

Value: Simple integration with existing Logic App workflows

### Scenario 2: ServiceNow Direct Integration  

Use Case: Direct ITSM integration for incident management

When events are detected:

1. Creates detailed ServiceNow incident
2. Includes event details and action items
3. Assigns to appropriate teams

Value: Direct integration with ITSM processes, no intermediate systems

### Scenario 3: Automated Handling + ServiceNow Record

Use Case: Maximum automation with documentation  

When events are detected:

1. Executes automated drain hooks (application shutdown, etc.)
2. Performs early acknowledgment to shorten maintenance window
3. Creates ServiceNow record documenting automation success

Value: Minimizes human intervention and service impact duration

## Quick Start

### Prerequisites

- Azure VM with Instance Metadata Service access
- Python 3.6+ (Linux) or Windows PowerShell 5.1+ (Windows)  
- Network connectivity to external services (Logic Apps, ServiceNow)

### 1. Choose Your Scenario

```bash
# Clone the repository
git clone https://github.com/<your_username>/azure-scheduled-events-demo.git
cd azure-scheduled-events-demo

# Navigate to your preferred scenario
cd scenarios/scenario1_logic_app
# or scenario2_servicenow_direct
# or scenario3_automated_handling
```

### 2. Configure

```bash
# Copy and edit configuration
cp config.json.example config.json
nano config.json  # Edit with your settings
```

### 3. Test Connection

```bash
# Verify IMDS connectivity
curl -H "Metadata: true" "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"

# Expected response when no events: {"DocumentIncarnation":1,"Events":[]}
```

### 4. Run Monitor

#### Linux

```bash
# Install dependencies
pip install requests

# Test run (safe)
python linux_monitor.py --once

# Continuous monitoring  
python linux_monitor.py
```

#### Windows

```powershell
# Test run (safe)
.\windows_monitor.ps1 -Once

# Continuous monitoring
.\windows_monitor.ps1
```

## Configuration Examples

### Scenario 1: Logic App

```json
{
  "logic_app_url": "https://your-logic-app.azurewebsites.net/api/your-trigger-url"
}
```

### Scenario 2: ServiceNow  

> This is an basic example connecting to ServiceNow. In a real-world use case do not store credentials in repositories. OAuth2 is a much more production ready implementation, but is outside the scope of this demo.
```json
{
  "servicenow": {
    "instance_url": "https://your-instance.service-now.com",
    "username": "your-username",
    "password": "your-password",
    "assignment_group": "Infrastructure Team"
  }
}
```

### Scenario 3: Automated Handling

```json
{
  "automation": {
    "dry_run": true
  },
  "servicenow": {
    "instance_url": "https://your-instance.service-now.com",
    "username": "automation-user", 
    "password": "automation-user-password"
  }
}
```

## Key Features

### Cross-Platform Support

- Python scripts for Linux VMs
- PowerShell scripts for Windows VMs
- Shared functionality via common libraries

### Safety Features

- Dry-run modes for safe testing
- Configuration validation with clear error messages
- Graceful error handling and recovery

### Production Ready Examples

- Comprehensive logging and monitoring
- Service/daemon deployment guides
- Security best practices documentation
- Health monitoring examples

### Extensible Design

- Modular architecture for easy customization
- Sample drain hooks that can be replaced
- Clear integration points for external systems

## Documentation

### Setup Guides

- [Linux Setup Guide](docs/setup_linux.md) - Complete Linux deployment walkthrough
- [Windows Setup Guide](docs/setup_windows.md) - Complete Windows deployment walkthrough  

### Reference Documentation

- [Azure Scheduled Events Overview](docs/azure_scheduled_events_overview.md) - Service overview and API reference

### Scenario Documentation

Each scenario includes detailed README with:

- Setup instructions
- Configuration options
- Usage examples
- Integration guides
- Troubleshooting tips

## Example Payloads

### Logic App Payload

```json
{
  "scenario": "Logic App Alerting",
  "eventCount": 1,
  "events": [{
    "eventId": "event-12345",
    "eventType": "Reboot", 
    "eventStatus": "Scheduled",
    "notBefore": "2024-01-01T12:00:00Z",
    "resources": ["vm1"]
  }],
  "alertType": "scheduled_event_detected",
  "severity": "medium",
  "actionRequired": "Review events and coordinate maintenance window"
}
```

### ServiceNow Incident

- Short Description: "Azure Scheduled Event(s) Detected - 1 event(s)"
- Category: Infrastructure / Maintenance
- Priority: Medium
- Description: Detailed event information with action items

### Automation Record  

- Category: Infrastructure / Automation
- State: Resolved
- Description: Documents automation actions taken and early ACK success

## Monitoring Output

All scenarios provide detailed status output:

```text
=== Azure Scheduled Events Demo - Scenario 3: Automated Handling ===
[2024-01-01T12:00:00] Found 1 scheduled event(s):
  Event event-12345: Reboot (Scheduled)
    Scheduled for: 2024-01-01T13:00:00Z
    Affected resources: vm1

=== Step 1: Executing Drain Hooks ===
  Executing reboot preparation hooks…
    - Applications gracefully stopped
    - Drain hooks completed successfully

=== Step 2: Early Acknowledgment ===  
Successfully acknowledged event event-12345
Impact window has been shortened via early acknowledgment!

=== Step 3: ServiceNow Documentation ===
ServiceNow automation record INC0010001 created

Automation completed successfully! Impact window shortened.
```

## Contributing

This repository demonstrates Azure Scheduled Events handling patterns. To extend or customize:

1. Fork the repository for your modifications
2. Replace stub implementations with your actual logic
3. Test thoroughly in development environments
4. Document your changes for team members

## Security Considerations

- Configuration files contain credentials - secure appropriately
- Service accounts should have minimal required permissions  
- External integrations should use secure authentication methods

## Support & Reuse Expectations

This repository demonstrates Azure Scheduled Events integration patterns and is intended for educational and reference purposes. The included implementations are demonstration stubs that should be customized for production use.

For production deployments:

- Replace stub drain hooks with actual application logic
- Implement proper error handling and recovery
- Add comprehensive logging and monitoring
- Follow security best practices for your environment (e.g., don't use basic auth!)
