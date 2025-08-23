-- =====================================================
-- CFlex Product Catalog and Pricing Schema
-- Migration: 003_create_product_catalog.sql
-- Agent: agent-1-database
-- Task: T-001-DB-FOUNDATION / ST-003
-- Created: 2025-08-23
-- Based on: Odoo product.product and product.template patterns
-- =====================================================

-- Set UTF8MB4 for bilingual support (English/Nepali)
SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================
-- Table: cflex_product_categories
-- Purpose: Product category hierarchy
-- Based on: Odoo product.category patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_product_categories` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL COMMENT 'Category name (English/Nepali)',
  `slug` VARCHAR(255) NOT NULL COMMENT 'URL-friendly category identifier',
  `parent_id` INT COMMENT 'Self-referencing for hierarchy',
  `description` TEXT COMMENT 'Category description',
  `sort_order` INT DEFAULT 0 COMMENT 'Display order within parent',
  `is_active` BOOLEAN DEFAULT TRUE COMMENT 'Category visibility status',
  `metadata` JSON COMMENT 'Category-specific configuration',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Foreign key constraints
  FOREIGN KEY (`parent_id`) REFERENCES `cflex_product_categories`(`id`) ON DELETE SET NULL,
  
  -- Indexes for performance
  INDEX `idx_category_parent` (`parent_id`, `sort_order`),
  INDEX `idx_category_slug` (`slug`),
  INDEX `idx_category_active` (`is_active`, `sort_order`),
  INDEX `idx_category_hierarchy` (`parent_id`, `is_active`, `sort_order`),
  
  -- Unique constraints
  UNIQUE KEY `uk_category_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Product category hierarchy';

-- =====================================================
-- Table: cflex_products
-- Purpose: Product templates (similar to Odoo product.template)
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_products` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `category_id` INT COMMENT 'Product category reference',
  `name` VARCHAR(255) NOT NULL COMMENT 'Product name (English/Nepali)',
  `slug` VARCHAR(255) NOT NULL COMMENT 'URL-friendly product identifier',
  `description` TEXT COMMENT 'Detailed product description',
  `product_type` ENUM('flex_banner', 'certificate', 'token_of_love', 'photo_frame', 'stamps', 'metal_medals', 'custom_quote') NOT NULL COMMENT 'Product classification',
  `pricing_type` ENUM('fixed', 'area_based', 'custom_quote') NOT NULL COMMENT 'Pricing calculation method',
  `base_price` DECIMAL(10,2) COMMENT 'Base price for fixed pricing',
  `price_per_unit` DECIMAL(10,4) COMMENT 'Price per unit for area-based pricing (per sqft)',
  `unit_type` VARCHAR(20) COMMENT 'Unit of measurement: sqft, piece, etc.',
  `has_variants` BOOLEAN DEFAULT FALSE COMMENT 'Whether product has variants',
  `requires_design` BOOLEAN DEFAULT TRUE COMMENT 'Whether product requires design work',
  `max_file_size` INT DEFAULT 524288000 COMMENT 'Maximum file size in bytes (500MB default)',
  `allowed_file_types` JSON COMMENT 'Allowed file extensions: ["pdf", "ai", "psd", "tiff", "jpg", "png"]',
  `dimension_constraints` JSON COMMENT 'Min/max width, height constraints',
  `processing_time_hours` INT DEFAULT 24 COMMENT 'Standard processing time in hours',
  `is_active` BOOLEAN DEFAULT TRUE COMMENT 'Product availability status',
  `metadata` JSON COMMENT 'Product-specific metadata and settings',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` TIMESTAMP NULL COMMENT 'Soft delete timestamp',
  
  -- Foreign key constraints
  FOREIGN KEY (`category_id`) REFERENCES `cflex_product_categories`(`id`) ON DELETE SET NULL,
  
  -- Indexes for performance
  INDEX `idx_product_type` (`product_type`, `is_active`),
  INDEX `idx_product_category` (`category_id`, `is_active`),
  INDEX `idx_product_slug` (`slug`),
  INDEX `idx_product_pricing` (`pricing_type`, `is_active`),
  INDEX `idx_product_active` (`is_active`, `created_at`),
  INDEX `idx_product_soft_delete` (`deleted_at`),
  
  -- Unique constraints
  UNIQUE KEY `uk_product_slug` (`slug`, `deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Product templates with pricing and constraints';

-- =====================================================
-- Table: cflex_product_variants
-- Purpose: Product variants (materials, sizes, finishes)
-- Based on: Odoo product.product patterns
-- =====================================================

CREATE TABLE IF NOT EXISTS `cflex_product_variants` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `product_id` INT NOT NULL COMMENT 'Parent product reference',
  `name` VARCHAR(255) NOT NULL COMMENT 'Variant name (e.g., "Vinyl Material", "Matte Finish")',
  `variant_type` ENUM('material', 'size', 'finish', 'quality') NOT NULL COMMENT 'Type of variant',
  `value` VARCHAR(255) NOT NULL COMMENT 'Variant value (vinyl, fabric, matte, etc.)',
  `price_modifier` DECIMAL(8,4) DEFAULT 1.0000 COMMENT 'Price multiplier or fixed amount',
  `modifier_type` ENUM('multiplier', 'fixed_amount') DEFAULT 'multiplier' COMMENT 'How price_modifier is applied',
  `is_default` BOOLEAN DEFAULT FALSE COMMENT 'Default variant for this type',
  `sort_order` INT DEFAULT 0 COMMENT 'Display order within variant type',
  `is_active` BOOLEAN DEFAULT TRUE COMMENT 'Variant availability status',
  `metadata` JSON COMMENT 'Variant-specific data: color codes, descriptions, etc.',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Foreign key constraints
  FOREIGN KEY (`product_id`) REFERENCES `cflex_products`(`id`) ON DELETE CASCADE,
  
  -- Indexes for performance
  INDEX `idx_variant_product` (`product_id`, `variant_type`),
  INDEX `idx_variant_type` (`variant_type`, `is_active`),
  INDEX `idx_variant_active` (`is_active`, `sort_order`),
  INDEX `idx_variant_default` (`product_id`, `variant_type`, `is_default`),
  
  -- Unique constraints to prevent duplicate variants
  UNIQUE KEY `uk_variant_product_type_value` (`product_id`, `variant_type`, `value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Product variants for materials, sizes, finishes';

-- =====================================================
-- Validation and Constraints
-- =====================================================

-- Ensure JSON fields are valid
ALTER TABLE `cflex_product_categories`
ADD CONSTRAINT `chk_category_metadata_valid`
CHECK (JSON_VALID(`metadata`));

ALTER TABLE `cflex_products`
ADD CONSTRAINT `chk_product_allowed_file_types_valid`
CHECK (JSON_VALID(`allowed_file_types`));

ALTER TABLE `cflex_products`
ADD CONSTRAINT `chk_product_dimension_constraints_valid`
CHECK (JSON_VALID(`dimension_constraints`));

ALTER TABLE `cflex_products`
ADD CONSTRAINT `chk_product_metadata_valid`
CHECK (JSON_VALID(`metadata`));

ALTER TABLE `cflex_product_variants`
ADD CONSTRAINT `chk_variant_metadata_valid`
CHECK (JSON_VALID(`metadata`));

-- Business logic constraints
ALTER TABLE `cflex_products`
ADD CONSTRAINT `chk_product_base_price_positive`
CHECK (`base_price` IS NULL OR `base_price` >= 0);

ALTER TABLE `cflex_products`
ADD CONSTRAINT `chk_product_price_per_unit_positive`
CHECK (`price_per_unit` IS NULL OR `price_per_unit` >= 0);

ALTER TABLE `cflex_products`
ADD CONSTRAINT `chk_product_max_file_size_positive`
CHECK (`max_file_size` > 0);

ALTER TABLE `cflex_products`
ADD CONSTRAINT `chk_product_processing_time_positive`
CHECK (`processing_time_hours` > 0);

ALTER TABLE `cflex_product_variants`
ADD CONSTRAINT `chk_variant_price_modifier_positive`
CHECK (`price_modifier` > 0);

-- =====================================================
-- Sample Data - Product Categories
-- =====================================================

INSERT INTO `cflex_product_categories` (`name`, `slug`, `parent_id`, `description`, `sort_order`, `is_active`, `metadata`) VALUES
('Printing Services', 'printing-services', NULL, 'All printing and design services', 1, TRUE,
 JSON_OBJECT('icon', 'print', 'color', '#2563eb')),

('Banners & Signage', 'banners-signage', 1, 'Flex banners, vinyl banners, and outdoor signage', 1, TRUE,
 JSON_OBJECT('icon', 'flag', 'color', '#dc2626')),

('Certificates & Awards', 'certificates-awards', 1, 'Certificates, awards, and recognition items', 2, TRUE,
 JSON_OBJECT('icon', 'award', 'color', '#059669')),

('Photo Products', 'photo-products', 1, 'Photo frames, canvas prints, and photo gifts', 3, TRUE,
 JSON_OBJECT('icon', 'camera', 'color', '#7c3aed')),

('Custom Items', 'custom-items', 1, 'Custom quotes and specialized products', 4, TRUE,
 JSON_OBJECT('icon', 'sparkles', 'color', '#ea580c'));

-- =====================================================
-- Sample Data - Products
-- =====================================================

INSERT INTO `cflex_products` (`category_id`, `name`, `slug`, `description`, `product_type`, `pricing_type`, `base_price`, `price_per_unit`, `unit_type`, `has_variants`, `requires_design`, `max_file_size`, `allowed_file_types`, `dimension_constraints`, `processing_time_hours`, `is_active`, `metadata`) VALUES

-- Flex Banners
(2, 'Flex Banner', 'flex-banner', 'High-quality vinyl flex banners for outdoor and indoor use', 'flex_banner', 'area_based', NULL, 45.0000, 'sqft', TRUE, TRUE, 524288000,
 JSON_ARRAY('pdf', 'ai', 'psd', 'tiff', 'jpg', 'png'),
 JSON_OBJECT('min_width_ft', 1, 'max_width_ft', 20, 'min_height_ft', 1, 'max_height_ft', 50),
 24, TRUE,
 JSON_OBJECT('weather_resistant', true, 'indoor_outdoor', 'both')),

-- Certificates
(3, 'Achievement Certificate', 'achievement-certificate', 'Professional certificates for achievements and recognition', 'certificate', 'fixed', 150.00, NULL, 'piece', TRUE, TRUE, 104857600,
 JSON_ARRAY('pdf', 'ai', 'psd', 'jpg', 'png'),
 JSON_OBJECT('standard_sizes', JSON_ARRAY('A4', 'A3', 'Letter')),
 12, TRUE,
 JSON_OBJECT('paper_quality', 'premium', 'lamination_available', true)),

-- Photo Frames
(4, 'Custom Photo Frame', 'custom-photo-frame', 'Personalized photo frames with custom designs', 'photo_frame', 'fixed', 250.00, NULL, 'piece', TRUE, TRUE, 52428800,
 JSON_ARRAY('jpg', 'png', 'tiff', 'pdf'),
 JSON_OBJECT('standard_sizes', JSON_ARRAY('4x6', '5x7', '8x10', '11x14')),
 48, TRUE,
 JSON_OBJECT('frame_materials', JSON_ARRAY('wood', 'metal', 'plastic'))),

-- Custom Quote Items
(5, 'Custom Design Project', 'custom-design-project', 'Custom design projects requiring individual quotes', 'custom_quote', 'custom_quote', NULL, NULL, 'project', FALSE, TRUE, 1073741824,
 JSON_ARRAY('pdf', 'ai', 'psd', 'tiff', 'jpg', 'png', 'eps', 'svg'),
 JSON_OBJECT('consultation_required', true),
 72, TRUE,
 JSON_OBJECT('requires_consultation', true, 'complex_design', true));

-- =====================================================
-- Sample Data - Product Variants
-- =====================================================

-- Flex Banner Variants
INSERT INTO `cflex_product_variants` (`product_id`, `name`, `variant_type`, `value`, `price_modifier`, `modifier_type`, `is_default`, `sort_order`, `is_active`, `metadata`) VALUES

-- Material variants for Flex Banner (product_id = 1)
(1, 'Standard Vinyl', 'material', 'vinyl_standard', 1.0000, 'multiplier', TRUE, 1, TRUE,
 JSON_OBJECT('durability', 'standard', 'weather_resistance', 'good')),
(1, 'Premium Vinyl', 'material', 'vinyl_premium', 1.3000, 'multiplier', FALSE, 2, TRUE,
 JSON_OBJECT('durability', 'high', 'weather_resistance', 'excellent')),
(1, 'Fabric Banner', 'material', 'fabric', 1.5000, 'multiplier', FALSE, 3, TRUE,
 JSON_OBJECT('durability', 'medium', 'texture', 'fabric', 'indoor_use', true)),

-- Finish variants for Flex Banner
(1, 'Matte Finish', 'finish', 'matte', 1.0000, 'multiplier', TRUE, 1, TRUE,
 JSON_OBJECT('reflection', 'low', 'readability', 'excellent')),
(1, 'Glossy Finish', 'finish', 'glossy', 1.1000, 'multiplier', FALSE, 2, TRUE,
 JSON_OBJECT('reflection', 'high', 'color_vibrancy', 'enhanced')),

-- Certificate Variants
-- Paper quality variants for Achievement Certificate (product_id = 2)
(2, 'Standard Paper', 'quality', 'paper_standard', 1.0000, 'multiplier', TRUE, 1, TRUE,
 JSON_OBJECT('gsm', 200, 'texture', 'smooth')),
(2, 'Premium Paper', 'quality', 'paper_premium', 1.4000, 'multiplier', FALSE, 2, TRUE,
 JSON_OBJECT('gsm', 300, 'texture', 'textured')),
(2, 'Cardstock', 'quality', 'cardstock', 1.6000, 'multiplier', FALSE, 3, TRUE,
 JSON_OBJECT('gsm', 350, 'durability', 'high')),

-- Size variants for Achievement Certificate
(2, 'A4 Size', 'size', 'a4', 1.0000, 'multiplier', TRUE, 1, TRUE,
 JSON_OBJECT('dimensions', '210x297mm', 'standard', true)),
(2, 'A3 Size', 'size', 'a3', 1.8000, 'multiplier', FALSE, 2, TRUE,
 JSON_OBJECT('dimensions', '297x420mm', 'premium', true)),

-- Photo Frame Variants
-- Material variants for Custom Photo Frame (product_id = 3)
(3, 'Wooden Frame', 'material', 'wood', 1.0000, 'multiplier', TRUE, 1, TRUE,
 JSON_OBJECT('material_type', 'pine', 'finish', 'natural')),
(3, 'Metal Frame', 'material', 'metal', 1.2000, 'multiplier', FALSE, 2, TRUE,
 JSON_OBJECT('material_type', 'aluminum', 'finish', 'brushed')),
(3, 'Premium Wood', 'material', 'wood_premium', 1.5000, 'multiplier', FALSE, 3, TRUE,
 JSON_OBJECT('material_type', 'oak', 'finish', 'stained'));

-- =====================================================
-- Performance Optimization
-- =====================================================

-- Additional composite indexes for common query patterns
CREATE INDEX `idx_category_parent_active_sort` ON `cflex_product_categories` (`parent_id`, `is_active`, `sort_order`);
CREATE INDEX `idx_product_category_type_active` ON `cflex_products` (`category_id`, `product_type`, `is_active`);
CREATE INDEX `idx_variant_product_type_active` ON `cflex_product_variants` (`product_id`, `variant_type`, `is_active`);

-- =====================================================
-- Migration Complete
-- =====================================================

-- Log migration completion
INSERT INTO `cflex_migration_log` (`migration_name`, `status`, `executed_at`)
VALUES ('003_create_product_catalog', 'completed', NOW())
ON DUPLICATE KEY UPDATE
  `status` = 'completed',
  `executed_at` = NOW();
