# CFlex Monitoring & Logging Design
Version: 1.0  
Date: August 22, 2025

---

## Objectives
- Real-time observability across infrastructure, application, and business layers
- Actionable alerts with low noise
- Cost-efficient deployment on a single VPS, compatible with cPanel storage constraints

## Stack Selection (Reasoned)
- Metrics: Prometheus + Node Exporter, Redis/Mysql exporters
  - Rationale: Low footprint, pull model, mature ecosystem
- Dashboards: Grafana
  - Rationale: Rich visualization, alerting integration
- Logs: Loki (promtail agents) instead of ELK for footprint
  - Rationale: Efficient indexing; ELK is heavier for our VPS size
- Uptime: Uptime-Kuma for external checks and notifications
- Alerting: Alertmanager (Prometheus) + email/WhatsApp proxy fallback

Alternatives considered: Netdata (lightweight, optional for quick host view). ELK reserved for future if resources increase.

## Architecture
```
[VPS]
  ├─ Prometheus (scrape: app services, exporters)
  ├─ Grafana (dashboards + alerts)
  ├─ Loki (logs)
  ├─ Promtail (ships app logs)
  ├─ Uptime-Kuma (external HTTP/TCP checks)
  └─ Exporters:
       - node_exporter (host)
       - mysqld_exporter (DB)
       - redis_exporter (Redis)
       - app /metrics endpoints
[cPanel]
  └─ No agents. Access via SFTP for storage metrics via scheduled job on VPS.
```

## Log Sources & Schema
- Application services: cflex-* repos emit structured JSON logs
- Nginx reverse proxy: access/error logs via promtail
- System logs: journal/syslog as needed

JSON schema example:
```json
{
  "ts": "2025-08-22T12:00:00Z",
  "level": "INFO",
  "service": "cflex-file-processor",
  "action": "preview_generated",
  "request_id": "req-abc123",
  "order_id": "ORD-1001",
  "file_id": "F-9983",
  "duration_ms": 44231,
  "status": "success"
}
```

## Metrics & SLIs
- API: http_request_duration_seconds P95 < 3s; error_rate < 0.1%
- Queue: job_latency_seconds P95 < 30s; backlog_size < threshold
- File processing: preview_time_seconds P90 < 60s (<=50MB)
- Storage: mover_backlog_files < 1000; mover_fail_rate < 0.5%
- Business: orders_processed_per_day, approval_rate, revision_cycles_avg

## Alert Policies
- Critical:
  - Uptime: 2 consecutive failures
  - DB down / redis down
  - Error rate > 1% over 5m
  - Queue backlog above threshold 30m
- Warning:
  - CPU > 85% 10m; Mem > 85% 10m; Disk > 85%
  - Preview P95 > 60s sustained 15m
- Info:
  - Backup completed/failed, deploy finished

## Dashboards
- Infra: CPU, MEM, DISK, NET, process health
- App: API latency, error rates, queue depth, worker health
- File: processing throughput, success/failure, duration percentiles
- Business: orders by status, approvals, tickets

## cPanel Storage Considerations
- No agents on cPanel: gather storage stats via SFTP directory listings (scheduled)
- Store daily snapshots of preview sizes and cold-tier counts for trend lines
- Signed URL access logs captured at app layer for visibility

## Security & Access
- TLS for Grafana and Prometheus (reverse proxy)
- Read-only viewer roles for stakeholders
- Admin access restricted by IP allowlist
- Log privacy: redact PII (names/phones) from logs; use IDs

## Retention & Costs
- Metrics: 15 days high-res; 1y downsampled (if enabled)
- Logs: 30d app logs in Loki; 7y audit logs in DB with encryption
- Backups: Grafana dashboards JSON, Prometheus rules, Loki index

## Implementation Steps
1. Provision Prometheus, Grafana, Loki, Uptime-Kuma on VPS
2. Add exporters and /metrics endpoints to services
3. Configure promtail to ship JSON logs
4. Create initial dashboards (import JSON in repo)
5. Define alert rules and routes (email, WhatsApp proxy as fallback)
6. Document OPERATIONS.md runbooks and on-call procedures

## Success Metrics
- MTTR < 4 hours; alert acknowledgment < 15 minutes
- Alert noise rate < 5%; dashboard adoption by target users > 80%

