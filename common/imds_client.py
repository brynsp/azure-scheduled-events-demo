"""
Azure Instance Metadata Service (IMDS) client for Scheduled Events.

This module provides a simple interface to interact with the Azure IMDS
Scheduled Events API, including polling for events and acknowledging them.
"""

import json
import time
import requests
from typing import Dict, List, Optional, Any
from datetime import datetime


class ScheduledEventsClient:
    """Client for Azure IMDS Scheduled Events API."""
    
    # IMDS endpoint for scheduled events
    IMDS_ENDPOINT = "http://169.254.169.254/metadata/scheduledevents"
    API_VERSION = "2020-07-01"
    HEADERS = {"Metadata": "true"}
    
    def __init__(self, timeout: int = 5):
        """
        Initialize the Scheduled Events client.
        
        Args:
            timeout: Request timeout in seconds
        """
        self.timeout = timeout
        self.base_url = f"{self.IMDS_ENDPOINT}?api-version={self.API_VERSION}"
    
    def get_scheduled_events(self) -> Optional[Dict[str, Any]]:
        """
        Poll for scheduled events from IMDS.
        
        Returns:
            Dictionary containing scheduled events data or None if request fails
        """
        try:
            response = requests.get(
                self.base_url,
                headers=self.HEADERS,
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"Error polling scheduled events: {e}")
            return None
        except json.JSONDecodeError as e:
            print(f"Error parsing scheduled events response: {e}")
            return None
    
    def acknowledge_event(self, event_id: str) -> bool:
        """
        Acknowledge a scheduled event to IMDS (early ACK).
        
        Args:
            event_id: The ID of the event to acknowledge
            
        Returns:
            True if acknowledgment was successful, False otherwise
        """
        payload = {
            "StartRequests": [
                {"EventId": event_id}
            ]
        }
        
        try:
            response = requests.post(
                self.base_url,
                headers=self.HEADERS,
                json=payload,
                timeout=self.timeout
            )
            response.raise_for_status()
            print(f"Successfully acknowledged event {event_id}")
            return True
        except requests.RequestException as e:
            print(f"Error acknowledging event {event_id}: {e}")
            return False
    
    def has_events(self, events_data: Optional[Dict[str, Any]]) -> bool:
        """
        Check if there are any scheduled events.
        
        Args:
            events_data: The response from get_scheduled_events()
            
        Returns:
            True if there are events, False otherwise
        """
        if not events_data or "Events" not in events_data:
            return False
        return len(events_data["Events"]) > 0
    
    def get_events_list(self, events_data: Optional[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Extract the list of events from the IMDS response.
        
        Args:
            events_data: The response from get_scheduled_events()
            
        Returns:
            List of event dictionaries
        """
        if not events_data or "Events" not in events_data:
            return []
        return events_data["Events"]
    
    def format_event_summary(self, event: Dict[str, Any]) -> str:
        """
        Create a human-readable summary of an event.
        
        Args:
            event: Event dictionary from IMDS
            
        Returns:
            Formatted string describing the event
        """
        event_id = event.get("EventId", "Unknown")
        event_type = event.get("EventType", "Unknown")
        event_status = event.get("EventStatus", "Unknown")
        not_before = event.get("NotBefore", "Unknown")
        resources = event.get("Resources", [])
        
        summary = f"Event {event_id}: {event_type} ({event_status})"
        summary += f"\n  Scheduled for: {not_before}"
        summary += f"\n  Affected resources: {', '.join(resources) if resources else 'None'}"
        
        return summary


def monitor_events(client: ScheduledEventsClient, poll_interval: int = 30) -> Optional[Dict[str, Any]]:
    """
    Continuously monitor for scheduled events.
    
    Args:
        client: ScheduledEventsClient instance
        poll_interval: Time between polls in seconds
    """
    print(f"Starting scheduled events monitoring (polling every {poll_interval}s)")
    print(f"Timestamp: {datetime.now().isoformat()}")
    
    while True:
        try:
            events_data = client.get_scheduled_events()
            
            if client.has_events(events_data):
                events = client.get_events_list(events_data)
                print(f"\n[{datetime.now().isoformat()}] Found {len(events)} scheduled event(s):")
                
                for event in events:
                    print(f"\n{client.format_event_summary(event)}")
                
                return events_data  # Return to caller for processing
            else:
                print(f"[{datetime.now().isoformat()}] No scheduled events")
            
            time.sleep(poll_interval)
            
        except KeyboardInterrupt:
            print("\nMonitoring stopped by user")
            break
        except Exception as e:
            print(f"Error in monitoring loop: {e}")
            time.sleep(poll_interval)
            