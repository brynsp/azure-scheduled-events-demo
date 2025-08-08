# Scenario 2: ServiceNow Direct Alerting

This scenario demonstrates how to monitor Azure Scheduled Events and create incidents directly in ServiceNow for ITSM integration and human response workflows.

## Overview

When scheduled events are detected, this scenario:

1. Polls the Azure Instance Metadata Service (IMDS) for scheduled events
2. Creates a detailed incident in ServiceNow with event information
3. Includes all relevant event details and action items
4. Continues monitoring until stopped

This approach is ideal for organizations using ServiceNow as their primary ITSM platform and wanting direct integration without intermediate systems.

## Files

- `linux_monitor.py` - Python implementation for Linux VMs
- `windows_monitor.ps1` - PowerShell implementation for Windows VMs  
- `config.json.example` - Example configuration file
- `README.md` - This documentation

## Setup

### Prerequisites

- Azure VM with access to Instance Metadata Service
- ServiceNow instance with Table API access
- ServiceNow user account with incident creation permissions
- Python 3.6+ (for Linux) or PowerShell 5.1+ (for Windows)

### Configuration

1. Copy the example configuration:

   ```bash
   cp config.json.example config.json
   ```

2. Edit `config.json` with your ServiceNow details:

   ```json
   {
     "servicenow": {
       "instance_url": "https://your-instance.service-now.com",
       "username": "your-username",
       "password": "your-password",
       "auth_type": "basic",
       "assignment_group": "Infrastructure Team",
       "caller_id": "system.admin",
       "vm_identifier": "your-vm-name"
     }
   }
   ```

### ServiceNow Setup

1. **User Account**: Create or use a service account with the following permissions:
   - `incident_manager` role or equivalent
   - Read/Write access to the incident table
   - API access permissions

2. **Optional Custom Fields** (enhance incident tracking):
   - `u_azure_vm` - String field for VM identifier
   - `u_event_count` - Integer field for number of events

3. **Assignment Group**: Ensure the specified assignment group exists

4. **Authentication Options**:
   - **Basic Auth** (demo): Uses username/password (shown in examples)
   - **OAuth2** (production): Recommended for production deployments

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

## Incident Fields

The created ServiceNow incidents include:

| Field | Value | Description |
|-------|--------|-------------|
| Short Description | "Azure Scheduled Event(s) Detected - X event(s)" | Summary |
| Description | Detailed event information | Full event details and action items |
| Category | Infrastructure | Incident category |
| Subcategory | Maintenance | Incident subcategory |
| Urgency | 3 (Medium) | Impact urgency |
| Impact | 3 (Medium) | Business impact |
| Priority | 3 (Medium) | Overall priority |
| Assignment Group | Configurable | Team to handle incident |
| Caller ID | Configurable | Reporting user |
| u_azure_vm | Configurable | VM identifier (custom field) |
| u_event_count | Automatic | Number of events (custom field) |

## Authentication Methods

### Basic Authentication (Demo)

```json
{
  "auth_type": "basic",
  "username": "your-username", 
  "password": "your-password"
}
```

### OAuth2 Client Credentials (Production)

For production deployments, implement OAuth2:

1. **Register Application** in ServiceNow:
   - Go to System OAuth > Application Registry
   - Create new OAuth API endpoint for external clients
   - Note the Client ID and Client Secret

2. **Get Access Token**:

   ```bash
   POST /oauth_token.do
   Content-Type: application/x-www-form-urlencoded
   
   grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET
   ```

3. **Use Bearer Token**:

   ```json
   {
     "auth_type": "oauth2",
     "client_id": "your-client-id",
     "client_secret": "your-client-secret"
   }
   ```

The scripts include TODO comments showing where to implement OAuth2 support.

## Monitoring

The scripts will output status information:

- Event detection and details
- HTTP request details (for debugging)
- Success/failure of incident creation
- Incident numbers and URLs
- Polling status and timing

## Troubleshooting

1. **Authentication errors (401)**:
   - Verify username/password are correct
   - Check user has incident creation permissions
   - Ensure account is not locked

2. **Permission errors (403)**:
   - Verify user has `incident_manager` role
   - Check Table API access permissions
   - Confirm assignment group permissions

3. **No events detected**:
   - This is normal - Azure only shows events when maintenance is scheduled
   - Test with the `--once` flag to verify connection

4. **Instance URL errors**:
   - Ensure URL format: `https://instance.service-now.com`
   - No trailing slashes
   - Verify instance is accessible

5. **Custom field errors**:
   - Custom fields (u_azure_vm, u_event_count) are optional
   - Remove from payload if fields don't exist
