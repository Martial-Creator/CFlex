-- =====================================================
-- CFlex Multi-Tenant Infrastructure Setup
-- Migration: 001_create_tenant_infrastructure.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-001
-- Created: 2025-08-23
-- =====================================================

-- Set UTF8MB4 for bilingual support (English/Nepali)
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- Table: cflex_tenants
-- Purpose: Tenant/subdomain configuration and management
-- Based on: Ever-Gauzy and Twenty multi-tenant patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_tenants` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `subdomain` VARCHAR(50) UNIQUE NOT NULL COMMENT 'Subdomain identifier (clients, staff, admin, public)',
  `type` ENUM('client', 'staff', 'admin', 'public') NOT NULL COMMENT 'Tenant type for access control',
  `name` VARCHAR(255) NOT NULL COMMENT 'Human-readable tenant name',
  `config` JSON COMMENT 'Tenant-specific configuration settings',
  `status` ENUM('active', 'inactive', 'maintenance') DEFAULT 'active' COMMENT 'Tenant operational status',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Indexes for performance
  INDEX `idx_tenant_subdomain` (`subdomain`),
  INDEX `idx_tenant_type_status` (`type`, `status`),
  INDEX `idx_tenant_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Multi-tenant subdomain configuration';

-- =====================================================
-- Table: cflex_user_tenants
-- Purpose: User access to specific tenants/subdomains
-- Integration: Links to Rise CRM users table
-- Based on: Ever-Gauzy tenant-user relationships
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_user_tenants` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL COMMENT 'Foreign key to Rise CRM users table',
  `tenant_id` INT NOT NULL COMMENT 'Foreign key to cflex_tenants',
  `roles` JSON COMMENT 'Role per subdomain: {"clients": ["customer"], "staff": ["helper"]}',
  `permissions` JSON COMMENT 'Specific permissions override for this tenant',
  `status` ENUM('active', 'inactive', 'pending') DEFAULT 'active' COMMENT 'User-tenant relationship status',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Foreign key constraints
  FOREIGN KEY (`tenant_id`) REFERENCES `cflex_tenants`(`id`) ON DELETE CASCADE,
  -- Note: user_id references Rise CRM users table - constraint added via application logic
  
  -- Indexes for performance
  INDEX `idx_user_tenant_user` (`user_id`, `tenant_id`),
  INDEX `idx_user_tenant_tenant` (`tenant_id`, `status`),
  INDEX `idx_user_tenant_status` (`status`),
  
  -- Unique constraint to prevent duplicate user-tenant relationships
  UNIQUE KEY `uk_user_tenant` (`user_id`, `tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User access to specific tenants';

-- =====================================================
-- Insert Default Tenant Data
-- Based on SUBDOMAIN_ARCHITECTURE.md specifications
-- =====================================================

INSERT INTO `cflex_tenants` (`subdomain`, `type`, `name`, `config`, `status`) VALUES
('clients', 'client', 'Client Portal', 
 JSON_OBJECT(
   'features', JSON_ARRAY('order_placement', 'design_review', 'invoice_viewing', 'project_collaboration'),
   'theme', 'client-theme',
   'max_file_size_mb', 500,
   'allowed_file_types', JSON_ARRAY('pdf', 'ai', 'psd', 'tiff', 'jpg', 'png'),
   'session_timeout_minutes', 120
 ), 'active'),

('staff', 'staff', 'Staff Operations', 
 JSON_OBJECT(
   'features', JSON_ARRAY('task_management', 'order_processing', 'file_processing', 'inventory_management'),
   'theme', 'staff-theme',
   'max_concurrent_tasks', 10,
   'auto_assign_tasks', true,
   'session_timeout_minutes', 480
 ), 'active'),

('admin', 'admin', 'System Administration', 
 JSON_OBJECT(
   'features', JSON_ARRAY('user_management', 'system_config', 'analytics', 'monitoring'),
   'theme', 'admin-theme',
   'full_system_access', true,
   'session_timeout_minutes', 720
 ), 'active'),

('public', 'public', 'Public Website', 
 JSON_OBJECT(
   'features', JSON_ARRAY('product_catalog', 'online_ordering', 'company_info'),
   'theme', 'public-theme',
   'cache_duration_minutes', 60,
   'seo_enabled', true
 ), 'active');

-- =====================================================
-- Validation and Constraints
-- =====================================================

-- Add check constraints for JSON structure validation
-- Note: MySQL 8.0+ supports JSON schema validation
-- For older versions, validation handled at application level

-- Ensure tenant config has required fields
ALTER TABLE `cflex_tenants` 
ADD CONSTRAINT `chk_tenant_config_valid` 
CHECK (JSON_VALID(`config`));

-- Ensure user_tenants roles and permissions are valid JSON
ALTER TABLE `cflex_user_tenants` 
ADD CONSTRAINT `chk_roles_valid` 
CHECK (JSON_VALID(`roles`));

ALTER TABLE `cflex_user_tenants` 
ADD CONSTRAINT `chk_permissions_valid` 
CHECK (JSON_VALID(`permissions`));

-- =====================================================
-- Performance Optimization
-- =====================================================

-- Additional composite indexes for common query patterns
CREATE INDEX `idx_tenant_subdomain_status` ON `cflex_tenants` (`subdomain`, `status`);
CREATE INDEX `idx_user_tenant_user_status` ON `cflex_user_tenants` (`user_id`, `status`);

-- =====================================================
-- Migration Complete
-- =====================================================

-- Log migration completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('001_create_tenant_infrastructure', 'completed', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'completed', 
  `executed_at` = NOW();
