# Azure Scheduled Events Overview

Azure Scheduled Events is a metadata service that provides advance notification about upcoming maintenance events for Virtual Machines. This service enables applications to prepare for VM maintenance and minimize service disruption.

## What are Scheduled Events?

Scheduled Events are notifications sent by Azure when maintenance is planned for your VM. These events provide advance warning (typically 15+ minutes) before actions like:

- **Reboots** - VM restart for host OS updates or hardware maintenance
- **Redeployment** - VM migration to different physical hardware  
- **Preemption** - Spot VM eviction due to capacity requirements
- **Freeze** - Brief VM pause (usually seconds)
- **Terminate** - VM deletion (planned)

## Instance Metadata Service (IMDS)

Scheduled Events are accessed through the Azure Instance Metadata Service:

### Endpoint

```text
http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01
```

### Required Headers

```text
Metadata: true
```

### Polling for Events (GET)

```bash
curl -H "Metadata: true" \
  "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"
```

### Acknowledging Events (POST)  

```bash
curl -H "Metadata: true" \
  -H "Content-Type: application/json" \
  -d '{"StartRequests": [{"EventId": "event-id-here"}]}' \
  "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"
```

## Event Structure

Each scheduled event contains:

```json
{
  "DocumentIncarnation": 1,
  "Events": [
    {
      "EventId": "A123BC45-1234-5678-AB90-ABCDEF123456",
      "EventStatus": "Scheduled", 
      "EventType": "Reboot",
      "ResourceType": "VirtualMachine",
      "Resources": ["vm1", "vm2"],
      "NotBefore": "2024-01-15T10:00:00Z",
      "Description": "The virtual machine is being rebooted due to planned maintenance.",
      "EventSource": "Platform"
    }
  ]
}
```

### Key Fields

| Field | Description |
|-------|-------------|
| `EventId` | Unique identifier for the event |
| `EventType` | Type: Reboot, Redeploy, Preempt, Freeze, Terminate |
| `EventStatus` | Status: Scheduled, Started |
| `NotBefore` | Earliest time the event will occur (ISO 8601) |
| `Resources` | List of affected VM names |
| `Description` | Human-readable event description |

## Event Types and Typical Use Cases

### Reboot Events

**Cause**: Host OS updates, security patches, hardware maintenance

**Duration**: Usually 1-5 minutes

**Application Response**:

- Graceful application shutdown
- Flush caches and buffers
- Drain active connections
- Save application state

### Redeploy Events  

**Cause**: VM migration to different hardware

**Duration**: Several minutes

**Application Response**:

- Backup critical data
- Export application state
- Prepare for potential data loss
- Notify monitoring systems

### Preempt Events

**Cause**: Spot VM eviction due to capacity needs

**Duration**: Very short notice (30 seconds typical)

**Application Response**:

- Quick save of work in progress
- Migrate workload to other instances
- Update job queues
- Fast cleanup operations

### Freeze Events

**Cause**: Live migration or snapshot operations

**Duration**: Usually seconds

**Application Response**:

- Usually no action needed
- Monitor for extended freezes

## Early Acknowledgment Benefits

### Without Early Acknowledgment

- Azure controls timing (15+ minute window)
- Fixed maintenance schedule
- No coordination with application state
- Longer service impact window

### With Early Acknowledgment

- Application controls timing
- Maintenance starts immediately after ACK
- Coordinated with application drain completion
- Minimized service impact window

### Implementation

```json
POST to IMDS endpoint with:
{
  "StartRequests": [
    {"EventId": "event-id-here"}
  ]
}
```

## Best Practices

### Polling Strategy

- **Frequency**: Poll every 30-60 seconds
- **Timeout**: Use 5-10 second request timeouts
- **Error Handling**: Continue monitoring on failures
- **Efficiency**: Cache DocumentIncarnation to detect changes

### Event Handling

- **Validate Events**: Check EventStatus and NotBefore time
- **Idempotent Operations**: Design drain hooks to be safely repeatable
- **Timeout Management**: Complete preparation within 10 minutes
- **Graceful Degradation**: Handle partial preparation failures

### Security Considerations

- **IMDS Access**: Only available from within the VM
- **Network Isolation**: IMDS endpoint not accessible externally
- **Authentication**: No authentication required (implicit VM identity)
- **Rate Limiting**: Azure enforces reasonable request limits

## Integration Patterns

### Human Response Workflows

1. **Alerting Systems**: Send notifications to teams
2. **ITSM Integration**: Create tickets in ServiceNow/Jira
3. **Communication**: Notify stakeholders via email/Teams
4. **Coordination**: Manual approval for maintenance windows

### Automated Response Workflows  

1. **Application Draining**: Automatic graceful shutdown
2. **Load Balancer Updates**: Remove from rotation
3. **Data Protection**: Backup critical state
4. **Early Acknowledgment**: Shorten maintenance windows
5. **Documentation**: Log automation actions

### Monitoring and Observability

- **Event Logging**: Record all detected events
- **Metrics Collection**: Track automation success rates
- **Health Checks**: Monitor application state during events
- **Alerting**: Notify on automation failures

## Common Challenges and Solutions

### Challenge: Missed Events

**Problem**: Application doesn't poll frequently enough

**Solution**: Use 30-60 second polling intervals

### Challenge: Preparation Timeouts

**Problem**: Drain operations take too long

**Solution**: Optimize shutdown procedures, use timeouts

### Challenge: Coordination Issues

**Problem**: Multiple applications need coordinated shutdown

**Solution**: Implement centralized coordination logic

### Challenge: Testing Difficulties

**Problem**: Scheduled events are unpredictable

**Solution**: Use Azure maintenance schedules for testing

## Testing Strategies

### Development Testing

- **Mock IMDS**: Create test doubles for IMDS responses
- **Unit Tests**: Test drain hook logic in isolation
- **Integration Tests**: Test end-to-end event handling

### Production Validation

- **Dry-Run Mode**: Test without making actual changes
- **Planned Maintenance**: Use scheduled maintenance windows
- **Monitoring**: Verify automation during real events

## References

- [Azure Scheduled Events Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/scheduled-events)
- [Instance Metadata Service](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/instance-metadata-service)
- [Azure Maintenance Configurations](https://docs.microsoft.com/en-us/azure/virtual-machines/maintenance-configurations)
