# CFlex Subdomain Architecture Specification
**Version**: 2.1  
**Date**: August 23, 2025  
**Multi-Tenant Structure**: Client/Staff/Admin Separation

---

## Subdomain Architecture Overview

The CFlex platform uses a **multi-tenant subdomain architecture** to separate concerns and provide role-specific interfaces:

### 🏢 Primary Subdomains

#### 1. **clients.caldronflex.com.np**
**Purpose**: Customer-facing business management interface  
**Target Users**: Organizations, Individual Customers, Guests  
**Core Functionality**:
- Order placement and tracking
- Design review and approval
- Invoice viewing and payment tracking
- Project collaboration
- File upload and annotation
- Communication center (WhatsApp/Email notifications)

**Technology Stack**:
- Frontend: Angular/React SPA
- Backend: Node.js/NestJS APIs + Rise CRM extensions
- Authentication: JWT with customer-specific permissions

#### 2. **staff.caldronflex.com.np**
**Purpose**: Staff operational interface  
**Target Users**: Staff Helpers, Staff Admins  
**Core Functionality**:
- Task queue management
- Order processing workflow
- File processing and preview generation
- Inventory management
- Customer communication
- Production scheduling
- Quality control

**Technology Stack**:
- Frontend: Angular/React with staff-specific components
- Backend: Shared APIs with staff-level permissions
- Features: Real-time task updates, drag-drop workflows

#### 3. **admin.caldronflex.com.np**
**Purpose**: System administration and business intelligence  
**Target Users**: System Admins, Business Owners  
**Core Functionality**:
- User and role management
- System configuration
- Business analytics and reporting
- Financial oversight
- System monitoring dashboards
- Backup and maintenance
- Integration management

**Technology Stack**:
- Frontend: Admin-optimized dashboard
- Backend: Full system access APIs
- Integration: Monitoring systems (Grafana, Prometheus)

#### 4. **caldronflex.com.np** (Main Domain)
**Purpose**: E-commerce storefront and public website  
**Target Users**: General public, prospective customers  
**Core Functionality**:
- Product catalog browsing
- Online ordering (standardized items)
- Company information
- Contact and support
- AR/VR product viewers
- SEO-optimized content

**Technology Stack**:
- E-commerce: Bagisto or custom solution
- CMS: Content management for public pages
- Integration: Sync with core platform APIs

---

## Multi-Tenant Data Architecture

### Tenant Identification Strategy
```javascript
// Subdomain-based tenant resolution
const getTenantFromSubdomain = (req) => {
  const subdomain = req.get('host').split('.')[0];
  return {
    'clients': { type: 'client', role: 'customer' },
    'staff': { type: 'internal', role: 'staff' },
    'admin': { type: 'internal', role: 'admin' },
    'www': { type: 'public', role: 'anonymous' }
  }[subdomain] || { type: 'public', role: 'anonymous' };
};
```

### Database Schema Considerations
```sql
-- Multi-tenant aware tables
CREATE TABLE cflex_tenants (
  id INT AUTO_INCREMENT PRIMARY KEY,
  subdomain VARCHAR(50) UNIQUE NOT NULL,
  type ENUM('client', 'staff', 'admin', 'public') NOT NULL,
  config JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add tenant context to core tables
ALTER TABLE cflex_orders ADD COLUMN tenant_context VARCHAR(20) DEFAULT 'client';
ALTER TABLE cflex_users ADD COLUMN allowed_subdomains JSON; -- ['clients', 'staff']
```

## Reference Architecture Analysis

### From GitHub Projects Study

#### Twenty (Modern CRM)
**Reference**: https://github.com/twentyhq/twenty  
**Learnings**:
- GraphQL-first API design
- React + TypeScript frontend
- PostgreSQL with Prisma ORM
- Multi-workspace architecture (applicable to our subdomains)
- Real-time subscriptions for live updates

**Applicable Patterns**:
- Workspace-based data isolation → Subdomain-based tenant isolation
- GraphQL schema stitching for complex queries
- Component-based UI architecture

#### ERPNext (Business Management)
**Reference**: https://github.com/frappe/erpnext  
**Learnings**:
- Frappe framework architecture
- Role-based permission system
- Modular app structure
- Workflow automation engine
- Multi-company support

**Applicable Patterns**:
- DocType system → Our entity management
- Permission framework → Role-based subdomain access
- Workflow states → Order processing pipeline

#### Ever-Gauzy (ERP/CRM)
**Reference**: https://github.com/ever-co/ever-gauzy  
**Learnings**:
- NestJS + Angular architecture
- Multi-tenant by design
- Task management and time tracking
- File management system
- Real-time updates via WebSockets

**Applicable Patterns**:
- Tenant-aware services → Subdomain-aware services
- Task queue management → Our printing workflow
- File processing pipeline → Design file handling

#### Odoo (Comprehensive ERP)
**Reference**: https://github.com/odoo/odoo  
**Learnings**:
- Modular addon architecture
- Multi-database multi-tenant approach
- Workflow automation
- Extensive reporting system
- Web client architecture

**Applicable Patterns**:
- Module system → Our feature separation by subdomain
- Database per tenant → Shared DB with tenant context
- ORM abstractions for complex queries

#### NocoBase (No-Code Platform)
**Reference**: https://github.com/nocobase/nocobase  
**Learnings**:
- Plugin-based architecture
- Dynamic schema management
- Role-based access control
- REST + GraphQL APIs
- React frontend with extensible components

**Applicable Patterns**:
- Plugin architecture → Feature modules per subdomain
- Dynamic permissions → Role-based subdomain access
- Extensible UI components → Reusable across subdomains

#### Akaunting (Accounting Software)
**Reference**: https://github.com/akaunting/akaunting  
**Learnings**:
- Laravel-based architecture
- Multi-company support
- Modular app structure
- API-first design
- Modern responsive UI

**Applicable Patterns**:
- Multi-company → Multi-tenant subdomains
- Module separation → Subdomain-specific features
- API structure → Consistent across all subdomains

## Implementation Strategy

### Shared Core Services
All subdomains share core services but with different access levels:

```javascript
// Shared service with subdomain-aware permissions
class OrderService {
  constructor(tenantContext) {
    this.tenant = tenantContext;
  }
  
  async getOrders(filters) {
    switch(this.tenant.type) {
      case 'client':
        return this.getClientOrders(filters);
      case 'staff':
        return this.getStaffOrders(filters);
      case 'admin':
        return this.getAllOrders(filters);
    }
  }
}
```

### Authentication & Authorization
```javascript
// JWT payload with subdomain context
{
  "sub": "user123",
  "subdomains": ["clients", "staff"], // Allowed subdomains
  "roles": {
    "clients": ["customer"],
    "staff": ["helper", "admin"]
  },
  "tenant_context": {
    "current_subdomain": "staff",
    "organization_id": "org456"
  }
}
```

### API Structure
```
/api/v1/
├── shared/          # Cross-subdomain APIs
│   ├── auth/        # Authentication
│   ├── users/       # User management
│   └── files/       # File operations
├── client/          # Client-specific APIs
│   ├── orders/      # Order management
│   ├── projects/    # Project collaboration
│   └── invoices/    # Invoice viewing
├── staff/           # Staff-specific APIs
│   ├── tasks/       # Task management
│   ├── production/  # Production workflow
│   └── inventory/   # Inventory management
└── admin/           # Admin-specific APIs
    ├── analytics/   # Business intelligence
    ├── config/      # System configuration
    └── monitoring/  # System health
```

This architecture provides clear separation of concerns while maintaining shared infrastructure and data consistency across all subdomains.
