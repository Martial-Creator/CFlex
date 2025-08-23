# Inter-Agent Communication Protocol
**Version**: 1.0  
**Date**: August 23, 2025

---

## Communication Architecture

### Message Format Standard
```json
{
  "message_id": "MSG-{timestamp}-{from}-{to}",
  "timestamp": "2025-08-23T14:50:00Z",
  "from_agent": "agent-1-database",
  "to_agent": "agent-2-backend-api",
  "message_type": "handoff|request|notification|error",
  "priority": "critical|high|medium|low",
  "context": {
    "task_id": "T-001-DB-FOUNDATION",
    "phase": "foundation",
    "sprint": 1
  },
  "payload": {},
  "attachments": [],
  "requires_response": true,
  "deadline": "2025-08-23T18:00:00Z"
}
```

## Message Types

### 1. Handoff Messages
Used when completing work that another agent depends on.

```json
{
  "message_type": "handoff",
  "payload": {
    "completed_task": "T-001-DB-FOUNDATION",
    "deliverables": [
      "artifacts/migrations/001_create_cflex_orders.sql",
      "artifacts/docs/schema_design_v1.md"
    ],
    "next_action": "Create CRUD APIs for order management",
    "context_notes": "All tables optimized for read-heavy workload",
    "integration_points": {
      "foreign_keys": ["client_id -> clients.id"],
      "indexes": ["idx_order_status", "idx_client_id"],
      "performance_notes": "Expect 80/20 read/write pattern"
    },
    "potential_issues": []
  }
}
```

### 2. Request Messages
Used when needing help or information from another agent.

```json
{
  "message_type": "request",
  "payload": {
    "request_type": "information|assistance|review",
    "description": "Need API endpoint specifications for file upload",
    "urgency": "blocking current task",
    "details": {
      "current_task": "T-003-FILE-UPLOAD",
      "specific_need": "Expected request/response format for /api/files/upload",
      "context": "Building file processor, need to match API contract"
    }
  }
}
```

### 3. Notification Messages
Used for status updates and non-blocking information sharing.

```json
{
  "message_type": "notification",
  "payload": {
    "notification_type": "progress|completion|issue|milestone",
    "summary": "Database schema 70% complete",
    "details": {
      "completed": ["orders table", "products table"],
      "in_progress": ["file_uploads table"],
      "blocked": [],
      "eta": "2025-08-24T12:00:00Z"
    }
  }
}
```

### 4. Error Messages
Used when encountering blocking issues that need resolution.

```json
{
  "message_type": "error",
  "payload": {
    "error_type": "technical|dependency|resource|clarification",
    "severity": "critical|high|medium|low",
    "description": "Migration script failing on foreign key constraint",
    "error_details": {
      "error_code": "1452",
      "error_message": "Cannot add or update a child row",
      "affected_task": "T-001-DB-FOUNDATION",
      "context": "Referencing Rise CRM clients table"
    },
    "assistance_needed": "Need confirmation of Rise CRM table structure",
    "suggested_resolution": "Review Rise CRM clients table schema"
  }
}
```

## Communication Channels

### Primary Channel: Shared Message Queue
- Location: `agents/shared/message_queue.json`
- Format: JSON array of messages
- Polling: Each agent checks every 15 minutes
- Retention: 30 days

### Secondary Channel: Direct File System
- Location: `agents/{to_agent}/inbox/{message_id}.json`
- For urgent messages requiring immediate attention
- Triggers: File system watch or explicit check

### Emergency Channel: Status Files
- Location: `agents/{agent}/status.json`
- For critical issues, failures, or urgent help
- Checked by coordinator every 5 minutes

## Handoff Protocol

### Step 1: Prepare Handoff
```json
{
  "handoff_preparation": {
    "validate_deliverables": true,
    "run_quality_checks": true,
    "update_documentation": true,
    "prepare_context": true
  }
}
```

### Step 2: Create Handoff Message
- Include all artifacts and documentation
- Provide detailed context and notes
- Specify next actions for receiving agent
- Highlight any potential issues or dependencies

### Step 3: Update Shared State
- Update global task board
- Mark dependencies as resolved
- Trigger notifications to waiting agents

### Step 4: Confirmation
- Receiving agent acknowledges receipt
- Validates deliverables
- Confirms readiness to proceed

## Dependency Management

### Blocking Dependencies
```yaml
dependency_type: "blocking"
waiting_agent: "agent-2-backend-api"
waiting_for: "agent-1-database"
task_blocked: "T-002-API-ORDERS"
requirement: "Database schema for orders table"
auto_check: true  # Automatically resolve when deliverable appears
```

### Soft Dependencies
```yaml
dependency_type: "soft"
can_proceed_with: "mock data or stubs"
preferred_wait: "real implementation"
fallback_plan: "Create mock order API, replace later"
```

### Circular Dependencies
Detection and resolution:
1. Monitor dependency chains
2. Identify cycles automatically
3. Break cycles by introducing interfaces/mocks
4. Prioritize critical path items

## Quality Gates

### Message Validation
- Required fields present
- Valid agent IDs
- Proper message format
- Reasonable payload size

### Handoff Validation
- All deliverables exist and accessible
- Documentation updated
- Quality checks passed
- Next actions clearly defined

### Response Requirements
- Acknowledge receipt within 1 hour
- Provide status update within 4 hours
- Complete dependency resolution within SLA

## Coordination Rules

### Daily Sync Protocol
Time slots for different types of communication:
- **9:00 AM**: Status reports and priority adjustments
- **1:00 PM**: Progress updates and help requests
- **5:00 PM**: Handoffs and next-day planning

### Message Priority Handling
- **Critical**: Immediate attention required, <1 hour response
- **High**: Important but not blocking, <4 hour response
- **Medium**: Standard priority, <24 hour response
- **Low**: Informational, response when convenient

### Escalation Path
1. **Level 1**: Direct agent-to-agent resolution
2. **Level 2**: Coordinator intervention
3. **Level 3**: Human project manager
4. **Level 4**: Stakeholder decision

## Shared Resources

### Global Task Board
Location: `agents/shared/task_board.json`
```json
{
  "current_sprint": 1,
  "phase": "foundation",
  "tasks": {
    "T-001-DB-FOUNDATION": {
      "agent": "agent-1-database",
      "status": "in_progress",
      "progress": 70,
      "eta": "2025-08-24T12:00:00Z",
      "blocked": false
    }
  },
  "dependencies": [],
  "milestones": []
}
```

### Shared Knowledge Base
Location: `agents/shared/knowledge/`
- Common patterns and solutions
- Integration specifications
- Error resolution guides
- Best practices

### Artifact Registry
Location: `agents/shared/artifacts/`
- Shared deliverables
- Documentation
- Code libraries
- Configuration files

## Communication Best Practices

### Clear Communication
- Use specific, actionable language
- Include relevant context
- Specify expected outcomes
- Provide clear deadlines

### Efficient Coordination
- Batch related messages
- Use appropriate priority levels
- Avoid unnecessary back-and-forth
- Document decisions and rationales

### Error Prevention
- Validate inputs before processing
- Check dependencies before starting work
- Communicate blockers immediately
- Provide fallback plans

This protocol ensures smooth coordination between agents while maintaining autonomy and preventing bottlenecks.
