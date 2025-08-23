-- =====================================================
-- CFlex Performance Optimization Rollback
-- Rollback: 006_rollback_performance_indexes.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-006
-- Created: 2025-08-23
-- =====================================================

-- Set UTF8MB4 for consistency
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- ROLLBACK PROCEDURE
-- WARNING: This will remove all performance optimizations
-- and may significantly impact query performance.
-- =====================================================

-- Log rollback initiation
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('006_rollback_performance_indexes', 'started', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'started', 
  `executed_at` = NOW();

-- =====================================================
-- Step 1: Drop Stored Procedures
-- =====================================================

DROP PROCEDURE IF EXISTS `sp_analyze_query_performance`;
DROP PROCEDURE IF EXISTS `sp_check_index_effectiveness`;

-- =====================================================
-- Step 2: Drop Performance Views
-- =====================================================

DROP VIEW IF EXISTS `v_index_usage_analysis`;
DROP VIEW IF EXISTS `v_query_performance_monitor`;

-- =====================================================
-- Step 3: Drop Full-Text Indexes
-- =====================================================

-- Drop full-text search indexes
ALTER TABLE `cflex_products` DROP INDEX IF EXISTS `name`;
ALTER TABLE `cflex_orders` DROP INDEX IF EXISTS `title`;
ALTER TABLE `cflex_projects` DROP INDEX IF EXISTS `name`;

-- =====================================================
-- Step 4: Drop Partial Indexes
-- =====================================================

-- Drop partial indexes for specific use cases
DROP INDEX IF EXISTS `idx_orders_overdue` ON `cflex_orders`;
DROP INDEX IF EXISTS `idx_files_pending_processing` ON `cflex_file_uploads`;
DROP INDEX IF EXISTS `idx_user_tenants_active` ON `cflex_user_tenants`;
DROP INDEX IF EXISTS `idx_tasks_urgent` ON `cflex_tasks`;

-- =====================================================
-- Step 5: Drop Covering Indexes
-- =====================================================

-- Drop covering indexes for read-heavy workloads
DROP INDEX IF EXISTS `idx_orders_summary_covering` ON `cflex_orders`;
DROP INDEX IF EXISTS `idx_projects_summary_covering` ON `cflex_projects`;
DROP INDEX IF EXISTS `idx_tasks_queue_covering` ON `cflex_tasks`;
DROP INDEX IF EXISTS `idx_files_listing_covering` ON `cflex_file_uploads`;

-- =====================================================
-- Step 6: Drop Composite Indexes
-- =====================================================

-- Drop composite indexes for complex queries
DROP INDEX IF EXISTS `idx_orders_active_priority_due` ON `cflex_orders`;
DROP INDEX IF EXISTS `idx_tasks_ready_priority_created` ON `cflex_tasks`;
DROP INDEX IF EXISTS `idx_files_order_type_active` ON `cflex_file_uploads`;
DROP INDEX IF EXISTS `idx_products_category_type_active` ON `cflex_products`;
DROP INDEX IF EXISTS `idx_user_tenants_user_status` ON `cflex_user_tenants`;

-- =====================================================
-- Step 7: Drop Critical Multi-Tenant Indexes
-- =====================================================

-- Drop tenant-aware query indexes
DROP INDEX IF EXISTS `idx_projects_tenant_status_created` ON `cflex_projects`;
DROP INDEX IF EXISTS `idx_orders_tenant_status_created` ON `cflex_orders`;
DROP INDEX IF EXISTS `idx_files_tenant_type_created` ON `cflex_file_uploads`;
DROP INDEX IF EXISTS `idx_tasks_tenant_status_created` ON `cflex_tasks`;

-- Drop staff task query indexes
DROP INDEX IF EXISTS `idx_orders_assigned_status_due` ON `cflex_orders`;
DROP INDEX IF EXISTS `idx_tasks_assigned_status_due` ON `cflex_tasks`;

-- Drop client order query indexes
DROP INDEX IF EXISTS `idx_projects_client_status_updated` ON `cflex_projects`;
DROP INDEX IF EXISTS `idx_projects_client_tenant_status` ON `cflex_projects`;

-- Drop file processing query indexes
DROP INDEX IF EXISTS `idx_files_processing_storage` ON `cflex_file_uploads`;
DROP INDEX IF EXISTS `idx_files_processing_created` ON `cflex_file_uploads`;

-- Drop audit trail query indexes
DROP INDEX IF EXISTS `idx_status_history_order_created` ON `cflex_order_status_history`;

-- =====================================================
-- Step 8: Backup Performance Data
-- =====================================================

-- Backup performance benchmarks data
CREATE TABLE IF NOT EXISTS `cflex_performance_benchmarks_backup_006` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_performance_benchmarks`;

-- =====================================================
-- Step 9: Drop Performance Tables
-- =====================================================

-- Drop performance benchmark table
DROP TABLE IF EXISTS `cflex_performance_benchmarks`;

-- =====================================================
-- Step 10: Clean Up Migration Log
-- =====================================================

-- Log rollback completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('006_rollback_performance_indexes', 'completed', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'completed', 
  `executed_at` = NOW();

-- =====================================================
-- Rollback Complete
-- =====================================================

-- Display rollback summary
SELECT 
  'Performance Optimization Rollback Completed' as status,
  NOW() as completed_at,
  'WARNING: Query performance may be significantly degraded' as warning,
  'Backup table created: cflex_performance_benchmarks_backup_006' as note;

-- =====================================================
-- RECOVERY INSTRUCTIONS
-- =====================================================

/*
To recover from this rollback:

1. Re-run the forward migration:
   SOURCE agents/agent-1-database/artifacts/migrations/006_create_performance_indexes.sql;

2. If you need to restore benchmark data:
   INSERT INTO cflex_performance_benchmarks SELECT id, benchmark_name, query_type, execution_time_ms, rows_affected, query_hash, created_at 
   FROM cflex_performance_benchmarks_backup_006;

3. Clean up backup table when no longer needed:
   DROP TABLE cflex_performance_benchmarks_backup_006;

4. IMPORTANT: After rollback, expect significant performance degradation:
   - Multi-tenant queries may be slow
   - Dashboard loading may take >1 second
   - File processing queries may timeout
   - Task queue operations may be sluggish

5. Monitor query performance and consider re-applying optimizations:
   - Enable slow query log
   - Monitor for queries >100ms
   - Consider selective index recreation based on usage patterns
*/
