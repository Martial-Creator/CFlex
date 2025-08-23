-- =====================================================
-- CFlex Core Business Entities Schema
-- Migration: 002_create_core_entities.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-002
-- Created: 2025-08-23
-- Based on: ERPNext DocType patterns and Odoo modular approach
-- =====================================================

-- Set UTF8MB4 for bilingual support (English/Nepali)
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- Table: cflex_projects
-- Purpose: Project/order groups (similar to ERPNext Project)
-- Integration: Links to Rise CRM clients table
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_projects` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `tenant_id` INT NOT NULL COMMENT 'Multi-tenant isolation',
  `project_number` VARCHAR(50) NOT NULL COMMENT 'Human-readable project identifier',
  `name` VARCHAR(255) NOT NULL COMMENT 'Project display name',
  `client_id` INT NOT NULL COMMENT 'Foreign key to Rise CRM clients table',
  `client_type` ENUM('organization', 'individual', 'guest') NOT NULL COMMENT 'Client classification',
  `status` ENUM('draft', 'active', 'on_hold', 'completed', 'cancelled') DEFAULT 'draft' COMMENT 'Project lifecycle status',
  `priority` ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium' COMMENT 'Project priority level',
  `description` TEXT COMMENT 'Project description and notes',
  `start_date` DATE COMMENT 'Project start date',
  `due_date` DATE COMMENT 'Project due date',
  `completion_date` DATE COMMENT 'Actual completion date',
  `estimated_total` DECIMAL(12,2) DEFAULT 0 COMMENT 'Estimated project value',
  `actual_total` DECIMAL(12,2) DEFAULT 0 COMMENT 'Actual project value',
  `metadata` JSON COMMENT 'Project-specific data and configuration',
  `created_by` INT NOT NULL COMMENT 'User who created the project',
  `updated_by` INT COMMENT 'User who last updated the project',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` TIMESTAMP NULL COMMENT 'Soft delete timestamp',
  
  -- Foreign key constraints
  FOREIGN KEY (`tenant_id`) REFERENCES `cflex_tenants`(`id`) ON DELETE RESTRICT,
  -- Note: client_id and user references to Rise CRM handled via application logic
  
  -- Indexes for performance
  INDEX `idx_project_client` (`client_id`, `tenant_id`),
  INDEX `idx_project_status` (`status`, `tenant_id`),
  INDEX `idx_project_dates` (`due_date`, `status`),
  INDEX `idx_project_tenant` (`tenant_id`, `status`, `created_at`),
  INDEX `idx_project_number` (`project_number`, `tenant_id`),
  INDEX `idx_project_soft_delete` (`deleted_at`),
  
  -- Unique constraint for project numbers within tenant
  UNIQUE KEY `uk_project_number_tenant` (`project_number`, `tenant_id`, `deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Project/order groups with multi-tenant support';

-- =====================================================
-- Table: cflex_orders
-- Purpose: Individual orders within projects
-- Based on: ERPNext Item/Sales Order patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_orders` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `tenant_id` INT NOT NULL COMMENT 'Multi-tenant isolation',
  `project_id` INT NOT NULL COMMENT 'Parent project reference',
  `order_number` VARCHAR(50) NOT NULL COMMENT 'Human-readable order identifier',
  `title` VARCHAR(255) NOT NULL COMMENT 'Order title/name',
  `description` TEXT COMMENT 'Detailed order description',
  `product_type` VARCHAR(100) COMMENT 'Product type: flex_banner, certificate, etc.',
  `status` ENUM('draft', 'submitted', 'in_queue', 'claimed', 'design_in_progress', 'awaiting_review', 'changes_requested', 'approved', 'in_production', 'ready_for_collection', 'completed', 'cancelled') DEFAULT 'draft' COMMENT 'Order workflow status',
  `priority` ENUM('normal', 'urgent') DEFAULT 'normal' COMMENT 'Order priority',
  `assigned_to` INT COMMENT 'Staff member assigned to this order',
  `dimensions` JSON COMMENT 'Custom dimensions: {width: 100, height: 50, unit: "cm"}',
  `specifications` JSON COMMENT 'Product-specific specifications',
  `estimated_price` DECIMAL(10,2) COMMENT 'Initial price estimate',
  `final_price` DECIMAL(10,2) COMMENT 'Final agreed price',
  `revision_count` INT DEFAULT 0 COMMENT 'Number of revisions requested',
  `max_revisions` INT DEFAULT 5 COMMENT 'Maximum allowed revisions',
  `due_date` DATETIME COMMENT 'Order due date and time',
  `claimed_at` TIMESTAMP NULL COMMENT 'When order was claimed by staff',
  `approved_at` TIMESTAMP NULL COMMENT 'When order was approved by client',
  `completed_at` TIMESTAMP NULL COMMENT 'When order was completed',
  `metadata` JSON COMMENT 'Order-specific metadata and settings',
  `created_by` INT NOT NULL COMMENT 'User who created the order',
  `updated_by` INT COMMENT 'User who last updated the order',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` TIMESTAMP NULL COMMENT 'Soft delete timestamp',
  
  -- Foreign key constraints
  FOREIGN KEY (`tenant_id`) REFERENCES `cflex_tenants`(`id`) ON DELETE RESTRICT,
  FOREIGN KEY (`project_id`) REFERENCES `cflex_projects`(`id`) ON DELETE CASCADE,
  
  -- Indexes for performance
  INDEX `idx_order_status` (`status`, `tenant_id`),
  INDEX `idx_order_assigned` (`assigned_to`, `status`),
  INDEX `idx_order_priority` (`priority`, `due_date`),
  INDEX `idx_order_project` (`project_id`, `status`),
  INDEX `idx_order_tenant` (`tenant_id`, `status`, `created_at`),
  INDEX `idx_order_number` (`order_number`, `tenant_id`),
  INDEX `idx_order_product_type` (`product_type`, `status`),
  INDEX `idx_order_dates` (`due_date`, `status`, `priority`),
  INDEX `idx_order_soft_delete` (`deleted_at`),
  
  -- Unique constraint for order numbers within tenant
  UNIQUE KEY `uk_order_number_tenant` (`order_number`, `tenant_id`, `deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual orders within projects';

-- =====================================================
-- Table: cflex_order_status_history
-- Purpose: Audit trail for order status changes
-- Based on: ERPNext workflow history patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_order_status_history` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `order_id` INT NOT NULL COMMENT 'Reference to the order',
  `from_status` VARCHAR(50) COMMENT 'Previous status (NULL for initial status)',
  `to_status` VARCHAR(50) NOT NULL COMMENT 'New status',
  `changed_by` INT NOT NULL COMMENT 'User who made the status change',
  `change_reason` TEXT COMMENT 'Reason for status change',
  `metadata` JSON COMMENT 'Additional context: time spent, notes, etc.',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Foreign key constraints
  FOREIGN KEY (`order_id`) REFERENCES `cflex_orders`(`id`) ON DELETE CASCADE,
  
  -- Indexes for performance
  INDEX `idx_status_history_order` (`order_id`, `created_at`),
  INDEX `idx_status_history_user` (`changed_by`, `created_at`),
  INDEX `idx_status_history_status` (`to_status`, `created_at`),
  INDEX `idx_status_history_timeline` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit trail for order status changes';

-- =====================================================
-- Validation and Constraints
-- =====================================================

-- Ensure JSON fields are valid
ALTER TABLE `cflex_projects`
ADD CONSTRAINT `chk_project_metadata_valid`
CHECK (JSON_VALID(`metadata`));

ALTER TABLE `cflex_orders`
ADD CONSTRAINT `chk_order_dimensions_valid`
CHECK (JSON_VALID(`dimensions`));

ALTER TABLE `cflex_orders`
ADD CONSTRAINT `chk_order_specifications_valid`
CHECK (JSON_VALID(`specifications`));

ALTER TABLE `cflex_orders`
ADD CONSTRAINT `chk_order_metadata_valid`
CHECK (JSON_VALID(`metadata`));

ALTER TABLE `cflex_order_status_history`
ADD CONSTRAINT `chk_status_history_metadata_valid`
CHECK (JSON_VALID(`metadata`));

-- Business logic constraints
ALTER TABLE `cflex_orders`
ADD CONSTRAINT `chk_revision_count_positive`
CHECK (`revision_count` >= 0);

ALTER TABLE `cflex_orders`
ADD CONSTRAINT `chk_max_revisions_positive`
CHECK (`max_revisions` > 0);

ALTER TABLE `cflex_orders`
ADD CONSTRAINT `chk_revision_count_within_max`
CHECK (`revision_count` <= `max_revisions`);

-- Price constraints
ALTER TABLE `cflex_projects`
ADD CONSTRAINT `chk_project_estimated_total_positive`
CHECK (`estimated_total` >= 0);

ALTER TABLE `cflex_projects`
ADD CONSTRAINT `chk_project_actual_total_positive`
CHECK (`actual_total` >= 0);

ALTER TABLE `cflex_orders`
ADD CONSTRAINT `chk_order_estimated_price_positive`
CHECK (`estimated_price` IS NULL OR `estimated_price` >= 0);

ALTER TABLE `cflex_orders`
ADD CONSTRAINT `chk_order_final_price_positive`
CHECK (`final_price` IS NULL OR `final_price` >= 0);

-- =====================================================
-- Triggers for Audit Trail
-- =====================================================

-- Trigger to automatically log status changes
DELIMITER $$

CREATE TRIGGER `tr_order_status_change`
AFTER UPDATE ON `cflex_orders`
FOR EACH ROW
BEGIN
  -- Only log if status actually changed
  IF OLD.status != NEW.status THEN
    INSERT INTO `cflex_order_status_history`
    (`order_id`, `from_status`, `to_status`, `changed_by`, `change_reason`, `metadata`, `created_at`)
    VALUES
    (NEW.id, OLD.status, NEW.status, NEW.updated_by,
     CONCAT('Status changed from ', OLD.status, ' to ', NEW.status),
     JSON_OBJECT(
       'old_assigned_to', OLD.assigned_to,
       'new_assigned_to', NEW.assigned_to,
       'priority', NEW.priority,
       'revision_count', NEW.revision_count
     ),
     NOW());
  END IF;
END$$

DELIMITER ;

-- =====================================================
-- Performance Optimization
-- =====================================================

-- Additional composite indexes for common query patterns
CREATE INDEX `idx_project_client_status_date` ON `cflex_projects` (`client_id`, `status`, `due_date`);
CREATE INDEX `idx_order_project_status_priority` ON `cflex_orders` (`project_id`, `status`, `priority`);
CREATE INDEX `idx_order_assigned_status_due` ON `cflex_orders` (`assigned_to`, `status`, `due_date`);

-- =====================================================
-- Migration Complete
-- =====================================================

-- Log migration completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`)
VALUES ('002_create_core_entities', 'completed', NOW())
ON DUPLICATE KEY UPDATE
  `status` = 'completed',
  `executed_at` = NOW();
