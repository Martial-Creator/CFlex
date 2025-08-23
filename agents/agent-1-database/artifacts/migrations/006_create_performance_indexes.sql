-- =====================================================
-- CFlex Performance Optimization and Index Strategy
-- Migration: 006_create_performance_indexes.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-006
-- Created: 2025-08-23
-- Purpose: Comprehensive indexing strategy for multi-tenant performance
-- =====================================================

-- Set UTF8MB4 for consistency
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- Migration Log Table (if not exists)
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_migration_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `migration_name` VARCHAR(255) NOT NULL,
  `status` ENUM('started', 'completed', 'failed') NOT NULL,
  `executed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `execution_time_ms` INT DEFAULT NULL,
  `notes` TEXT,
  UNIQUE KEY `uk_migration_name` (`migration_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Migration execution log';

-- =====================================================
-- Critical Multi-Tenant Query Indexes
-- Target: <100ms P95 for standard operations
-- =====================================================

-- Tenant-aware queries: (tenant_id, status, created_at)
CREATE INDEX `idx_projects_tenant_status_created` ON `cflex_projects` (`tenant_id`, `status`, `created_at`);
CREATE INDEX `idx_orders_tenant_status_created` ON `cflex_orders` (`tenant_id`, `status`, `created_at`);
CREATE INDEX `idx_files_tenant_type_created` ON `cflex_file_uploads` (`tenant_id`, `file_type`, `created_at`);
CREATE INDEX `idx_tasks_tenant_status_created` ON `cflex_tasks` (`tenant_id`, `status`, `created_at`);

-- Staff task queries: (assigned_to, status, due_date)
CREATE INDEX `idx_orders_assigned_status_due` ON `cflex_orders` (`assigned_to`, `status`, `due_date`);
CREATE INDEX `idx_tasks_assigned_status_due` ON `cflex_tasks` (`assigned_to`, `status`, `due_date`);

-- Client order queries: (client_id, status, updated_at)
CREATE INDEX `idx_projects_client_status_updated` ON `cflex_projects` (`client_id`, `status`, `updated_at`);
CREATE INDEX `idx_projects_client_tenant_status` ON `cflex_projects` (`client_id`, `tenant_id`, `status`);

-- File processing queries: (processing_status, storage_tier)
CREATE INDEX `idx_files_processing_storage` ON `cflex_file_uploads` (`processing_status`, `storage_tier`);
CREATE INDEX `idx_files_processing_created` ON `cflex_file_uploads` (`processing_status`, `created_at`);

-- Audit trail queries: (order_id, created_at)
CREATE INDEX `idx_status_history_order_created` ON `cflex_order_status_history` (`order_id`, `created_at` DESC);

-- =====================================================
-- Composite Indexes for Complex Queries
-- =====================================================

-- Dashboard queries - active orders by priority and due date
CREATE INDEX `idx_orders_active_priority_due` ON `cflex_orders` (`status`, `priority`, `due_date`) 
WHERE `status` IN ('submitted', 'in_queue', 'claimed', 'design_in_progress', 'awaiting_review', 'approved', 'in_production');

-- Task queue optimization - ready tasks by priority
CREATE INDEX `idx_tasks_ready_priority_created` ON `cflex_tasks` (`status`, `priority`, `created_at`) 
WHERE `status` IN ('ready', 'pending');

-- File management - active files by order and type
CREATE INDEX `idx_files_order_type_active` ON `cflex_file_uploads` (`order_id`, `file_type`, `is_active`) 
WHERE `deleted_at` IS NULL;

-- Product catalog - active products by category and type
CREATE INDEX `idx_products_category_type_active` ON `cflex_products` (`category_id`, `product_type`, `is_active`) 
WHERE `deleted_at` IS NULL;

-- User-tenant relationships for subdomain access
CREATE INDEX `idx_user_tenants_user_status` ON `cflex_user_tenants` (`user_id`, `status`);

-- =====================================================
-- Covering Indexes for Read-Heavy Workloads
-- Target: 80/20 read/write ratio optimization
-- =====================================================

-- Order summary covering index
CREATE INDEX `idx_orders_summary_covering` ON `cflex_orders` 
(`tenant_id`, `status`, `priority`, `id`, `order_number`, `title`, `due_date`, `final_price`, `updated_at`);

-- Project summary covering index
CREATE INDEX `idx_projects_summary_covering` ON `cflex_projects` 
(`tenant_id`, `client_id`, `status`, `id`, `project_number`, `name`, `due_date`, `actual_total`, `updated_at`);

-- Task queue covering index
CREATE INDEX `idx_tasks_queue_covering` ON `cflex_tasks` 
(`status`, `priority`, `assigned_to`, `id`, `title`, `due_date`, `estimated_hours`, `created_at`);

-- File listing covering index
CREATE INDEX `idx_files_listing_covering` ON `cflex_file_uploads` 
(`order_id`, `file_type`, `is_active`, `id`, `original_filename`, `file_size_bytes`, `created_at`) 
WHERE `deleted_at` IS NULL;

-- =====================================================
-- Partial Indexes for Specific Use Cases
-- =====================================================

-- Overdue orders index
CREATE INDEX `idx_orders_overdue` ON `cflex_orders` (`due_date`, `status`, `priority`) 
WHERE `due_date` < NOW() AND `status` NOT IN ('completed', 'cancelled');

-- Pending file processing index
CREATE INDEX `idx_files_pending_processing` ON `cflex_file_uploads` (`created_at`, `file_size_bytes`) 
WHERE `processing_status` = 'pending' AND `deleted_at` IS NULL;

-- Active user sessions index (for subdomain access)
CREATE INDEX `idx_user_tenants_active` ON `cflex_user_tenants` (`tenant_id`, `user_id`) 
WHERE `status` = 'active';

-- Urgent tasks index
CREATE INDEX `idx_tasks_urgent` ON `cflex_tasks` (`due_date`, `assigned_to`) 
WHERE `priority` = 'urgent' AND `status` IN ('ready', 'claimed', 'in_progress');

-- =====================================================
-- Full-Text Search Indexes
-- =====================================================

-- Product search
ALTER TABLE `cflex_products` ADD FULLTEXT(`name`, `description`);

-- Order search
ALTER TABLE `cflex_orders` ADD FULLTEXT(`title`, `description`);

-- Project search
ALTER TABLE `cflex_projects` ADD FULLTEXT(`name`, `description`);

-- =====================================================
-- Performance Monitoring Views
-- =====================================================

-- Index usage analysis view
CREATE VIEW `v_index_usage_analysis` AS
SELECT 
  TABLE_SCHEMA as database_name,
  TABLE_NAME as table_name,
  INDEX_NAME as index_name,
  COLUMN_NAME as column_name,
  SEQ_IN_INDEX as column_position,
  CARDINALITY as estimated_rows,
  CASE 
    WHEN NON_UNIQUE = 0 THEN 'UNIQUE'
    ELSE 'NON_UNIQUE'
  END as index_type
FROM information_schema.STATISTICS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'cflex_%'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- Query performance monitoring view
CREATE VIEW `v_query_performance_monitor` AS
SELECT 
  'cflex_orders' as table_name,
  COUNT(*) as total_rows,
  COUNT(CASE WHEN status IN ('submitted', 'in_queue', 'claimed') THEN 1 END) as active_rows,
  COUNT(CASE WHEN due_date < NOW() AND status NOT IN ('completed', 'cancelled') THEN 1 END) as overdue_rows,
  AVG(TIMESTAMPDIFF(HOUR, created_at, updated_at)) as avg_processing_hours
FROM cflex_orders
WHERE deleted_at IS NULL

UNION ALL

SELECT 
  'cflex_tasks' as table_name,
  COUNT(*) as total_rows,
  COUNT(CASE WHEN status IN ('ready', 'claimed', 'in_progress') THEN 1 END) as active_rows,
  COUNT(CASE WHEN due_date < NOW() AND status NOT IN ('completed', 'cancelled') THEN 1 END) as overdue_rows,
  AVG(actual_hours) as avg_processing_hours
FROM cflex_tasks

UNION ALL

SELECT 
  'cflex_file_uploads' as table_name,
  COUNT(*) as total_rows,
  COUNT(CASE WHEN processing_status = 'pending' THEN 1 END) as active_rows,
  COUNT(CASE WHEN virus_scan_status = 'pending' THEN 1 END) as overdue_rows,
  AVG(file_size_bytes / 1024 / 1024) as avg_processing_hours
FROM cflex_file_uploads
WHERE deleted_at IS NULL;

-- =====================================================
-- Database Configuration Recommendations
-- =====================================================

-- Set optimal MySQL configuration for multi-tenant workload
-- Note: These are recommendations to be applied at server level

/*
Recommended MySQL Configuration (my.cnf):

[mysqld]
# Buffer pool size (70-80% of available RAM)
innodb_buffer_pool_size = 2G

# Log file size for write performance
innodb_log_file_size = 256M

# Connection handling
max_connections = 200
thread_cache_size = 50

# Query cache (if using MySQL 5.7 or earlier)
query_cache_type = 1
query_cache_size = 128M

# InnoDB settings for multi-tenant workload
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1
innodb_buffer_pool_instances = 4

# Character set
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci
*/

-- =====================================================
-- Performance Testing Procedures
-- =====================================================

DELIMITER $$

-- Procedure to analyze query performance
CREATE PROCEDURE `sp_analyze_query_performance`()
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE table_name VARCHAR(64);
  DECLARE row_count INT;

  -- Cursor for all CFlex tables
  DECLARE table_cursor CURSOR FOR
    SELECT TABLE_NAME
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME LIKE 'cflex_%'
      AND TABLE_TYPE = 'BASE TABLE';

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  -- Create temporary results table
  CREATE TEMPORARY TABLE IF NOT EXISTS temp_performance_results (
    table_name VARCHAR(64),
    total_rows INT,
    avg_row_length INT,
    data_length BIGINT,
    index_length BIGINT,
    fragmentation_ratio DECIMAL(5,2)
  );

  OPEN table_cursor;

  read_loop: LOOP
    FETCH table_cursor INTO table_name;
    IF done THEN
      LEAVE read_loop;
    END IF;

    -- Get table statistics
    SET @sql = CONCAT('INSERT INTO temp_performance_results
      SELECT
        TABLE_NAME,
        TABLE_ROWS,
        AVG_ROW_LENGTH,
        DATA_LENGTH,
        INDEX_LENGTH,
        ROUND((DATA_FREE / (DATA_LENGTH + INDEX_LENGTH)) * 100, 2)
      FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ''', table_name, '''');

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END LOOP;

  CLOSE table_cursor;

  -- Return results
  SELECT * FROM temp_performance_results ORDER BY data_length DESC;

  DROP TEMPORARY TABLE temp_performance_results;
END$$

-- Procedure to check index effectiveness
CREATE PROCEDURE `sp_check_index_effectiveness`()
BEGIN
  SELECT
    s.TABLE_NAME,
    s.INDEX_NAME,
    s.COLUMN_NAME,
    s.CARDINALITY,
    CASE
      WHEN s.CARDINALITY = 0 THEN 'UNUSED - Consider dropping'
      WHEN s.CARDINALITY < 10 THEN 'LOW SELECTIVITY - Review necessity'
      WHEN s.CARDINALITY > 1000 THEN 'HIGH SELECTIVITY - Good'
      ELSE 'MODERATE SELECTIVITY - Monitor usage'
    END as effectiveness_status
  FROM information_schema.STATISTICS s
  WHERE s.TABLE_SCHEMA = DATABASE()
    AND s.TABLE_NAME LIKE 'cflex_%'
    AND s.INDEX_NAME != 'PRIMARY'
  ORDER BY s.TABLE_NAME, s.CARDINALITY DESC;
END$$

DELIMITER ;

-- =====================================================
-- Performance Benchmarking
-- =====================================================

-- Create benchmark results table
CREATE TABLE IF NOT EXISTS `cflex_performance_benchmarks` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `benchmark_name` VARCHAR(255) NOT NULL,
  `query_type` ENUM('SELECT', 'INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `execution_time_ms` DECIMAL(10,3) NOT NULL,
  `rows_affected` INT DEFAULT 0,
  `query_hash` VARCHAR(64) COMMENT 'MD5 hash of the query for tracking',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX `idx_benchmark_name_time` (`benchmark_name`, `execution_time_ms`),
  INDEX `idx_benchmark_type_time` (`query_type`, `execution_time_ms`),
  INDEX `idx_benchmark_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Performance benchmark results';

-- =====================================================
-- Migration Complete
-- =====================================================

-- Log migration completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`)
VALUES ('006_create_performance_indexes', 'completed', NOW())
ON DUPLICATE KEY UPDATE
  `status` = 'completed',
  `executed_at` = NOW();

-- =====================================================
-- Performance Validation
-- =====================================================

-- Run initial performance analysis
CALL sp_analyze_query_performance();

-- Display completion summary
SELECT
  'Performance Optimization Migration Completed' as status,
  NOW() as completed_at,
  'All indexes created, monitoring views established, performance procedures ready' as note;

-- =====================================================
-- Post-Migration Recommendations
-- =====================================================

/*
POST-MIGRATION CHECKLIST:

1. Monitor Query Performance:
   - Run: SELECT * FROM v_query_performance_monitor;
   - Target: <100ms P95 for standard operations

2. Check Index Usage:
   - Run: CALL sp_check_index_effectiveness();
   - Target: >90% utilization for critical queries

3. Analyze Table Statistics:
   - Run: CALL sp_analyze_query_performance();
   - Monitor fragmentation ratios

4. Set up Regular Maintenance:
   - Schedule ANALYZE TABLE for all cflex_* tables weekly
   - Monitor slow query log
   - Review index usage monthly

5. Load Testing:
   - Test with 30 concurrent users
   - Validate scalability to 150 users
   - Benchmark file upload performance (500MB files)

6. Monitoring Setup:
   - Enable slow query log
   - Set up performance_schema monitoring
   - Configure alerts for query times >100ms
*/
