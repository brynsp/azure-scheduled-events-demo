"""
Utility functions for Azure Scheduled Events demo scenarios.
"""

import json
import os
import sys
from typing import Dict, Any, Optional


def load_config(config_path: str) -> Optional[Dict[str, Any]]:
    """
    Load configuration from JSON file.

    Args:
        config_path: Path to the configuration file

    Returns:
        Configuration dictionary or None if loading fails
    """
    try:
        with open(config_path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Configuration file not found: {config_path}")
        print(f"Please copy the .example file and configure it with your settings.")
        return None
    except json.JSONDecodeError as e:
        print(f"Error parsing configuration file: {e}")
        return None


def validate_config(config: Dict[str, Any], required_keys: list) -> bool:
    """
    Validate that required configuration keys are present.

    Args:
        config: Configuration dictionary
        required_keys: List of required configuration keys

    Returns:
        True if all required keys are present, False otherwise
    """
    missing_keys = [
        key for key in required_keys if key not in config or not config[key]
    ]

    if missing_keys:
        print(f"Missing required configuration keys: {', '.join(missing_keys)}")
        return False

    return True


def setup_logging(scenario_name: str) -> None:
    """
    Set up basic logging for the scenario.

    Args:
        scenario_name: Name of the scenario for log prefixes
    """
    print(f"=== Azure Scheduled Events Demo - {scenario_name} ===")
    print(f"Python version: {sys.version}")
    print(f"Working directory: {os.getcwd()}")
    print("=" * 60)


def create_minimal_payload(
    events_data: Dict[str, Any], scenario: str
) -> Dict[str, Any]:
    """
    Create a minimal JSON payload for external systems.

    Args:
        events_data: Raw events data from IMDS
        scenario: Name of the scenario creating the payload

    Returns:
        Minimal payload dictionary
    """
    events = events_data.get("Events", [])

    # Extract key information for each event
    event_summaries = []
    for event in events:
        event_summaries.append(
            {
                "eventId": event.get("EventId"),
                "eventType": event.get("EventType"),
                "eventStatus": event.get("EventStatus"),
                "notBefore": event.get("NotBefore"),
                "resources": event.get("Resources", []),
            }
        )

    return {
        "scenario": scenario,
        "timestamp": events_data.get("DocumentIncarnation"),
        "eventCount": len(events),
        "events": event_summaries,
    }


def print_http_request_debug(
    method: str,
    url: str,
    headers: Dict[str, str],
    payload: Optional[Dict[str, Any]] = None,
) -> None:
    """
    Print HTTP request details for debugging.

    Args:
        method: HTTP method
        url: Request URL
        headers: Request headers
        payload: Request payload (optional)
    """
    print(f"\n--- HTTP Request Debug ---")
    print(f"Method: {method}")
    print(f"URL: {url}")
    print(f"Headers: {json.dumps(headers, indent=2)}")
    if payload:
        print(f"Payload: {json.dumps(payload, indent=2)}")
    print("--- End Debug ---\n")


def mask_sensitive_data(data: str, keywords: Optional[list] = None) -> str:
    """
    Mask sensitive data in strings for logging.

    Args:
        data: String that may contain sensitive data
        keywords: List of keywords to mask (default: common sensitive terms)

    Returns:
        String with sensitive data masked
    """
    if keywords is None:
        keywords = ["password", "token", "key", "secret", "authorization"]

    masked_data = data
    for keyword in keywords:
        if keyword.lower() in data.lower():
            # Simple masking - replace with asterisks
            masked_data = masked_data.replace(data, "***MASKED***")
            break

    return masked_data
