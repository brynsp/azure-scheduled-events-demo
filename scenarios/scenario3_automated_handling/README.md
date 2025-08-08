# Scenario 3: Automated Handling + ServiceNow Record

This scenario demonstrates the highest value approach: automated handling of Azure Scheduled Events with drain hooks, early acknowledgment to shorten impact windows, and ServiceNow documentation of automation actions.

## Overview

When scheduled events are detected, this scenario:

1. **Executes automated drain hooks** based on event type (reboot, redeploy, preempt)
2. **Performs early acknowledgment** to IMDS to shorten the maintenance window
3. **Creates ServiceNow automation records** documenting what was automated
4. **Minimizes service impact** through automation and shortened windows

This approach provides the highest business value by reducing both human intervention requirements and service impact duration.

## Files

- `linux_monitor.py` - Python implementation for Linux VMs
- `windows_monitor.ps1` - PowerShell implementation for Windows VMs
- `drain_hooks.py` - Python module with sample drain hook implementations
- `config.json.example` - Example configuration file

## Setup

### Prerequisites

- Azure VM with access to Instance Metadata Service
- Python 3.6+ (for Linux) or Windows PowerShell 5.1 (for Windows)
- Appropriate permissions for drain operations (application shutdown, etc.)
- ServiceNow instance access (optional - for automation documentation)

### Configuration

1. Copy the example configuration:

   ```bash
   cp config.json.example config.json
   ```

2. Edit `config.json` with your settings:

   ```json
   {
     "automation": {
       "dry_run": true
     },
     "servicenow": {
       "instance_url": "https://your-instance.service-now.com",
       "username": "automation-user",
       "password": "your-password",
       "auth_type": "basic",
       "assignment_group": "Infrastructure Team",
       "caller_id": "automation.user",
       "vm_identifier": "your-vm-name"
     }
   }
   ```

3. **Important**: Start with `dry_run: true` to test safely

### Drain Hooks Customization

The included drain hooks are **demonstration stubs**. For production use:

1. **Review `drain_hooks.py`** (Linux) or the PowerShell equivalents in `windows_monitor.ps1`
2. **Replace stub implementations** with your actual application logic:
   - Database connection draining
   - Application graceful shutdown
   - Load balancer removal
   - Cache flushing
   - State backup/export
   - Workload migration

3. **Test thoroughly** in development environments before production deployment

## Usage

### Linux (Python)

Install dependencies:

```bash
pip install requests
```

Run the monitor:

```bash
# Start with dry-run mode (recommended)
python linux_monitor.py --dry-run

# Continuous monitoring (dry-run)
python linux_monitor.py

# Production mode (after testing)
# Edit config.json to set "dry_run": false
python linux_monitor.py

# Custom polling interval
python linux_monitor.py --poll-interval 60

# Check once and exit
python linux_monitor.py --once

# Force dry-run mode via command line
python linux_monitor.py --dry-run
```

### Windows (PowerShell)

Run the monitor:

```powershell
# Start with dry-run mode (recommended)
.\windows_monitor.ps1 -DryRun

# Continuous monitoring (dry-run)
.\windows_monitor.ps1

# Production mode (after testing)
# Edit config.json to set "dry_run": false
.\windows_monitor.ps1

# Custom polling interval
.\windows_monitor.ps1 -PollInterval 60

# Check once and exit
.\windows_monitor.ps1 -Once

# Force dry-run mode via command line
.\windows_monitor.ps1 -DryRun
```

## Automation Flow

### Step 1: Drain Hook Execution

For each detected event, the system executes appropriate hooks:

| Event Type | Drain Actions |
|------------|---------------|
| **Reboot** | Graceful app shutdown, cache flush, DB sync, traffic drain |
| **Redeploy** | Data backup, state export, monitoring notification |
| **Preempt** | Quick save, workload migration, queue updates |
| **Generic** | Basic state save and graceful shutdown |

### Step 2: Early Acknowledgment

If all drain hooks succeed:

- **POST acknowledgment** to IMDS for each event
- **Shortens maintenance window** from default (15+ minutes) to immediate
- **Reduces service impact duration** significantly

### Step 3: ServiceNow Documentation

Creates resolved incident records documenting:

- Events processed
- Automation actions taken
- Success/failure status  
- Impact window reduction achieved

## Drain Hook Implementation Guide

### Key Principles

1. **Idempotent operations** - Safe to run multiple times
2. **Fast execution** - Complete within 2-3 minutes maximum
3. **Graceful degradation** - Fail safely if operations can't complete
4. **Comprehensive logging** - Record all actions for troubleshooting

### Example Implementations

#### Database Connection Draining

```python
def drain_database_connections(self):
    # Stop accepting new connections
    # Wait for existing transactions to complete
    # Force-close remaining connections
    # Sync transaction logs
```

#### Load Balancer Removal

```python
def remove_from_load_balancer(self):
    # Call load balancer API to mark instance unhealthy
    # Wait for health check failures to propagate
    # Verify no new traffic is arriving
```

#### Application Graceful Shutdown

```python
def shutdown_applications(self):
    # Send SIGTERM to application processes
    # Wait for graceful shutdown
    # Force kill if timeout exceeded
    # Verify processes have stopped
```

## Early Acknowledgment Benefits

| Without Early ACK | With Early ACK |
|-------------------|----------------|
| 15+ minute maintenance window | Immediate start after ACK |
| Fixed Azure-controlled timing | Application-controlled timing |
| No coordination with app state | Coordinated with drain completion |
| Higher service impact | Minimized service impact |

## ServiceNow Integration

### Automation Records

The system creates **resolved incidents** with these characteristics:

- **Category**: Infrastructure/Automation
- **Priority**: Low (informational)
- **State**: Resolved  
- **Purpose**: Document successful automation

### Custom Fields (Optional)

Enhance tracking by adding these ServiceNow fields:

- `u_azure_vm` - VM identifier
- `u_event_count` - Number of events processed
- `u_automation_success` - Success flag

## Monitoring and Alerting

The scripts provide detailed output for monitoring:

```text
=== Step 1: Executing Drain Hooks ===
  Executing reboot preparation hooks… 
    - Applications gracefully stopped
    - Caches flushed  
    - Database synchronized
    Drain hooks completed successfully

=== Step 2: Early Acknowledgment ===
  Successfully acknowledged all 1 event(s)
Impact window has been shortened via early acknowledgment!

=== Step 3: ServiceNow Documentation ===
  ServiceNow automation record created successfully

=== Automation Summary ===
Events processed: 1
Drain hooks:   Success
Early acknowledgment:   Success  
ServiceNow record:   Success

Automation completed successfully! Impact window shortened.
```

## Safety Features

### Dry-Run Mode

- **Test automation logic** without making changes
- **Validate configuration** before production deployment
- **Debug drain hooks** safely

### Failure Handling

- **Skip early ACK** if drain hooks fail
- **Continue monitoring** after failures
- **Log all errors** for troubleshooting

### Configuration Validation

- **Check required settings** at startup
- **Graceful degradation** for missing optional components
- **Clear error messages** for configuration issues
