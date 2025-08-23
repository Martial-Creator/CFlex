-- =====================================================
-- CFlex Task Queue and Workflow Management
-- Migration: 005_create_task_workflow.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-005
-- Created: 2025-08-23
-- Based on: Twenty task management and Ever-Gauzy workflow patterns
-- =====================================================

-- Set UTF8MB4 for bilingual support (English/Nepali)
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- Table: cflex_task_definitions
-- Purpose: Task templates and workflow definitions
-- Based on: Twenty task templates and Ever-Gauzy workflow patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_task_definitions` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL COMMENT 'Task template name',
  `description` TEXT COMMENT 'Detailed task description',
  `task_type` ENUM('design', 'review', 'production', 'quality_check', 'communication') NOT NULL COMMENT 'Task classification',
  `estimated_duration_hours` INT DEFAULT 2 COMMENT 'Estimated time to complete in hours',
  `required_skills` JSON COMMENT 'Required skills: ["design", "printing", "customer_service"]',
  `prerequisite_tasks` JSON COMMENT 'Task IDs that must complete first',
  `auto_assign_rules` JSON COMMENT 'Rules for automatic task assignment',
  `is_active` BOOLEAN DEFAULT TRUE COMMENT 'Template availability status',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Indexes for performance
  INDEX `idx_task_def_type` (`task_type`, `is_active`),
  INDEX `idx_task_def_active` (`is_active`, `created_at`),
  INDEX `idx_task_def_duration` (`estimated_duration_hours`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Task templates and workflow definitions';

-- =====================================================
-- Table: cflex_tasks
-- Purpose: Individual task instances
-- Based on: Twenty task management with workflow states
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_tasks` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `tenant_id` INT NOT NULL COMMENT 'Multi-tenant isolation',
  `order_id` INT NOT NULL COMMENT 'Associated order',
  `task_definition_id` INT NOT NULL COMMENT 'Task template reference',
  `title` VARCHAR(255) NOT NULL COMMENT 'Task title/name',
  `description` TEXT COMMENT 'Detailed task description',
  `status` ENUM('pending', 'ready', 'claimed', 'in_progress', 'review', 'completed', 'blocked', 'cancelled') DEFAULT 'pending' COMMENT 'Task workflow status',
  `priority` ENUM('low', 'normal', 'high', 'urgent') DEFAULT 'normal' COMMENT 'Task priority level',
  `assigned_to` INT COMMENT 'Staff member assigned to this task',
  `assigned_at` TIMESTAMP NULL COMMENT 'When task was assigned',
  `started_at` TIMESTAMP NULL COMMENT 'When work on task began',
  `completed_at` TIMESTAMP NULL COMMENT 'When task was completed',
  `due_date` DATETIME COMMENT 'Task due date and time',
  `estimated_hours` INT COMMENT 'Estimated hours for this specific task',
  `actual_hours` DECIMAL(5,2) COMMENT 'Actual hours spent on task',
  `blocked_reason` TEXT COMMENT 'Reason why task is blocked',
  `completion_notes` TEXT COMMENT 'Notes added upon task completion',
  `metadata` JSON COMMENT 'Task-specific metadata and configuration',
  `created_by` INT NOT NULL COMMENT 'User who created the task',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Foreign key constraints
  FOREIGN KEY (`tenant_id`) REFERENCES `cflex_tenants`(`id`) ON DELETE RESTRICT,
  FOREIGN KEY (`order_id`) REFERENCES `cflex_orders`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`task_definition_id`) REFERENCES `cflex_task_definitions`(`id`) ON DELETE RESTRICT,
  -- Note: assigned_to and created_by reference Rise CRM users table - handled via application logic
  
  -- Indexes for performance
  INDEX `idx_task_status` (`status`, `priority`, `due_date`),
  INDEX `idx_task_assigned` (`assigned_to`, `status`),
  INDEX `idx_task_order` (`order_id`, `status`),
  INDEX `idx_task_tenant` (`tenant_id`, `status`, `created_at`),
  INDEX `idx_task_definition` (`task_definition_id`, `status`),
  INDEX `idx_task_priority_due` (`priority`, `due_date`, `status`),
  INDEX `idx_task_dates` (`due_date`, `status`, `priority`),
  INDEX `idx_task_workflow` (`status`, `assigned_to`, `due_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual task instances with workflow management';

-- =====================================================
-- Validation and Constraints
-- =====================================================

-- Ensure JSON fields are valid
ALTER TABLE `cflex_task_definitions` 
ADD CONSTRAINT `chk_task_def_required_skills_valid` 
CHECK (JSON_VALID(`required_skills`));

ALTER TABLE `cflex_task_definitions` 
ADD CONSTRAINT `chk_task_def_prerequisite_tasks_valid` 
CHECK (JSON_VALID(`prerequisite_tasks`));

ALTER TABLE `cflex_task_definitions` 
ADD CONSTRAINT `chk_task_def_auto_assign_rules_valid` 
CHECK (JSON_VALID(`auto_assign_rules`));

ALTER TABLE `cflex_tasks` 
ADD CONSTRAINT `chk_task_metadata_valid` 
CHECK (JSON_VALID(`metadata`));

-- Business logic constraints
ALTER TABLE `cflex_task_definitions` 
ADD CONSTRAINT `chk_task_def_estimated_duration_positive` 
CHECK (`estimated_duration_hours` > 0);

ALTER TABLE `cflex_tasks` 
ADD CONSTRAINT `chk_task_estimated_hours_positive` 
CHECK (`estimated_hours` IS NULL OR `estimated_hours` > 0);

ALTER TABLE `cflex_tasks` 
ADD CONSTRAINT `chk_task_actual_hours_positive` 
CHECK (`actual_hours` IS NULL OR `actual_hours` >= 0);

-- =====================================================
-- Sample Data - Task Definitions
-- =====================================================

INSERT INTO `cflex_task_definitions` (`name`, `description`, `task_type`, `estimated_duration_hours`, `required_skills`, `prerequisite_tasks`, `auto_assign_rules`, `is_active`) VALUES

('Initial Design Creation', 'Create initial design based on client requirements and uploaded files', 'design', 4, 
 JSON_ARRAY('design', 'adobe_creative_suite', 'typography'), 
 JSON_ARRAY(), 
 JSON_OBJECT('skill_match_required', true, 'workload_balance', true), 
 TRUE),

('Design Review', 'Review design for quality, accuracy, and client requirements compliance', 'review', 1, 
 JSON_ARRAY('design', 'quality_control'), 
 JSON_ARRAY(1), 
 JSON_OBJECT('senior_designer_required', true), 
 TRUE),

('Client Approval Process', 'Send design to client for approval and handle feedback', 'communication', 2, 
 JSON_ARRAY('customer_service', 'communication'), 
 JSON_ARRAY(2), 
 JSON_OBJECT('customer_service_team', true), 
 TRUE),

('Design Revision', 'Make requested changes to design based on client feedback', 'design', 2, 
 JSON_ARRAY('design', 'adobe_creative_suite'), 
 JSON_ARRAY(3), 
 JSON_OBJECT('original_designer_preferred', true), 
 TRUE),

('Production Preparation', 'Prepare files for production, check specifications and quality', 'production', 1, 
 JSON_ARRAY('production', 'file_preparation'), 
 JSON_ARRAY(2), 
 JSON_OBJECT('production_team_required', true), 
 TRUE),

('Quality Check', 'Final quality check before delivery to client', 'quality_check', 1, 
 JSON_ARRAY('quality_control', 'attention_to_detail'), 
 JSON_ARRAY(5), 
 JSON_OBJECT('quality_team_required', true), 
 TRUE);

-- =====================================================
-- Workflow Views for Task Management
-- =====================================================

-- View for task queue by priority and due date
CREATE VIEW `v_task_queue` AS
SELECT 
  t.id,
  t.title,
  t.status,
  t.priority,
  t.due_date,
  t.estimated_hours,
  t.assigned_to,
  td.task_type,
  td.required_skills,
  o.order_number,
  o.title as order_title,
  CASE 
    WHEN t.due_date < NOW() THEN 'overdue'
    WHEN t.due_date < DATE_ADD(NOW(), INTERVAL 24 HOUR) THEN 'due_soon'
    ELSE 'on_track'
  END as urgency_status,
  TIMESTAMPDIFF(HOUR, t.created_at, NOW()) as hours_in_queue
FROM cflex_tasks t
JOIN cflex_task_definitions td ON t.task_definition_id = td.id
JOIN cflex_orders o ON t.order_id = o.id
WHERE t.status IN ('pending', 'ready', 'claimed', 'in_progress')
ORDER BY 
  FIELD(t.priority, 'urgent', 'high', 'normal', 'low'),
  t.due_date ASC,
  t.created_at ASC;

-- View for staff workload analysis
CREATE VIEW `v_staff_workload` AS
SELECT 
  t.assigned_to,
  COUNT(*) as active_tasks,
  SUM(t.estimated_hours) as estimated_hours_total,
  SUM(CASE WHEN t.status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_tasks,
  SUM(CASE WHEN t.due_date < NOW() THEN 1 ELSE 0 END) as overdue_tasks,
  AVG(t.actual_hours) as avg_actual_hours
FROM cflex_tasks t
WHERE t.assigned_to IS NOT NULL 
  AND t.status IN ('claimed', 'in_progress', 'review')
GROUP BY t.assigned_to;

-- =====================================================
-- Triggers for Task Workflow Management
-- =====================================================

DELIMITER $$

-- Trigger to automatically set timestamps based on status changes
CREATE TRIGGER `tr_task_status_timestamps`
BEFORE UPDATE ON `cflex_tasks`
FOR EACH ROW
BEGIN
  -- Set assigned_at when task is assigned
  IF OLD.assigned_to IS NULL AND NEW.assigned_to IS NOT NULL THEN
    SET NEW.assigned_at = NOW();
  END IF;

  -- Set started_at when task status changes to in_progress
  IF OLD.status != 'in_progress' AND NEW.status = 'in_progress' THEN
    SET NEW.started_at = NOW();
  END IF;

  -- Set completed_at when task status changes to completed
  IF OLD.status != 'completed' AND NEW.status = 'completed' THEN
    SET NEW.completed_at = NOW();
  END IF;

  -- Clear timestamps if task is reset to earlier status
  IF NEW.status IN ('pending', 'ready') THEN
    SET NEW.started_at = NULL;
    SET NEW.completed_at = NULL;
  END IF;

  IF NEW.status IN ('pending', 'ready', 'claimed') THEN
    SET NEW.completed_at = NULL;
  END IF;
END$$

-- Trigger to create tasks automatically when order status changes
CREATE TRIGGER `tr_order_status_create_tasks`
AFTER UPDATE ON `cflex_orders`
FOR EACH ROW
BEGIN
  -- Create initial design task when order is submitted
  IF OLD.status != 'submitted' AND NEW.status = 'submitted' THEN
    INSERT INTO `cflex_tasks`
    (`tenant_id`, `order_id`, `task_definition_id`, `title`, `description`, `status`, `priority`, `due_date`, `estimated_hours`, `created_by`)
    SELECT
      NEW.tenant_id,
      NEW.id,
      td.id,
      CONCAT(td.name, ' - ', NEW.title),
      CONCAT('Auto-created task for order: ', NEW.order_number),
      'ready',
      CASE WHEN NEW.priority = 'urgent' THEN 'urgent' ELSE 'normal' END,
      DATE_ADD(NOW(), INTERVAL td.estimated_duration_hours HOUR),
      td.estimated_duration_hours,
      NEW.updated_by
    FROM `cflex_task_definitions` td
    WHERE td.name = 'Initial Design Creation' AND td.is_active = TRUE
    LIMIT 1;
  END IF;
END$$

DELIMITER ;

-- =====================================================
-- Performance Optimization
-- =====================================================

-- Additional composite indexes for common query patterns
CREATE INDEX `idx_task_status_priority_due` ON `cflex_tasks` (`status`, `priority`, `due_date`);
CREATE INDEX `idx_task_assigned_status_due` ON `cflex_tasks` (`assigned_to`, `status`, `due_date`);
CREATE INDEX `idx_task_order_status_created` ON `cflex_tasks` (`order_id`, `status`, `created_at`);
CREATE INDEX `idx_task_tenant_status_priority` ON `cflex_tasks` (`tenant_id`, `status`, `priority`);

-- =====================================================
-- Migration Complete
-- =====================================================

-- Log migration completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`)
VALUES ('005_create_task_workflow', 'completed', NOW())
ON DUPLICATE KEY UPDATE
  `status` = 'completed',
  `executed_at` = NOW();
