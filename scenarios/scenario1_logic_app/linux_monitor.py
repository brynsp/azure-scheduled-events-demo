"""
Azure Scheduled Events Demo - Scenario 1: Logic App Alerting

This script monitors Azure Scheduled Events and sends notifications to an
Azure Logic App when events are detected. This scenario is designed for
human response workflows.

Usage:
    python linux_monitor.py [--config config.json] [--poll-interval 30]

Requirements:
    - requests library: pip install requests
    - Azure VM with Instance Metadata Service access
    - Configured Azure Logic App with HTTP trigger
"""

import argparse
import sys
import os
import time
import requests
import json
from datetime import datetime

# Add the common module to the path
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "..", "common"))

from imds_client import ScheduledEventsClient
from utils import (
    load_config,
    validate_config,
    setup_logging,
    create_minimal_payload,
    print_http_request_debug,
)


def send_to_logic_app(logic_app_url: str, payload: dict, timeout: int = 10) -> bool:
    """
    Send event notification to Azure Logic App.

    Args:
        logic_app_url: The Logic App HTTP trigger URL
        payload: JSON payload to send
        timeout: Request timeout in seconds

    Returns:
        True if successful, False otherwise
    """
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "AzureScheduledEvents-Demo/1.0",
    }

    try:
        print(f"Sending notification to Logic App…")
        print_http_request_debug("POST", logic_app_url, headers, payload)

        response = requests.post(
            logic_app_url, json=payload, headers=headers, timeout=timeout
        )

        print(f"Logic App response: {response.status_code}")
        if response.text:
            print(f"Response body: {response.text}")

        response.raise_for_status()
        print("✓ Successfully sent notification to Logic App")
        return True

    except requests.RequestException as e:
        print(f"✗ Error sending to Logic App: {e}")
        return False


def process_scheduled_events(events_data: dict, config: dict) -> None:
    """
    Process detected scheduled events and send to Logic App.

    Args:
        events_data: Events data from IMDS
        config: Configuration dictionary
    """
    print(f"\n[{datetime.now().isoformat()}] Processing scheduled events…")

    # Create minimal payload for Logic App
    payload = create_minimal_payload(events_data, "Logic App Alerting")

    # Add scenario-specific information
    payload.update(
        {
            "alertType": "scheduled_event_detected",
            "severity": "medium",
            "description": f"Detected {payload['eventCount']} scheduled event(s) requiring attention",
            "actionRequired": "Review events and coordinate maintenance window",
        }
    )

    # Send to Logic App
    success = send_to_logic_app(config["logic_app_url"], payload)

    if success:
        print("Logic App notification sent successfully")
    else:
        print("Failed to send Logic App notification")


def main():
    """Main function to run the Logic App alerting scenario."""
    parser = argparse.ArgumentParser(
        description="Azure Scheduled Events - Logic App Alerting"
    )
    parser.add_argument(
        "--config", default="config.json", help="Configuration file path"
    )
    parser.add_argument(
        "--poll-interval", type=int, default=30, help="Polling interval in seconds"
    )
    parser.add_argument("--once", action="store_true", help="Check once and exit")

    args = parser.parse_args()

    setup_logging("Scenario 1 - Logic App Alerting")

    # Load configuration
    config = load_config(args.config)
    if not config:
        sys.exit(1)

    # Validate required configuration
    required_keys = ["logic_app_url"]
    if not validate_config(config, required_keys):
        print("\nExample configuration:")
        print(
            json.dumps(
                {
                    "logic_app_url": "https://your-logic-app.azurewebsites.net/api/your-trigger-url"
                },
                indent=2,
            )
        )
        sys.exit(1)

    # Initialize IMDS client
    client = ScheduledEventsClient()

    print(f"Monitoring for scheduled events (polling every {args.poll_interval}s)")
    print(f"Logic App URL: {config['logic_app_url']}")
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

                # Process events and send to Logic App
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
