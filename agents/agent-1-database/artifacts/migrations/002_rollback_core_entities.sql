-- =====================================================
-- CFlex Core Business Entities Rollback
-- Rollback: 002_rollback_core_entities.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-002
-- Created: 2025-08-23
-- =====================================================

-- Set UTF8MB4 for consistency
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- ROLLBACK PROCEDURE
-- WARNING: This will remove all core business entities
-- and associated data. Use with extreme caution.
-- =====================================================

-- Log rollback initiation
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('002_rollback_core_entities', 'started', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'started', 
  `executed_at` = NOW();

-- =====================================================
-- Step 1: Drop Triggers
-- =====================================================

DROP TRIGGER IF EXISTS `tr_order_status_change`;

-- =====================================================
-- Step 2: Remove Check Constraints
-- =====================================================

-- Remove JSON validation constraints
ALTER TABLE `cflex_projects` DROP CONSTRAINT IF EXISTS `chk_project_metadata_valid`;
ALTER TABLE `cflex_orders` DROP CONSTRAINT IF EXISTS `chk_order_dimensions_valid`;
ALTER TABLE `cflex_orders` DROP CONSTRAINT IF EXISTS `chk_order_specifications_valid`;
ALTER TABLE `cflex_orders` DROP CONSTRAINT IF EXISTS `chk_order_metadata_valid`;
ALTER TABLE `cflex_order_status_history` DROP CONSTRAINT IF EXISTS `chk_status_history_metadata_valid`;

-- Remove business logic constraints
ALTER TABLE `cflex_orders` DROP CONSTRAINT IF EXISTS `chk_revision_count_positive`;
ALTER TABLE `cflex_orders` DROP CONSTRAINT IF EXISTS `chk_max_revisions_positive`;
ALTER TABLE `cflex_orders` DROP CONSTRAINT IF EXISTS `chk_revision_count_within_max`;

-- Remove price constraints
ALTER TABLE `cflex_projects` DROP CONSTRAINT IF EXISTS `chk_project_estimated_total_positive`;
ALTER TABLE `cflex_projects` DROP CONSTRAINT IF EXISTS `chk_project_actual_total_positive`;
ALTER TABLE `cflex_orders` DROP CONSTRAINT IF EXISTS `chk_order_estimated_price_positive`;
ALTER TABLE `cflex_orders` DROP CONSTRAINT IF EXISTS `chk_order_final_price_positive`;

-- =====================================================
-- Step 3: Drop Additional Indexes
-- =====================================================

-- Drop performance optimization indexes
DROP INDEX IF EXISTS `idx_project_client_status_date` ON `cflex_projects`;
DROP INDEX IF EXISTS `idx_order_project_status_priority` ON `cflex_orders`;
DROP INDEX IF EXISTS `idx_order_assigned_status_due` ON `cflex_orders`;

-- =====================================================
-- Step 4: Drop Foreign Key Constraints
-- =====================================================

-- Drop foreign key constraints to avoid dependency issues
ALTER TABLE `cflex_orders` DROP FOREIGN KEY IF EXISTS `cflex_orders_ibfk_1`;
ALTER TABLE `cflex_orders` DROP FOREIGN KEY IF EXISTS `cflex_orders_ibfk_2`;
ALTER TABLE `cflex_order_status_history` DROP FOREIGN KEY IF EXISTS `cflex_order_status_history_ibfk_1`;

-- =====================================================
-- Step 5: Backup Data (Optional)
-- Create backup tables before dropping
-- =====================================================

-- Backup projects data
CREATE TABLE IF NOT EXISTS `cflex_projects_backup_002` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_projects`;

-- Backup orders data
CREATE TABLE IF NOT EXISTS `cflex_orders_backup_002` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_orders`;

-- Backup status history data
CREATE TABLE IF NOT EXISTS `cflex_order_status_history_backup_002` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_order_status_history`;

-- =====================================================
-- Step 6: Drop Tables
-- Order matters due to foreign key dependencies
-- =====================================================

-- Drop dependent tables first
DROP TABLE IF EXISTS `cflex_order_status_history`;
DROP TABLE IF EXISTS `cflex_orders`;

-- Drop main projects table
DROP TABLE IF EXISTS `cflex_projects`;

-- =====================================================
-- Step 7: Clean Up Migration Log
-- =====================================================

-- Log rollback completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('002_rollback_core_entities', 'completed', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'completed', 
  `executed_at` = NOW();

-- =====================================================
-- Rollback Complete
-- =====================================================

-- Display rollback summary
SELECT 
  'Core Business Entities Rollback Completed' as status,
  NOW() as completed_at,
  'Backup tables created: cflex_projects_backup_002, cflex_orders_backup_002, cflex_order_status_history_backup_002' as note;

-- =====================================================
-- RECOVERY INSTRUCTIONS
-- =====================================================

/*
To recover from this rollback:

1. Re-run the forward migration:
   SOURCE agents/agent-1-database/artifacts/migrations/002_create_core_entities.sql;

2. If you need to restore data from backup:
   INSERT INTO cflex_projects SELECT id, tenant_id, project_number, name, client_id, client_type, status, priority, description, start_date, due_date, completion_date, estimated_total, actual_total, metadata, created_by, updated_by, created_at, updated_at, deleted_at 
   FROM cflex_projects_backup_002;
   
   INSERT INTO cflex_orders SELECT id, tenant_id, project_id, order_number, title, description, product_type, status, priority, assigned_to, dimensions, specifications, estimated_price, final_price, revision_count, max_revisions, due_date, claimed_at, approved_at, completed_at, metadata, created_by, updated_by, created_at, updated_at, deleted_at 
   FROM cflex_orders_backup_002;
   
   INSERT INTO cflex_order_status_history SELECT id, order_id, from_status, to_status, changed_by, change_reason, metadata, created_at 
   FROM cflex_order_status_history_backup_002;

3. Clean up backup tables when no longer needed:
   DROP TABLE cflex_projects_backup_002;
   DROP TABLE cflex_orders_backup_002;
   DROP TABLE cflex_order_status_history_backup_002;
*/
