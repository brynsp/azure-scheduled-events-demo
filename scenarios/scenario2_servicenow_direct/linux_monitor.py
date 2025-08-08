"""
Azure Scheduled Events Demo - Scenario 2: ServiceNow Direct Alerting

This script monitors Azure Scheduled Events and creates incidents directly
in ServiceNow when events are detected. This scenario demonstrates direct
ITSM integration for human response workflows.

Usage:
    python linux_monitor.py [--config config.json] [--poll-interval 30]

Requirements:
    - requests library: pip install requests
    - Azure VM with Instance Metadata Service access
    - ServiceNow instance with Table API access
    - ServiceNow credentials (Basic Auth or OAuth2)
"""

import argparse
import sys
import os
import time
import requests
import json
import base64
from datetime import datetime

# Add the common module to the path
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "..", "common"))

from imds_client import ScheduledEventsClient
from utils import (
    load_config,
    validate_config,
    setup_logging,
    print_http_request_debug,
)


def create_servicenow_incident(snow_config: dict, events_data: dict) -> bool:
    """
    Create an incident in ServiceNow for scheduled events.

    Args:
        snow_config: ServiceNow configuration dictionary
        events_data: Events data from IMDS

    Returns:
        True if successful, False otherwise
    """
    # ServiceNow Table API endpoint for incidents
    url = f"{snow_config['instance_url']}/api/now/table/incident"

    # Create incident payload
    events = events_data.get("Events", [])
    event_details = []

    for event in events:
        event_details.append(f"Event ID: {event.get('EventId', 'Unknown')}")
        event_details.append(f"Type: {event.get('EventType', 'Unknown')}")
        event_details.append(f"Status: {event.get('EventStatus', 'Unknown')}")
        event_details.append(f"Scheduled: {event.get('NotBefore', 'Unknown')}")
        event_details.append(f"Resources: {', '.join(event.get('Resources', []))}")
        event_details.append("")

    short_description = f"Azure Scheduled Event(s) Detected - {len(events)} event(s)"
    description = f"""Azure Scheduled Events detected requiring attention.

Event Count: {len(events)}
Detection Time: {datetime.now().isoformat()}

Event Details:
{chr(10).join(event_details)}

Action Required:
- Review scheduled maintenance events
- Coordinate with infrastructure teams  
- Plan for service impact during maintenance window
- Communicate to stakeholders as needed

This incident was automatically created by the Azure Scheduled Events monitoring system."""

    payload = {
        "short_description": short_description,
        "description": description,
        "category": "Infrastructure",
        "subcategory": "Maintenance",
        "urgency": "3",  # Medium urgency
        "impact": "3",  # Medium impact
        "priority": "3",  # Medium priority
        "assignment_group": snow_config.get("assignment_group", ""),
        "caller_id": snow_config.get("caller_id", ""),
        "u_azure_vm": snow_config.get("vm_identifier", ""),
        "u_event_count": str(len(events)),
    }

    # Remove empty fields
    payload = {k: v for k, v in payload.items() if v}

    # Prepare authentication
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "AzureScheduledEvents-Demo/1.0",
    }

    # Basic Authentication (demo approach)
    if snow_config.get("auth_type", "basic") == "basic":
        username = snow_config["username"]
        password = snow_config["password"]
        credentials = base64.b64encode(f"{username}:{password}".encode()).decode()
        headers["Authorization"] = f"Basic {credentials}"

    # TODO: OAuth2 Client Credentials implementation
    # For production use, implement OAuth2 client credentials flow:
    # 1. Register application in ServiceNow
    # 2. Get client_id and client_secret
    # 3. Request access token from /oauth_token.do endpoint
    # 4. Use Bearer token in Authorization header
    # Example:
    # elif snow_config.get("auth_type") == "oauth2":
    #     token = get_oauth2_token(snow_config)
    #     headers["Authorization"] = f"Bearer {token}"

    try:
        print(f"Creating ServiceNow incident…")
        print_http_request_debug("POST", url, headers, payload)

        response = requests.post(url, json=payload, headers=headers, timeout=30)

        print(f"ServiceNow response: {response.status_code}")
        response.raise_for_status()

        result = response.json()
        incident_number = result.get("result", {}).get("number", "Unknown")
        incident_sys_id = result.get("result", {}).get("sys_id", "Unknown")

        print(f"  Successfully created ServiceNow incident: {incident_number}")
        print(f"  Incident sys_id: {incident_sys_id}")
        print(
            f"  URL: {snow_config['instance_url']}/nav_to.do?uri=incident.do?sys_id={incident_sys_id}"
        )

        return True

    except requests.RequestException as e:
        print(f"  Error creating ServiceNow incident: {e}")
        if hasattr(e, "response") and e.response is not None:
            print(f"  Response status: {e.response.status_code}")
            print(f"  Response body: {e.response.text}")
        return False


def process_scheduled_events(events_data: dict, config: dict) -> None:
    """
    Process detected scheduled events and create ServiceNow incident.

    Args:
        events_data: Events data from IMDS
        config: Configuration dictionary
    """
    print(f"\n[{datetime.now().isoformat()}] Processing scheduled events…")

    # Create ServiceNow incident
    success = create_servicenow_incident(config["servicenow"], events_data)

    if success:
        print("ServiceNow incident created successfully")
    else:
        print("Failed to create ServiceNow incident")


def main():
    """Main function to run the ServiceNow direct alerting scenario."""
    parser = argparse.ArgumentParser(
        description="Azure Scheduled Events - ServiceNow Direct Alerting"
    )
    parser.add_argument(
        "--config", default="config.json", help="Configuration file path"
    )
    parser.add_argument(
        "--poll-interval", type=int, default=30, help="Polling interval in seconds"
    )
    parser.add_argument("--once", action="store_true", help="Check once and exit")

    args = parser.parse_args()

    setup_logging("Scenario 2 - ServiceNow Direct Alerting")

    # Load configuration
    config = load_config(args.config)
    if not config:
        sys.exit(1)

    # Validate required configuration
    required_keys = ["servicenow"]
    if not validate_config(config, required_keys):
        sys.exit(1)

    # Validate ServiceNow configuration
    snow_required = ["instance_url", "username", "password"]
    if not validate_config(config["servicenow"], snow_required):
        print("\nExample ServiceNow configuration:")
        print(
            json.dumps(
                {
                    "servicenow": {
                        "instance_url": "https://your-instance.service-now.com",
                        "username": "your-username",
                        "password": "your-password",
                        "auth_type": "basic",
                        "assignment_group": "Infrastructure Team",
                        "caller_id": "system.admin",
                        "vm_identifier": "your-vm-name",
                    }
                },
                indent=2,
            )
        )
        sys.exit(1)

    # Initialize IMDS client
    client = ScheduledEventsClient()

    print(f"Monitoring for scheduled events (polling every {args.poll_interval}s)")
    print(f"ServiceNow instance: {config['servicenow']['instance_url']}")
    print("Press Ctrl+C to stop monitoring\n")

    try:
        while True:
            events_data = client.get_scheduled_events()

            if client.has_events(events_data):
                events = client.get_events_list(events_data)
                print(
                    f"\n[{datetime.now().isoformat()}] Found {len(events)} scheduled event(s):"
                )

                for event in events:
                    print(f"  {client.format_event_summary(event)}")

                # Process events and create ServiceNow incident
                process_scheduled_events(events_data, config)

                if args.once:
                    break
            else:
                print(f"[{datetime.now().isoformat()}] No scheduled events detected")

                if args.once:
                    print("No events found, exiting")
                    break

            if not args.once:
                time.sleep(args.poll_interval)

    except KeyboardInterrupt:
        print("\nMonitoring stopped by user")
    except Exception as e:
        print(f"Error in main loop: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
