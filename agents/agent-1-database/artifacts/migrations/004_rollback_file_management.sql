-- =====================================================
-- CFlex File Management Rollback
-- Rollback: 004_rollback_file_management.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-004
-- Created: 2025-08-23
-- =====================================================

-- Set UTF8MB4 for consistency
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- ROLLBACK PROCEDURE
-- WARNING: This will remove all file management data
-- and associated metadata. Use with extreme caution.
-- =====================================================

-- Log rollback initiation
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('004_rollback_file_management', 'started', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'started', 
  `executed_at` = NOW();

-- =====================================================
-- Step 1: Drop Views
-- =====================================================

DROP VIEW IF EXISTS `v_file_storage_stats`;
DROP VIEW IF EXISTS `v_file_processing_queue`;

-- =====================================================
-- Step 2: Drop Triggers
-- =====================================================

DROP TRIGGER IF EXISTS `tr_file_upload_create_version`;
DROP TRIGGER IF EXISTS `tr_file_processing_status_update`;

-- =====================================================
-- Step 3: Drop Additional Indexes
-- =====================================================

-- Drop performance optimization indexes
DROP INDEX IF EXISTS `idx_file_order_type_status` ON `cflex_file_uploads`;
DROP INDEX IF EXISTS `idx_file_tenant_storage_tier` ON `cflex_file_uploads`;
DROP INDEX IF EXISTS `idx_version_parent_type_number` ON `cflex_file_versions`;
DROP INDEX IF EXISTS `idx_annotation_file_type_status` ON `cflex_design_annotations`;

-- =====================================================
-- Step 4: Remove Check Constraints
-- =====================================================

-- Remove JSON validation constraints
ALTER TABLE `cflex_file_uploads` DROP CONSTRAINT IF EXISTS `chk_file_metadata_valid`;
ALTER TABLE `cflex_design_annotations` DROP CONSTRAINT IF EXISTS `chk_annotation_markup_data_valid`;

-- Remove business logic constraints
ALTER TABLE `cflex_file_uploads` DROP CONSTRAINT IF EXISTS `chk_file_size_positive`;
ALTER TABLE `cflex_design_annotations` DROP CONSTRAINT IF EXISTS `chk_annotation_x_coordinate_range`;
ALTER TABLE `cflex_design_annotations` DROP CONSTRAINT IF EXISTS `chk_annotation_y_coordinate_range`;
ALTER TABLE `cflex_file_versions` DROP CONSTRAINT IF EXISTS `chk_version_number_positive`;

-- =====================================================
-- Step 5: Drop Foreign Key Constraints
-- =====================================================

-- Drop foreign key constraints to avoid dependency issues
ALTER TABLE `cflex_file_uploads` DROP FOREIGN KEY IF EXISTS `cflex_file_uploads_ibfk_1`;
ALTER TABLE `cflex_file_uploads` DROP FOREIGN KEY IF EXISTS `cflex_file_uploads_ibfk_2`;
ALTER TABLE `cflex_file_versions` DROP FOREIGN KEY IF EXISTS `cflex_file_versions_ibfk_1`;
ALTER TABLE `cflex_file_versions` DROP FOREIGN KEY IF EXISTS `cflex_file_versions_ibfk_2`;
ALTER TABLE `cflex_design_annotations` DROP FOREIGN KEY IF EXISTS `cflex_design_annotations_ibfk_1`;
ALTER TABLE `cflex_design_annotations` DROP FOREIGN KEY IF EXISTS `cflex_design_annotations_ibfk_2`;

-- =====================================================
-- Step 6: Backup Data (Optional)
-- Create backup tables before dropping
-- =====================================================

-- Backup file uploads data
CREATE TABLE IF NOT EXISTS `cflex_file_uploads_backup_004` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_file_uploads`;

-- Backup file versions data
CREATE TABLE IF NOT EXISTS `cflex_file_versions_backup_004` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_file_versions`;

-- Backup design annotations data
CREATE TABLE IF NOT EXISTS `cflex_design_annotations_backup_004` AS 
SELECT *, NOW() as backup_created_at FROM `cflex_design_annotations`;

-- =====================================================
-- Step 7: Drop Tables
-- Order matters due to foreign key dependencies
-- =====================================================

-- Drop dependent tables first
DROP TABLE IF EXISTS `cflex_design_annotations`;
DROP TABLE IF EXISTS `cflex_file_versions`;

-- Drop main file uploads table
DROP TABLE IF EXISTS `cflex_file_uploads`;

-- =====================================================
-- Step 8: Clean Up Migration Log
-- =====================================================

-- Log rollback completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`) 
VALUES ('004_rollback_file_management', 'completed', NOW())
ON DUPLICATE KEY UPDATE 
  `status` = 'completed', 
  `executed_at` = NOW();

-- =====================================================
-- Rollback Complete
-- =====================================================

-- Display rollback summary
SELECT 
  'File Management Rollback Completed' as status,
  NOW() as completed_at,
  'Backup tables created: cflex_file_uploads_backup_004, cflex_file_versions_backup_004, cflex_design_annotations_backup_004' as note;

-- =====================================================
-- RECOVERY INSTRUCTIONS
-- =====================================================

/*
To recover from this rollback:

1. Re-run the forward migration:
   SOURCE agents/agent-1-database/artifacts/migrations/004_create_file_management.sql;

2. If you need to restore data from backup:
   INSERT INTO cflex_file_uploads SELECT id, tenant_id, order_id, uploaded_by, file_type, original_filename, stored_filename, file_path, file_size_bytes, mime_type, file_extension, checksum_md5, checksum_sha256, storage_tier, storage_location, virus_scan_status, virus_scan_at, processing_status, processed_at, metadata, is_active, created_at, updated_at, deleted_at 
   FROM cflex_file_uploads_backup_004;
   
   INSERT INTO cflex_file_versions SELECT id, parent_file_id, file_id, version_number, version_type, created_by, change_notes, created_at 
   FROM cflex_file_versions_backup_004;
   
   INSERT INTO cflex_design_annotations SELECT id, file_id, annotated_by, annotation_type, x_coordinate, y_coordinate, comment, markup_data, parent_annotation_id, status, created_at, updated_at 
   FROM cflex_design_annotations_backup_004;

3. Clean up backup tables when no longer needed:
   DROP TABLE cflex_file_uploads_backup_004;
   DROP TABLE cflex_file_versions_backup_004;
   DROP TABLE cflex_design_annotations_backup_004;
*/
