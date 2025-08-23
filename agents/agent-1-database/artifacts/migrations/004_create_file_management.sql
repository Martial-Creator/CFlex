-- =====================================================
-- CFlex File Management and Version Control
-- Migration: 004_create_file_management.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-004
-- Created: 2025-08-23
-- Based on: Ever-Gauzy file handling patterns with version control
-- =====================================================

-- Set UTF8MB4 for bilingual support (English/Nepali)
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- Table: cflex_file_uploads
-- Purpose: File upload tracking and metadata
-- Based on: Ever-Gauzy file management patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_file_uploads` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `tenant_id` INT NOT NULL COMMENT 'Multi-tenant isolation',
  `order_id` INT COMMENT 'Associated order (optional for general files)',
  `uploaded_by` INT NOT NULL COMMENT 'User who uploaded the file',
  `file_type` ENUM('design', 'reference', 'preview', 'proof', 'final') NOT NULL COMMENT 'File classification',
  `original_filename` VARCHAR(500) NOT NULL COMMENT 'Original filename from upload',
  `stored_filename` VARCHAR(500) NOT NULL COMMENT 'Stored filename (UUID-based)',
  `file_path` VARCHAR(1000) NOT NULL COMMENT 'Full file path on storage system',
  `file_size_bytes` BIGINT NOT NULL COMMENT 'File size in bytes',
  `mime_type` VARCHAR(100) NOT NULL COMMENT 'MIME type of the file',
  `file_extension` VARCHAR(10) NOT NULL COMMENT 'File extension',
  `checksum_md5` VARCHAR(32) COMMENT 'MD5 checksum for integrity',
  `checksum_sha256` VARCHAR(64) COMMENT 'SHA256 checksum for security',
  `storage_tier` ENUM('hot', 'warm', 'cold', 'archived') DEFAULT 'hot' COMMENT 'Storage tier for lifecycle management',
  `storage_location` VARCHAR(500) COMMENT 'Storage location: VPS, cPanel, cloud, etc.',
  `virus_scan_status` ENUM('pending', 'clean', 'infected', 'failed') DEFAULT 'pending' COMMENT 'Virus scan status',
  `virus_scan_at` TIMESTAMP NULL COMMENT 'When virus scan was performed',
  `processing_status` ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending' COMMENT 'File processing status',
  `processed_at` TIMESTAMP NULL COMMENT 'When file processing completed',
  `metadata` JSON COMMENT 'File metadata: EXIF, dimensions, etc.',
  `is_active` BOOLEAN DEFAULT TRUE COMMENT 'File availability status',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` TIMESTAMP NULL COMMENT 'Soft delete timestamp',
  
  -- Foreign key constraints
  FOREIGN KEY (`tenant_id`) REFERENCES `cflex_tenants`(`id`) ON DELETE RESTRICT,
  FOREIGN KEY (`order_id`) REFERENCES `cflex_orders`(`id`) ON DELETE CASCADE,
  -- Note: uploaded_by references Rise CRM users table - handled via application logic
  
  -- Indexes for performance
  INDEX `idx_file_order` (`order_id`, `file_type`),
  INDEX `idx_file_storage` (`storage_tier`, `created_at`),
  INDEX `idx_file_processing` (`processing_status`, `created_at`),
  INDEX `idx_file_tenant` (`tenant_id`, `file_type`, `created_at`),
  INDEX `idx_file_uploader` (`uploaded_by`, `created_at`),
  INDEX `idx_file_virus_scan` (`virus_scan_status`, `virus_scan_at`),
  INDEX `idx_file_checksum_md5` (`checksum_md5`),
  INDEX `idx_file_checksum_sha256` (`checksum_sha256`),
  INDEX `idx_file_soft_delete` (`deleted_at`),
  
  -- Unique constraints
  UNIQUE KEY `uk_file_stored_filename` (`stored_filename`),
  UNIQUE KEY `uk_file_path` (`file_path`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='File upload tracking and metadata';

-- =====================================================
-- Table: cflex_file_versions
-- Purpose: File version history and relationships
-- Based on: Git-like version control patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_file_versions` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `parent_file_id` INT NOT NULL COMMENT 'Original/parent file reference',
  `file_id` INT NOT NULL COMMENT 'This version file reference',
  `version_number` INT NOT NULL COMMENT 'Sequential version number',
  `version_type` ENUM('original', 'preview', 'watermarked', 'processed', 'revision') NOT NULL COMMENT 'Type of version',
  `created_by` INT NOT NULL COMMENT 'User who created this version',
  `change_notes` TEXT COMMENT 'Description of changes in this version',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Foreign key constraints
  FOREIGN KEY (`parent_file_id`) REFERENCES `cflex_file_uploads`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`file_id`) REFERENCES `cflex_file_uploads`(`id`) ON DELETE CASCADE,
  -- Note: created_by references Rise CRM users table - handled via application logic
  
  -- Indexes for performance
  INDEX `idx_version_parent` (`parent_file_id`, `version_number`),
  INDEX `idx_version_file` (`file_id`),
  INDEX `idx_version_type` (`version_type`, `created_at`),
  INDEX `idx_version_creator` (`created_by`, `created_at`),
  
  -- Unique constraints
  UNIQUE KEY `uk_version_parent_number` (`parent_file_id`, `version_number`),
  UNIQUE KEY `uk_version_file_unique` (`file_id`) -- Each file can only be a version once
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='File version history and relationships';

-- =====================================================
-- Table: cflex_design_annotations
-- Purpose: Design review annotations and comments
-- Based on: Collaborative design review patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_design_annotations` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `file_id` INT NOT NULL COMMENT 'File being annotated',
  `annotated_by` INT NOT NULL COMMENT 'User who created the annotation',
  `annotation_type` ENUM('comment', 'markup', 'approval', 'rejection') NOT NULL COMMENT 'Type of annotation',
  `x_coordinate` DECIMAL(8,4) COMMENT 'Relative X position (0-1) on the file',
  `y_coordinate` DECIMAL(8,4) COMMENT 'Relative Y position (0-1) on the file',
  `comment` TEXT COMMENT 'Text comment or feedback',
  `markup_data` JSON COMMENT 'SVG or canvas data for drawings/markups',
  `parent_annotation_id` INT COMMENT 'Parent annotation for threaded discussions',
  `status` ENUM('open', 'resolved', 'acknowledged') DEFAULT 'open' COMMENT 'Annotation status',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Foreign key constraints
  FOREIGN KEY (`file_id`) REFERENCES `cflex_file_uploads`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`parent_annotation_id`) REFERENCES `cflex_design_annotations`(`id`) ON DELETE CASCADE,
  -- Note: annotated_by references Rise CRM users table - handled via application logic
  
  -- Indexes for performance
  INDEX `idx_annotation_file` (`file_id`, `created_at`),
  INDEX `idx_annotation_thread` (`parent_annotation_id`),
  INDEX `idx_annotation_type` (`annotation_type`, `status`),
  INDEX `idx_annotation_status` (`status`, `created_at`),
  INDEX `idx_annotation_user` (`annotated_by`, `created_at`),
  INDEX `idx_annotation_coordinates` (`x_coordinate`, `y_coordinate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Design review annotations and comments';

-- =====================================================
-- Validation and Constraints
-- =====================================================

-- Ensure JSON fields are valid
ALTER TABLE `cflex_file_uploads`
ADD CONSTRAINT `chk_file_metadata_valid`
CHECK (JSON_VALID(`metadata`));

ALTER TABLE `cflex_design_annotations`
ADD CONSTRAINT `chk_annotation_markup_data_valid`
CHECK (JSON_VALID(`markup_data`));

-- File size constraints
ALTER TABLE `cflex_file_uploads`
ADD CONSTRAINT `chk_file_size_positive`
CHECK (`file_size_bytes` > 0);

-- Coordinate constraints (0-1 range for relative positioning)
ALTER TABLE `cflex_design_annotations`
ADD CONSTRAINT `chk_annotation_x_coordinate_range`
CHECK (`x_coordinate` IS NULL OR (`x_coordinate` >= 0 AND `x_coordinate` <= 1));

ALTER TABLE `cflex_design_annotations`
ADD CONSTRAINT `chk_annotation_y_coordinate_range`
CHECK (`y_coordinate` IS NULL OR (`y_coordinate` >= 0 AND `y_coordinate` <= 1));

-- Version number constraints
ALTER TABLE `cflex_file_versions`
ADD CONSTRAINT `chk_version_number_positive`
CHECK (`version_number` > 0);

-- =====================================================
-- Triggers for File Management
-- =====================================================

DELIMITER $$

-- Trigger to automatically create version entry for original files
CREATE TRIGGER `tr_file_upload_create_version`
AFTER INSERT ON `cflex_file_uploads`
FOR EACH ROW
BEGIN
  -- Create version 1 entry for the original file
  INSERT INTO `cflex_file_versions`
  (`parent_file_id`, `file_id`, `version_number`, `version_type`, `created_by`, `change_notes`, `created_at`)
  VALUES
  (NEW.id, NEW.id, 1, 'original', NEW.uploaded_by, 'Original file upload', NEW.created_at);
END$$

-- Trigger to update file processing timestamp
CREATE TRIGGER `tr_file_processing_status_update`
BEFORE UPDATE ON `cflex_file_uploads`
FOR EACH ROW
BEGIN
  -- Update processed_at timestamp when processing status changes to completed
  IF OLD.processing_status != NEW.processing_status AND NEW.processing_status = 'completed' THEN
    SET NEW.processed_at = NOW();
  END IF;

  -- Update virus_scan_at timestamp when virus scan status changes from pending
  IF OLD.virus_scan_status != NEW.virus_scan_status AND OLD.virus_scan_status = 'pending' THEN
    SET NEW.virus_scan_at = NOW();
  END IF;
END$$

DELIMITER ;

-- =====================================================
-- File Storage Lifecycle Management
-- =====================================================

-- Create view for file storage statistics
CREATE VIEW `v_file_storage_stats` AS
SELECT
  storage_tier,
  COUNT(*) as file_count,
  SUM(file_size_bytes) as total_size_bytes,
  ROUND(SUM(file_size_bytes) / 1024 / 1024, 2) as total_size_mb,
  ROUND(SUM(file_size_bytes) / 1024 / 1024 / 1024, 2) as total_size_gb,
  MIN(created_at) as oldest_file,
  MAX(created_at) as newest_file
FROM cflex_file_uploads
WHERE deleted_at IS NULL AND is_active = TRUE
GROUP BY storage_tier;

-- Create view for file processing queue
CREATE VIEW `v_file_processing_queue` AS
SELECT
  f.id,
  f.original_filename,
  f.file_type,
  f.file_size_bytes,
  f.processing_status,
  f.virus_scan_status,
  f.created_at,
  TIMESTAMPDIFF(MINUTE, f.created_at, NOW()) as minutes_in_queue,
  o.order_number,
  o.status as order_status
FROM cflex_file_uploads f
LEFT JOIN cflex_orders o ON f.order_id = o.id
WHERE f.processing_status IN ('pending', 'processing')
  AND f.deleted_at IS NULL
  AND f.is_active = TRUE
ORDER BY f.created_at ASC;

-- =====================================================
-- Performance Optimization
-- =====================================================

-- Additional composite indexes for common query patterns
CREATE INDEX `idx_file_order_type_status` ON `cflex_file_uploads` (`order_id`, `file_type`, `processing_status`);
CREATE INDEX `idx_file_tenant_storage_tier` ON `cflex_file_uploads` (`tenant_id`, `storage_tier`, `created_at`);
CREATE INDEX `idx_version_parent_type_number` ON `cflex_file_versions` (`parent_file_id`, `version_type`, `version_number`);
CREATE INDEX `idx_annotation_file_type_status` ON `cflex_design_annotations` (`file_id`, `annotation_type`, `status`);

-- =====================================================
-- Migration Complete
-- =====================================================

-- Log migration completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`)
VALUES ('004_create_file_management', 'completed', NOW())
ON DUPLICATE KEY UPDATE
  `status` = 'completed',
  `executed_at` = NOW();
