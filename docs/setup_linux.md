# Linux Setup Guide

This guide covers setup and deployment of Azure Scheduled Events monitoring on Linux systems.

## Prerequisites

### System Requirements

- Linux distribution with Python 3.6+
- Network access to Azure Instance Metadata Service (169.254.169.254)
- Sufficient privileges for application management operations

### Supported Distributions

- Ubuntu 18.04+
- CentOS/RHEL 7+
- SUSE Linux Enterprise 15+
- Debian 9+

## Installation

### 1. Install Python Dependencies

#### Ubuntu/Debian

```bash
# Update package lists
sudo apt update

# Install Python 3 and pip
sudo apt install python3 python3-pip

# Install required Python packages
pip3 install requests
```

#### CentOS/RHEL

```bash
# Install Python 3 and pip
sudo yum install python3 python3-pip

# Install required Python packages  
pip3 install requests
```

### 2. Download Demo Scripts

```bash
# Clone or download the repository
git clone https://github.com/brynsp/azure-scheduled-events-demo.git
cd azure-scheduled-events-demo

# Make scripts executable
chmod +x scenarios/*/linux_monitor.py
```

### 3. Verify IMDS Connectivity

```bash
# Test basic IMDS connectivity
curl -H "Metadata: true" \
  "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01" \
  --connect-timeout 5

# Expected response (when no events):
# {"DocumentIncarnation":1,"Events":[]}
```

## Configuration

### 1. Scenario-Specific Setup

Choose your scenario and configure accordingly:

#### Scenario 1: Logic App Alerting

```bash
cd scenarios/scenario1_logic_app
cp config.json.example config.json
nano config.json  # Edit with your Logic App URL
```

#### Scenario 2: ServiceNow Direct

```bash
cd scenarios/scenario2_servicenow_direct  
cp config.json.example config.json
nano config.json  # Edit with your ServiceNow details
```

#### Scenario 3: Automated Handling

```bash
cd scenarios/scenario3_automated_handling
cp config.json.example config.json
nano config.json  # Edit automation and ServiceNow settings
```

### 2. Network Configuration

Ensure the VM can reach the IMDS endpoint:

```bash
# Test connectivity
ping -c 3 169.254.169.254

# Check for firewall issues
sudo iptables -L | grep 169.254.169.254

# If using Azure NSG, ensure no blocking rules exist
```

### 3. Service Account Setup (Optional)

For production deployments, create a dedicated service account:

```bash
# Create service account
sudo useradd -r -s /bin/false azure-events

# Create working directory
sudo mkdir -p /opt/azure-events
sudo chown azure-events:azure-events /opt/azure-events

# Copy scripts
sudo cp -r scenarios /opt/azure-events/
sudo chown -R azure-events:azure-events /opt/azure-events/
```

## Running the Monitors

### Manual Execution

#### Test Mode (Dry Run)

```bash
# Test Scenario 3 without making changes
cd scenarios/scenario3_automated_handling
python3 linux_monitor.py --dry-run --once
```

#### Continuous Monitoring

```bash
# Run with default settings
python3 linux_monitor.py

# Custom polling interval
python3 linux_monitor.py --poll-interval 60

# Custom configuration file
python3 linux_monitor.py --config /path/to/config.json
```

### Systemd Service Setup

Create a systemd service for automatic startup:

#### 1. Create Service File

```bash
sudo nano /etc/systemd/system/azure-scheduled-events.service
```

```ini
[Unit]
Description=Azure Scheduled Events Monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=azure-events
Group=azure-events
WorkingDirectory=/opt/azure-events/scenarios/scenario3_automated_handling
ExecStart=/usr/bin/python3 linux_monitor.py --config /opt/azure-events/config.json
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

#### 2. Enable and Start Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service for startup
sudo systemctl enable azure-scheduled-events

# Start service
sudo systemctl start azure-scheduled-events

# Check status
sudo systemctl status azure-scheduled-events
```

### Cron Job Setup (Alternative)

For simpler deployments, use cron for periodic checks:

```bash
# Edit crontab
crontab -e

# Add entry to check every 5 minutes
*/5 * * * * cd /opt/azure-events/scenarios/scenario1_logic_app && python3 linux_monitor.py --once >> /var/log/azure-events.log 2>&1
```

## Monitoring and Logging

### Log Management

#### Systemd Logs

```bash
# View recent logs
sudo journalctl -u azure-scheduled-events -f

# View logs from last hour
sudo journalctl -u azure-scheduled-events --since "1 hour ago"

# Export logs
sudo journalctl -u azure-scheduled-events --since today > azure-events.log
```

#### File-Based Logging

```python
# Add to your monitor script
import logging

logging.basicConfig(
    filename='/var/log/azure-events.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
```

### Health Monitoring

#### Simple Health Check Script

```bash
#!/bin/bash
# /opt/azure-events/healthcheck.sh

LOGFILE="/var/log/azure-events.log"
TIMEOUT=300  # 5 minutes

# Check if process is running
if ! pgrep -f "linux_monitor.py" > /dev/null; then
    echo "ERROR: Monitor process not running"
    exit 1
fi

# Check for recent log activity
if [ -f "$LOGFILE" ]; then
    LAST_LOG=$(stat -c %Y "$LOGFILE")
    NOW=$(date +%s)
    DIFF=$((NOW - LAST_LOG))
    
    if [ $DIFF -gt $TIMEOUT ]; then
        echo "WARNING: No recent log activity ($DIFF seconds)"
        exit 1
    fi
fi

echo "OK: Monitor is healthy"
exit 0
```

Make it executable and add to cron:

```bash
chmod +x /opt/azure-events/healthcheck.sh

# Add to crontab for monitoring
*/10 * * * * /opt/azure-events/healthcheck.sh || echo "Azure Events Monitor unhealthy" | logger
```

## Security Considerations

### File Permissions

```bash
# Secure configuration files
sudo chmod 600 /opt/azure-events/scenarios/*/config.json
sudo chown azure-events:azure-events /opt/azure-events/scenarios/*/config.json

# Secure script directory
sudo chmod 750 /opt/azure-events
sudo chown -R azure-events:azure-events /opt/azure-events
```

### Network Security

```bash
# Allow IMDS access (if firewall blocks it)
sudo iptables -A OUTPUT -d 169.254.169.254 -p tcp --dport 80 -j ACCEPT

# For restrictive environments, create specific rule
sudo iptables -A OUTPUT -d 169.254.169.254 -p tcp --dport 80 -m owner --uid-owner azure-events -j ACCEPT
```

### SELinux Considerations (CentOS/RHEL)

```bash
# Check SELinux status
sestatus

# If enforcing, you may need custom policies
# Create and apply SELinux module if needed
sudo setsebool -P httpd_can_network_connect on
```

## Troubleshooting

### Common Issues

#### 1. IMDS Connectivity Issues

```bash
# Test with verbose output
curl -v -H "Metadata: true" \
  "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"

# Check routing
ip route get 169.254.169.254

# Test with different timeout
curl --connect-timeout 10 -H "Metadata: true" \
  "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"
```

#### 2. Python Import Errors

```bash
# Check Python path
python3 -c "import sys; print(sys.path)"

# Verify requests library
python3 -c "import requests; print(requests.__version__)"

# Install missing dependencies
pip3 install requests --user
```

#### 3. Permission Errors

```bash
# Check file ownership
ls -la /opt/azure-events/scenarios/*/config.json

# Fix permissions
sudo chown azure-events:azure-events /opt/azure-events/scenarios/*/config.json
sudo chmod 600 /opt/azure-events/scenarios/*/config.json
```

#### 4. Service Start Issues

```bash
# Check service logs
sudo journalctl -u azure-scheduled-events --no-pager

# Test manual execution
sudo -u azure-events python3 /opt/azure-events/scenarios/scenario3_automated_handling/linux_monitor.py --once

# Verify working directory
sudo -u azure-events pwd
```

### Debug Mode

Enable detailed debugging:

```python
# Add to top of monitor script
import logging
logging.basicConfig(level=logging.DEBUG)

# Or use debug flag
python3 linux_monitor.py --debug
```
