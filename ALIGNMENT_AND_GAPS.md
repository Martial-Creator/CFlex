# Alignment & Gaps Analysis: PRD/SRS vs Development Plan
Version: 1.0  
Date: August 22, 2025

---

## Source Documents Referenced
- PRD/consolidate v2.md
- PRD/consolidate v3.md
- PRD/CUSTOMIZATION-STRATEGY.md
- PRD/SOFTWARE_SPECIFICATION.md

---

## Alignment Summary

### Architecture & Hosting
- PRD v2: Gauzy + Bagisto with VPS app and cPanel storage via SFTP
- SRS: Single-domain Rise CRM with enhanced Store
- Plan: Default to SRS (Rise-only) for Phase 1 to reduce complexity; keep PRD hybrid as contingency (see ADR D1)

### File Handling & Previews
- PRD: TIFF/PSD -> JPG previews, watermark, annotations, 500MB cap
- SRS: Same support within Rise customization
- Plan: cflex-file-processor with Sharp/libvips primary, ImageMagick fallback; annotation via front-end lib; meets NFRs

### Communications
- PRD: WhatsApp proxy + email fallback; templates bilingual
- SRS: WhatsApp + email; daily notifications
- Plan: cflex-whatsapp-proxy using Baileys; strict retry/backoff and fallback to email; monitor and gate via metrics

### Inventory & Purchasing
- PRD: Mixed raw/finished tracking; low-stock alerts
- SRS: Inventory tracking with alerts
- Plan: Implement per CUSTOMIZATION-STRATEGY.md sections 2.5/2.6; integrate alerts into monitoring

### Reporting & Monitoring
- PRD: Ops dashboards, scheduled reports; observability
- SRS: Reporting and system KPIs
- Plan: cflex-monitoring-system with Prometheus/Grafana/Loki; business dashboards in Grafana; report exports via app

---

## Conflicts & Decisions Needed
1) Store Architecture (Hybrid vs Rise-only)
- Conflict: PRD v2 prefers hybrid; SRS prefers Rise-only
- Decision Gate: Week 4 spike results on Store capability; if significant gaps are found, activate cflex-bagisto-sync and minimal Bagisto storefront

2) Performance NFR Differences
- PRD v2: P95 page load < 2s; SRS: < 3s
- Proposal: Target 2.5s P95 compromise initially; optimize towards 2s where feasible; record ADR

3) Data Retention Policies
- PRD v2: Invoices 7y, uploads 2y; SRS: generalized requirements
- Decision: Adopt stricter PRD policy; document in SECURITY.md and OPERATIONS.md

4) WhatsApp Proxy Risk
- Decision: Proceed with proxy; define migration path to Official API; monitor ban risk and error rates

---

## Gaps & Clarifications Requested
- Quality Checklist before delivery: PRD suggests later; SRS defers; confirm whether to include a minimal QC step in Phase 1
- VIP customer handling: SRS says no VIP; confirm priority rules for organizations vs individuals
- Emergency orders: Clarify after-hours support expectations and SLAs
- SMS fallback: PRD email fallback is mandatory; is SMS also required in Phase 1?

---

## Traceability Mapping (Sample)
- BR-1 (Reduce manual steps) → Core workflow automation (core-platform), queues, templates; Tests: E2E upload→notify
- NFR-Perf → Prometheus SLI tracking, load tests documented in monitoring repo
- Security (RBAC, signed URLs, ClamAV) → Implemented across core, storage, processor; Tests: file upload security cases

---

## Next Actions
- Record ADR D1-D7 across repos
- Execute Week 1-4 spikes (Store capability, storage mover throughput, WhatsApp resiliency)
- Update this document after spikes with final decisions

