-- =====================================================
-- CFlex Task Queue and Workflow Rollback
-- Rollback: 005_rollback_task_workflow.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-005
-- Created: 2025-08-23
-- =====================================================

-- Set UTF8MB4 for consistency
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- ROLLBACK PROCEDURE
-- WARNING: This will remove all task workflow data
-- and associated configurations. Use with extreme caution.
-- =====================================================

-- Log rollback initiation
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('005_rollback_task_workflow', 'started', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'started', 
  `executed_at` = NOW();

-- =====================================================
-- Step 1: Drop Views
-- =====================================================

DROP VIEW IF EXISTS `v_task_queue`;
DROP VIEW IF EXISTS `v_staff_workload`;

-- =====================================================
-- Step 2: Drop Triggers
-- =====================================================

DROP TRIGGER IF EXISTS `tr_task_status_timestamps`;
DROP TRIGGER IF EXISTS `tr_order_status_create_tasks`;

-- =====================================================
-- Step 3: Drop Additional Indexes
-- =====================================================

-- Drop performance optimization indexes
DROP INDEX IF EXISTS `idx_task_status_priority_due` ON `cflex_tasks`;
DROP INDEX IF EXISTS `idx_task_assigned_status_due` ON `cflex_tasks`;
DROP INDEX IF EXISTS `idx_task_order_status_created` ON `cflex_tasks`;
DROP INDEX IF EXISTS `idx_task_tenant_status_priority` ON `cflex_tasks`;

-- =====================================================
-- Step 4: Remove Check Constraints
-- =====================================================

-- Remove JSON validation constraints
ALTER TABLE `cflex_task_definitions` DROP CONSTRAINT IF EXISTS `chk_task_def_required_skills_valid`;
ALTER TABLE `cflex_task_definitions` DROP CONSTRAINT IF EXISTS `chk_task_def_prerequisite_tasks_valid`;
ALTER TABLE `cflex_task_definitions` DROP CONSTRAINT IF EXISTS `chk_task_def_auto_assign_rules_valid`;
ALTER TABLE `cflex_tasks` DROP CONSTRAINT IF EXISTS `chk_task_metadata_valid`;

-- Remove business logic constraints
ALTER TABLE `cflex_task_definitions` DROP CONSTRAINT IF EXISTS `chk_task_def_estimated_duration_positive`;
ALTER TABLE `cflex_tasks` DROP CONSTRAINT IF EXISTS `chk_task_estimated_hours_positive`;
ALTER TABLE `cflex_tasks` DROP CONSTRAINT IF EXISTS `chk_task_actual_hours_positive`;

-- =====================================================
-- Step 5: Drop Foreign Key Constraints
-- =====================================================

-- Drop foreign key constraints to avoid dependency issues
ALTER TABLE `cflex_tasks` DROP FOREIGN KEY IF EXISTS `cflex_tasks_ibfk_1`;
ALTER TABLE `cflex_tasks` DROP FOREIGN KEY IF EXISTS `cflex_tasks_ibfk_2`;
ALTER TABLE `cflex_tasks` DROP FOREIGN KEY IF EXISTS `cflex_tasks_ibfk_3`;

-- =====================================================
-- Step 6: Backup Data (Optional)
-- Create backup tables before dropping
-- =====================================================

-- Backup task definitions data
CREATE TABLE IF NOT EXISTS `cflex_task_definitions_backup_005` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_task_definitions`;

-- Backup tasks data
CREATE TABLE IF NOT EXISTS `cflex_tasks_backup_005` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_tasks`;

-- =====================================================
-- Step 7: Drop Tables
-- Order matters due to foreign key dependencies
-- =====================================================

-- Drop dependent table first
DROP TABLE IF EXISTS `cflex_tasks`;

-- Drop main task definitions table
DROP TABLE IF EXISTS `cflex_task_definitions`;

-- =====================================================
-- Step 8: Clean Up Migration Log
-- =====================================================

-- Log rollback completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('005_rollback_task_workflow', 'completed', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'completed', 
  `executed_at` = NOW();

-- =====================================================
-- Rollback Complete
-- =====================================================

-- Display rollback summary
SELECT 
  'Task Queue and Workflow Rollback Completed' as status,
  NOW() as completed_at,
  'Backup tables created: cflex_task_definitions_backup_005, cflex_tasks_backup_005' as note;

-- =====================================================
-- RECOVERY INSTRUCTIONS
-- =====================================================

/*
To recover from this rollback:

1. Re-run the forward migration:
   SOURCE agents/agent-1-database/artifacts/migrations/005_create_task_workflow.sql;

2. If you need to restore data from backup:
   INSERT INTO cflex_task_definitions SELECT id, name, description, task_type, estimated_duration_hours, required_skills, prerequisite_tasks, auto_assign_rules, is_active, created_at, updated_at 
   FROM cflex_task_definitions_backup_005;
   
   INSERT INTO cflex_tasks SELECT id, tenant_id, order_id, task_definition_id, title, description, status, priority, assigned_to, assigned_at, started_at, completed_at, due_date, estimated_hours, actual_hours, blocked_reason, completion_notes, metadata, created_by, created_at, updated_at 
   FROM cflex_tasks_backup_005;

3. Clean up backup tables when no longer needed:
   DROP TABLE cflex_task_definitions_backup_005;
   DROP TABLE cflex_tasks_backup_005;
*/
