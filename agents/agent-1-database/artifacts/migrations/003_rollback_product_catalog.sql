-- =====================================================
-- CFlex Product Catalog Rollback
-- Rollback: 003_rollback_product_catalog.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-003
-- Created: 2025-08-23
-- =====================================================

-- Set UTF8MB4 for consistency
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- ROLLBACK PROCEDURE
-- WARNING: This will remove all product catalog data
-- and associated configurations. Use with extreme caution.
-- =====================================================

-- Log rollback initiation
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('003_rollback_product_catalog', 'started', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'started', 
  `executed_at` = NOW();

-- =====================================================
-- Step 1: Drop Additional Indexes
-- =====================================================

-- Drop performance optimization indexes
DROP INDEX IF EXISTS `idx_category_parent_active_sort` ON `cflex_product_categories`;
DROP INDEX IF EXISTS `idx_product_category_type_active` ON `cflex_products`;
DROP INDEX IF EXISTS `idx_variant_product_type_active` ON `cflex_product_variants`;

-- =====================================================
-- Step 2: Remove Check Constraints
-- =====================================================

-- Remove JSON validation constraints
ALTER TABLE `cflex_product_categories` DROP CONSTRAINT IF EXISTS `chk_category_metadata_valid`;
ALTER TABLE `cflex_products` DROP CONSTRAINT IF EXISTS `chk_product_allowed_file_types_valid`;
ALTER TABLE `cflex_products` DROP CONSTRAINT IF EXISTS `chk_product_dimension_constraints_valid`;
ALTER TABLE `cflex_products` DROP CONSTRAINT IF EXISTS `chk_product_metadata_valid`;
ALTER TABLE `cflex_product_variants` DROP CONSTRAINT IF EXISTS `chk_variant_metadata_valid`;

-- Remove business logic constraints
ALTER TABLE `cflex_products` DROP CONSTRAINT IF EXISTS `chk_product_base_price_positive`;
ALTER TABLE `cflex_products` DROP CONSTRAINT IF EXISTS `chk_product_price_per_unit_positive`;
ALTER TABLE `cflex_products` DROP CONSTRAINT IF EXISTS `chk_product_max_file_size_positive`;
ALTER TABLE `cflex_products` DROP CONSTRAINT IF EXISTS `chk_product_processing_time_positive`;
ALTER TABLE `cflex_product_variants` DROP CONSTRAINT IF EXISTS `chk_variant_price_modifier_positive`;

-- =====================================================
-- Step 3: Drop Foreign Key Constraints
-- =====================================================

-- Drop foreign key constraints to avoid dependency issues
ALTER TABLE `cflex_products` DROP FOREIGN KEY IF EXISTS `cflex_products_ibfk_1`;
ALTER TABLE `cflex_product_variants` DROP FOREIGN KEY IF EXISTS `cflex_product_variants_ibfk_1`;
ALTER TABLE `cflex_product_categories` DROP FOREIGN KEY IF EXISTS `cflex_product_categories_ibfk_1`;

-- =====================================================
-- Step 4: Backup Data (Optional)
-- Create backup tables before dropping
-- =====================================================

-- Backup product categories data
CREATE TABLE IF NOT EXISTS `cflex_product_categories_backup_003` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_product_categories`;

-- Backup products data
CREATE TABLE IF NOT EXISTS `cflex_products_backup_003` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_products`;

-- Backup product variants data
CREATE TABLE IF NOT EXISTS `cflex_product_variants_backup_003` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_product_variants`;

-- =====================================================
-- Step 5: Drop Tables
-- Order matters due to foreign key dependencies
-- =====================================================

-- Drop dependent tables first
DROP TABLE IF EXISTS `cflex_product_variants`;
DROP TABLE IF EXISTS `cflex_products`;

-- Drop main categories table
DROP TABLE IF EXISTS `cflex_product_categories`;

-- =====================================================
-- Step 6: Clean Up Migration Log
-- =====================================================

-- Log rollback completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('003_rollback_product_catalog', 'completed', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'completed', 
  `executed_at` = NOW();

-- =====================================================
-- Rollback Complete
-- =====================================================

-- Display rollback summary
SELECT 
  'Product Catalog Rollback Completed' as status,
  NOW() as completed_at,
  'Backup tables created: cflex_product_categories_backup_003, cflex_products_backup_003, cflex_product_variants_backup_003' as note;

-- =====================================================
-- RECOVERY INSTRUCTIONS
-- =====================================================

/*
To recover from this rollback:

1. Re-run the forward migration:
   SOURCE agents/agent-1-database/artifacts/migrations/003_create_product_catalog.sql;

2. If you need to restore data from backup:
   INSERT INTO cflex_product_categories SELECT id, name, slug, parent_id, description, sort_order, is_active, metadata, created_at, updated_at 
   FROM cflex_product_categories_backup_003;
   
   INSERT INTO cflex_products SELECT id, category_id, name, slug, description, product_type, pricing_type, base_price, price_per_unit, unit_type, has_variants, requires_design, max_file_size, allowed_file_types, dimension_constraints, processing_time_hours, is_active, metadata, created_at, updated_at, deleted_at 
   FROM cflex_products_backup_003;
   
   INSERT INTO cflex_product_variants SELECT id, product_id, name, variant_type, value, price_modifier, modifier_type, is_default, sort_order, is_active, metadata, created_at, updated_at 
   FROM cflex_product_variants_backup_003;

3. Clean up backup tables when no longer needed:
   DROP TABLE cflex_product_categories_backup_003;
   DROP TABLE cflex_products_backup_003;
   DROP TABLE cflex_product_variants_backup_003;
*/
