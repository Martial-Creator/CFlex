-- =====================================================
-- CFlex Multi-Tenant Infrastructure Rollback
-- Rollback: 001_rollback_tenant_infrastructure.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-001
-- Created: 2025-08-23
-- =====================================================

-- Set UTF8MB4 for consistency
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- ROLLBACK PROCEDURE
-- WARNING: This will remove all tenant infrastructure
-- and associated data. Use with extreme caution.
-- =====================================================

-- Log rollback initiation
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('001_rollback_tenant_infrastructure', 'started', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'started', 
  `executed_at` = NOW();

-- =====================================================
-- Step 1: Remove Foreign Key Dependencies
-- =====================================================

-- Drop foreign key constraints first to avoid dependency issues
ALTER TABLE `cflex_user_tenants` DROP FOREIGN KEY IF EXISTS `cflex_user_tenants_ibfk_1`;

-- =====================================================
-- Step 2: Drop Indexes
-- =====================================================

-- Drop additional indexes created for performance
DROP INDEX IF EXISTS `idx_tenant_subdomain_status` ON `cflex_tenants`;
DROP INDEX IF EXISTS `idx_user_tenant_user_status` ON `cflex_user_tenants`;

-- =====================================================
-- Step 3: Drop Check Constraints
-- =====================================================

-- Remove JSON validation constraints
ALTER TABLE `cflex_tenants` DROP CONSTRAINT IF EXISTS `chk_tenant_config_valid`;
ALTER TABLE `cflex_user_tenants` DROP CONSTRAINT IF EXISTS `chk_roles_valid`;
ALTER TABLE `cflex_user_tenants` DROP CONSTRAINT IF EXISTS `chk_permissions_valid`;

-- =====================================================
-- Step 4: Backup Data (Optional)
-- Create backup tables before dropping
-- =====================================================

-- Backup tenant data
CREATE TABLE IF NOT EXISTS `cflex_tenants_backup_001` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_tenants`;

-- Backup user-tenant relationships
CREATE TABLE IF NOT EXISTS `cflex_user_tenants_backup_001` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_user_tenants`;

-- =====================================================
-- Step 5: Drop Tables
-- Order matters due to foreign key dependencies
-- =====================================================

-- Drop dependent table first
DROP TABLE IF EXISTS `cflex_user_tenants`;

-- Drop main tenant table
DROP TABLE IF EXISTS `cflex_tenants`;

-- =====================================================
-- Step 6: Clean Up Migration Log
-- =====================================================

-- Remove migration entries (optional - keep for audit trail)
-- DELETE FROM `cflex_migration_log` WHERE `migration_name` LIKE '001_%tenant_infrastructure%';

-- Log rollback completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('001_rollback_tenant_infrastructure', 'completed', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'completed', 
  `executed_at` = NOW();

-- =====================================================
-- Rollback Complete
-- =====================================================

-- Display rollback summary
SELECT 
  'Tenant Infrastructure Rollback Completed' as status,
  NOW() as completed_at,
  'Backup tables created: cflex_tenants_backup_001, cflex_user_tenants_backup_001' as note;

-- =====================================================
-- RECOVERY INSTRUCTIONS
-- =====================================================

/*
To recover from this rollback:

1. Re-run the forward migration:
   SOURCE agents/agent-1-database/artifacts/migrations/001_create_tenant_infrastructure.sql;

2. If you need to restore data from backup:
   INSERT INTO cflex_tenants SELECT id, subdomain, type, name, config, status, created_at, updated_at 
   FROM cflex_tenants_backup_001;
   
   INSERT INTO cflex_user_tenants SELECT id, user_id, tenant_id, roles, permissions, status, created_at, updated_at 
   FROM cflex_user_tenants_backup_001;

3. Clean up backup tables when no longer needed:
   DROP TABLE cflex_tenants_backup_001;
   DROP TABLE cflex_user_tenants_backup_001;
*/
