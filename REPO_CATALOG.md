# CFlex Repository Catalog & Blueprints
Version: 1.0  
Date: August 22, 2025

---

## Overview
This catalog defines the complete repository architecture for the CFlex platform, including purpose, goals, responsibilities, interdependencies, documentation requirements, audit folder templates, deliverables, and success metrics for each repository.

The architecture uses eight repositories, aligned to deployment units, failure domains, and agent responsibilities.

---

## Common Requirements for All Repositories
- docs/
  - OVERVIEW.md, ARCHITECTURE.md, API_CONTRACT.md, OPERATIONS.md, SECURITY.md, MAINTENANCE.md
  - ADR/ (Architectural Decision Records) with numbered markdown files
- audit/
  - agent-progress/YYYY/WW-week.md (auto-compiled standups)
  - completed-tasks/<task-id>.md (with acceptance evidence)
  - code-quality/coverage-reports/, static-analysis/, performance-benchmarks/, security-scans/
  - releases/release-readiness-checklist.md, rollback-verification.md
- .github/workflows/ci.yml, security.yml, quality.yml
- CONTRIBUTING.md, CODEOWNERS

---

## Repositories

### 1) cflex-core-platform
- Purpose: Orchestrator, API gateway, business logic, authZ/authN
- Stack: Node.js (NestJS), TypeScript, MySQL, Redis
- Goals: <200ms P95 API, >85% coverage on critical paths, 99.5% uptime
- Depends on: cflex-storage-manager, cflex-file-processor, cflex-whatsapp-proxy, cflex-monitoring-system, cflex-infrastructure
- Provides: Public REST APIs, domain events, signed URL broker
- Deliverables: API spec, business rules engine, webhooks, metrics endpoint (/metrics)
- Success Metrics: Error rate <0.1%, SLOs documented and met

### 2) cflex-rise-customizations
- Purpose: Rise CRM 3.9.3 custom modules for printing workflows
- Stack: PHP 8.2+, CodeIgniter 4, MySQL
- Goals: Zero core modifications, plugin architecture, <500ms pricing calc
- Depends on: MySQL
- Provides: REST endpoints, webhooks, admin UIs
- Deliverables: Modules (pricing, inventory, file mgmt), migration scripts, API docs
- Success Metrics: 100% compatibility with Rise updates, no schema drift

### 3) cflex-monitoring-system
- Purpose: Monitoring, logging, dashboards, alerting
- Stack: Prometheus, Grafana, Loki (logs), Uptime-Kuma; Alertmanager
- Goals: Unified dashboards, SLO/SLI tracking, actionable alerts
- Depends on: exporters from all services
- Provides: Dashboards, alert routes, log storage/access
- Deliverables: Prometheus config, Grafana dashboards JSON, Alertmanager rules, Loki config
- Success Metrics: MTTR < 4h, false positive rate < 5%, dashboard adoption by stakeholders

### 4) cflex-storage-manager
- Purpose: Hybrid storage (VPS hot, cPanel SFTP cold), signed URLs
- Stack: Node.js, SFTP, optional MinIO client
- Goals: Reliable tiering, resumable uploads, anti-virus hooks (ClamAV), encryption at rest
- Depends on: cPanel SFTP, VPS filesystem, ClamAV service
- Provides: Storage SDK, mover jobs, retention policies
- Deliverables: FileMover service, CLI tools, SDK for other repos
- Success Metrics: 0 data loss, mover backlog < 1h, signed URL misuse 0 incidents

### 5) cflex-file-processor
- Purpose: Previews, conversions (TIFF/PSD -> JPG), watermarks, PDFs
- Stack: Node.js, Sharp/libvips, ImageMagick fallback, BullMQ
- Goals: 90% of <50MB files processed <60s; memory efficiency
- Depends on: cflex-storage-manager, Redis
- Provides: Worker services, processing metrics
- Deliverables: Queue workers, processing pipeline, health endpoints
- Success Metrics: Throughput targets met; CPU/mem within guardrails

### 6) cflex-whatsapp-proxy
- Purpose: WhatsApp messaging via Baileys with email fallback
- Stack: Node.js, Baileys, Nodemailer
- Goals: Reliable delivery, session resilience, compliance logging
- Depends on: Redis, SMTP relay
- Provides: /send, /status APIs; webhooks
- Deliverables: Message templates, retry/backoff logic, health checks
- Success Metrics: Delivery success rate > 95%; auto-recovery < 2m

### 7) cflex-bagisto-sync
- Purpose: Optional e-commerce sync to Bagisto (Phase 2/Contingency)
- Stack: Laravel 10+, PHP, GraphQL/REST
- Goals: Accurate product/order/customer sync
- Depends on: cflex-core-platform, Bagisto APIs
- Provides: Sync jobs, reconciliation reports
- Deliverables: Sync services, conflict resolution policies, CLI tools
- Success Metrics: 100% reconciliation consistency; <0.1% conflict rate

### 8) cflex-infrastructure
- Purpose: IaC, deployment, backups, security hardening
- Stack: Ansible, Bash, YAML; GitHub Actions workflows
- Goals: Repeatable deployments, zero-downtime, auditable changes
- Depends on: VPS, cPanel access
- Provides: Playbooks, scripts, policies
- Deliverables: Ansible roles, GH Actions, backup/restore scripts, hardening baselines
- Success Metrics: >98% deploy success; rollback <2m; backup verify weekly

---

## Audit Folder Templates (copy into each repo)

```text
/audit/
  agent-progress/
    2025/
      34-week.md
  completed-tasks/
    TASK-1234.md
  code-quality/
    coverage-reports/
    static-analysis/
    performance-benchmarks/
    security-scans/
  releases/
    release-readiness-checklist.md
    rollback-verification.md
```

### Example: release-readiness-checklist.md
- [ ] Tests > 85% coverage critical paths
- [ ] Load test P95 < target
- [ ] Security scans: 0 criticals, 0 secrets
- [ ] Docs updated (API, OPERATIONS, ADR link)
- [ ] Rollback plan validated

---

## Interdependencies
See DEVELOPMENT_STRATEGY.md section 10 for full matrix and rationale.

