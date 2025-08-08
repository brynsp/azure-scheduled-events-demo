"""
Azure Scheduled Events Demo - Scenario 3: Automated Handling + ServiceNow Record

This script monitors Azure Scheduled Events, executes automated drain hooks,
performs early acknowledgment to shorten impact windows, and creates ServiceNow
records documenting the automation taken.

Usage:
    python linux_monitor.py [--config config.json] [--poll-interval 30]

Requirements:
    - requests library: pip install requests
    - Azure VM with Instance Metadata Service access
    - ServiceNow instance with Table API access (for automation records)
    - Appropriate permissions for drain operations
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
from drain_hooks import DrainHooks


def create_servicenow_automation_record(
    snow_config: dict, events_data: dict, automation_results: dict
) -> bool:
    """
    Create a ServiceNow record documenting the automation performed.

    Args:
        snow_config: ServiceNow configuration dictionary
        events_data: Events data from IMDS
        automation_results: Results from drain hooks and early ACK

    Returns:
        True if successful, False otherwise
    """
    # Use incidents table, but mark as informational/resolved
    url = f"{snow_config['instance_url']}/api/now/table/incident"

    events = events_data.get("Events", [])
    event_details = []

    for event in events:
        event_details.append(f"Event ID: {event.get('EventId', 'Unknown')}")
        event_details.append(f"Type: {event.get('EventType', 'Unknown')}")
        event_details.append(f"Status: {event.get('EventStatus', 'Unknown')}")
        event_details.append(f"Scheduled: {event.get('NotBefore', 'Unknown')}")
        event_details.append(f"Resources: {', '.join(event.get('Resources', []))}")
        event_details.append("")

    # Format automation results
    automation_summary = []
    for result in automation_results.get("drain_results", []):
        automation_summary.append(f"- {result}")

    short_description = f"Azure Scheduled Event(s) Automated - {len(events)} event(s)"
    description = f"""Azure Scheduled Events automatically handled by automation system.

Event Count: {len(events)}
Automation Time: {datetime.now().isoformat()}
Early ACK Status: {'  Success' if automation_results.get('early_ack_success') else '✗ Failed'}

Event Details:
{chr(10).join(event_details)}

Automation Actions Taken:
{chr(10).join(automation_summary)}

Impact Window: {'Shortened via early acknowledgment' if automation_results.get('early_ack_success') else 'Standard maintenance window'}

This record was automatically created to document successful automation handling of Azure Scheduled Events. No manual intervention was required."""

    payload = {
        "short_description": short_description,
        "description": description,
        "category": "Infrastructure",
        "subcategory": "Automation",
        "urgency": "4",  # Low urgency - automated handling
        "impact": "4",  # Low impact - automation succeeded
        "priority": "4",  # Low priority - informational
        "state": "6",  # Resolved state
        "close_code": "Solved (Permanently)",
        "close_notes": "Azure Scheduled Events handled automatically. No issues detected.",
        "assignment_group": snow_config.get("assignment_group", ""),
        "caller_id": snow_config.get("caller_id", ""),
        "u_azure_vm": snow_config.get("vm_identifier", ""),
        "u_event_count": str(len(events)),
        "u_automation_success": "true",
    }

    # Remove empty fields
    payload = {k: v for k, v in payload.items() if v}

    # Prepare authentication
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "AzureScheduledEvents-Demo/1.0",
    }

    # Basic Authentication
    if snow_config.get("auth_type", "basic") == "basic":
        username = snow_config["username"]
        password = snow_config["password"]
        credentials = base64.b64encode(f"{username}:{password}".encode()).decode()
        headers["Authorization"] = f"Basic {credentials}"

    try:
        print(f"Creating ServiceNow automation record… ")
        print_http_request_debug("POST", url, headers, payload)

        response = requests.post(url, json=payload, headers=headers, timeout=30)

        print(f"ServiceNow response: {response.status_code}")
        response.raise_for_status()

        result = response.json()
        record_number = result.get("result", {}).get("number", "Unknown")
        record_sys_id = result.get("result", {}).get("sys_id", "Unknown")

        print(f"  Successfully created ServiceNow automation record: {record_number}")
        print(f"  Record sys_id: {record_sys_id}")
        print(
            f"  URL: {snow_config['instance_url']}/nav_to.do?uri=incident.do?sys_id={record_sys_id}"
        )

        return True

    except requests.RequestException as e:
        print(f"  Error creating ServiceNow automation record: {e}")
        if hasattr(e, "response") and e.response is not None:
            print(f"  Response status: {e.response.status_code}")
            print(f"  Response body: {e.response.text}")
        return False


def process_scheduled_events_with_automation(
    events_data: dict, config: dict, client: ScheduledEventsClient
) -> None:
    """
    Process detected scheduled events with full automation.

    Args:
        events_data: Events data from IMDS
        config: Configuration dictionary
        client: IMDS client for early acknowledgment
    """
    print(
        f"\n[{datetime.now().isoformat()}] Processing scheduled events with automation… "
    )

    events = events_data.get("Events", [])
    automation_results = {
        "drain_results": [],
        "early_ack_success": False,
        "servicenow_record_success": False,
    }

    # Initialize drain hooks
    drain_config = config.get("automation", {})
    hooks = DrainHooks(drain_config)

    print(f"Available drain hooks: {json.dumps(hooks.get_hook_summary(), indent=2)}")

    # Step 1: Execute drain hooks for each event
    print("\n=== Step 1: Executing Drain Hooks ===")
    overall_drain_success = True

    for event in events:
        print(
            f"\nProcessing event {event.get('EventId', 'Unknown')} ({event.get('EventType', 'Unknown')})… "
        )

        success, results = hooks.execute_all_hooks(event)
        automation_results["drain_results"].extend(results)

        if not success:
            overall_drain_success = False
            print(f"  Drain hooks failed for event {event.get('EventId')}")
        else:
            print(
                f"  Drain hooks completed successfully for event {event.get('EventId')}"
            )

    # Step 2: Early acknowledge events if drain was successful
    print(f"\n=== Step 2: Early Acknowledgment ===")
    if overall_drain_success:
        print("Drain hooks successful - proceeding with early acknowledgment… ")

        ack_success_count = 0
        for event in events:
            event_id = event.get("EventId")
            if client.acknowledge_event(event_id):
                ack_success_count += 1
            time.sleep(1)  # Brief delay between ACKs

        if ack_success_count == len(events):
            automation_results["early_ack_success"] = True
            print(f"  Successfully acknowledged all {len(events)} event(s)")
            print("Impact window has been shortened via early acknowledgment!")
        else:
            print(f"  Only acknowledged {ack_success_count}/{len(events)} event(s)")
    else:
        print("  Skipping early acknowledgment due to drain hook failures")
        automation_results["drain_results"].append(
            "  Early acknowledgment skipped due to drain failures"
        )

    # Step 3: Create ServiceNow automation record
    print(f"\n=== Step 3: ServiceNow Documentation ===")
    if config.get("servicenow"):
        record_success = create_servicenow_automation_record(
            config["servicenow"], events_data, automation_results
        )
        automation_results["servicenow_record_success"] = record_success

        if record_success:
            print("  ServiceNow automation record created successfully")
        else:
            print("  Failed to create ServiceNow automation record")
    else:
        print("ServiceNow configuration not found - skipping record creation")

    # Summary
    print(f"\n=== Automation Summary ===")
    print(f"Events processed: {len(events)}")
    print(f"Drain hooks: {'✓ Success' if overall_drain_success else '✗ Failed'}")
    print(
        f"Early acknowledgment: {'✓ Success' if automation_results['early_ack_success'] else '✗ Failed'}"
    )
    print(
        f"ServiceNow record: {'✓ Success' if automation_results.get('servicenow_record_success') else '✗ Failed/Skipped'}"
    )

    if automation_results["early_ack_success"]:
        print(f"\n  Automation completed successfully! Impact window shortened.")
    else:
        print(f"\n  Automation partially completed. Manual review may be required.")


def main():
    """Main function to run the automated handling scenario."""
    parser = argparse.ArgumentParser(
        description="Azure Scheduled Events - Automated Handling + ServiceNow"
    )
    parser.add_argument(
        "--config", default="config.json", help="Configuration file path"
    )
    parser.add_argument(
        "--poll-interval", type=int, default=30, help="Polling interval in seconds"
    )
    parser.add_argument("--once", action="store_true", help="Check once and exit")
    parser.add_argument(
        "--dry-run", action="store_true", help="Run drain hooks in dry-run mode"
    )

    args = parser.parse_args()

    setup_logging("Scenario 3 - Automated Handling + ServiceNow Record")

    # Load configuration
    config = load_config(args.config)
    if not config:
        sys.exit(1)

    # Override dry-run setting if specified
    if args.dry_run:
        if "automation" not in config:
            config["automation"] = {}
        config["automation"]["dry_run"] = True
        print("  Running in DRY-RUN mode - no actual changes will be made")

    # Validate automation configuration (optional)
    if "automation" in config:
        print(f"Automation configuration: {json.dumps(config['automation'], indent=2)}")

    # ServiceNow is optional for this scenario
    if "servicenow" in config:
        snow_required = ["instance_url", "username", "password"]
        if not validate_config(config["servicenow"], snow_required):
            print(
                "ServiceNow configuration invalid - automation records will be skipped"
            )
            config.pop("servicenow", None)

    # Initialize IMDS client
    client = ScheduledEventsClient()

    print(f"Monitoring for scheduled events (polling every {args.poll_interval}s)")
    if config.get("servicenow"):
        print(f"ServiceNow instance: {config['servicenow']['instance_url']}")
    if args.dry_run:
        print("Mode: DRY-RUN (no actual changes will be made)")
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

                # Process events with full automation
                process_scheduled_events_with_automation(events_data, config, client)

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
