-- Phase 1 Database Enhancement Migration Script
-- Creates core foundation tables for contract and supplier performance management
-- Run this after backing up your existing database

-- =============================================================================
-- PHASE 1: FOUNDATION TABLES
-- =============================================================================

-- Contract Lifecycle Management Tables
-- =============================================================================

-- 1. Contracts Master Table
CREATE TABLE contracts (
    contract_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER NOT NULL,
    contract_name VARCHAR(200) NOT NULL,
    contract_type VARCHAR(50) DEFAULT 'Purchase Agreement',
    contract_value DECIMAL(15,2),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    auto_renewal_flag BOOLEAN DEFAULT FALSE,
    renewal_notice_days INTEGER DEFAULT 90,
    contract_status VARCHAR(30) DEFAULT 'Active',
    contract_owner VARCHAR(100),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_contracts_vendor FOREIGN KEY (vendor_id) REFERENCES vendor_dimension(vendor_id),
    CONSTRAINT chk_contract_dates CHECK (end_date > start_date),
    CONSTRAINT chk_contract_status CHECK (contract_status IN ('Active', 'Expired', 'Terminated', 'Under Review', 'Draft'))
);

-- 2. Contract Renewals Tracking
CREATE TABLE contract_renewals (
    renewal_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) NOT NULL,
    renewal_type VARCHAR(30) DEFAULT 'Negotiated',
    renewal_date DATE,
    new_end_date DATE,
    value_change_pct DECIMAL(5,2) DEFAULT 0.0,
    renewal_status VARCHAR(30) DEFAULT 'Planned',
    stakeholder_approved BOOLEAN DEFAULT FALSE,
    renewal_rationale TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_renewals_contract FOREIGN KEY (contract_id) REFERENCES contracts(contract_id),
    CONSTRAINT chk_renewal_type CHECK (renewal_type IN ('Automatic', 'Negotiated', 'Re-tendered', 'Extended')),
    CONSTRAINT chk_renewal_status CHECK (renewal_status IN ('Planned', 'In Progress', 'Completed', 'Cancelled'))
);

-- 3. Contract Performance Tracking
CREATE TABLE contract_performance (
    performance_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) NOT NULL,
    reporting_period VARCHAR(20) NOT NULL,
    contract_utilization_pct DECIMAL(5,2) DEFAULT 0.0,
    savings_realized DECIMAL(15,2) DEFAULT 0.0,
    sla_compliance_pct DECIMAL(5,2) DEFAULT 0.0,
    performance_score INTEGER DEFAULT 3,
    issues_reported INTEGER DEFAULT 0,
    escalations_count INTEGER DEFAULT 0,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_contract_perf_contract FOREIGN KEY (contract_id) REFERENCES contracts(contract_id),
    CONSTRAINT chk_utilization_pct CHECK (contract_utilization_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_sla_compliance CHECK (sla_compliance_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_performance_score CHECK (performance_score BETWEEN 1 AND 5)
);

-- Supplier Performance Management Tables
-- =============================================================================

-- 4. Supplier Scorecard
CREATE TABLE supplier_scorecard (
    scorecard_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER NOT NULL,
    reporting_period VARCHAR(20) NOT NULL,
    overall_score DECIMAL(4,2) DEFAULT 3.0,
    delivery_score DECIMAL(4,2) DEFAULT 3.0,
    quality_score DECIMAL(4,2) DEFAULT 3.0,
    cost_score DECIMAL(4,2) DEFAULT 3.0,
    service_score DECIMAL(4,2) DEFAULT 3.0,
    innovation_score DECIMAL(4,2) DEFAULT 3.0,
    esg_score DECIMAL(4,2) DEFAULT 3.0,
    performance_tier VARCHAR(20) DEFAULT 'Approved',
    improvement_required BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_scorecard_vendor FOREIGN KEY (vendor_id) REFERENCES vendor_dimension(vendor_id),
    CONSTRAINT chk_overall_score CHECK (overall_score BETWEEN 0 AND 5),
    CONSTRAINT chk_delivery_score CHECK (delivery_score BETWEEN 0 AND 5),
    CONSTRAINT chk_quality_score CHECK (quality_score BETWEEN 0 AND 5),
    CONSTRAINT chk_cost_score CHECK (cost_score BETWEEN 0 AND 5),
    CONSTRAINT chk_service_score CHECK (service_score BETWEEN 0 AND 5),
    CONSTRAINT chk_innovation_score CHECK (innovation_score BETWEEN 0 AND 5),
    CONSTRAINT chk_esg_score_sc CHECK (esg_score BETWEEN 0 AND 5),
    CONSTRAINT chk_performance_tier CHECK (performance_tier IN ('Strategic', 'Preferred', 'Approved', 'Monitor', 'Exit'))
);

-- 5. Delivery Performance Tracking
CREATE TABLE delivery_performance (
    delivery_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER NOT NULL,
    po_number VARCHAR(50),
    promised_date DATE NOT NULL,
    actual_delivery_date DATE,
    quantity_ordered INTEGER DEFAULT 1,
    quantity_delivered INTEGER DEFAULT 0,
    on_time_flag BOOLEAN DEFAULT FALSE,
    in_full_flag BOOLEAN DEFAULT FALSE,
    otif_flag BOOLEAN DEFAULT FALSE,
    delay_days INTEGER DEFAULT 0,
    delay_reason VARCHAR(100),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_delivery_vendor FOREIGN KEY (vendor_id) REFERENCES vendor_dimension(vendor_id),
    CONSTRAINT chk_quantities CHECK (quantity_ordered > 0 AND quantity_delivered >= 0)
);

-- 6. Quality Performance Tracking
CREATE TABLE quality_performance (
    quality_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER NOT NULL,
    inspection_date DATE NOT NULL,
    commodity_id INTEGER,
    total_quantity INTEGER DEFAULT 1,
    defective_quantity INTEGER DEFAULT 0,
    defect_rate DECIMAL(5,2) DEFAULT 0.0,
    quality_rating INTEGER DEFAULT 3,
    corrective_action_required BOOLEAN DEFAULT FALSE,
    corrective_action_description TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_quality_vendor FOREIGN KEY (vendor_id) REFERENCES vendor_dimension(vendor_id),
    CONSTRAINT fk_quality_commodity FOREIGN KEY (commodity_id) REFERENCES commodity_dimension(commodity_id),
    CONSTRAINT chk_defect_rate CHECK (defect_rate BETWEEN 0 AND 100),
    CONSTRAINT chk_quality_rating CHECK (quality_rating BETWEEN 1 AND 5),
    CONSTRAINT chk_quality_quantities CHECK (total_quantity > 0 AND defective_quantity >= 0 AND defective_quantity <= total_quantity)
);

-- Financial Performance Tables
-- =============================================================================

-- 7. Savings Initiatives Tracking
CREATE TABLE savings_initiatives (
    initiative_id VARCHAR(50) PRIMARY KEY,
    initiative_name VARCHAR(200) NOT NULL,
    category_id INTEGER,
    initiative_type VARCHAR(50) DEFAULT 'Price Negotiation',
    baseline_amount DECIMAL(15,2) DEFAULT 0.0,
    forecasted_savings DECIMAL(15,2) DEFAULT 0.0,
    realized_savings DECIMAL(15,2) DEFAULT 0.0,
    realization_rate DECIMAL(5,2) DEFAULT 0.0,
    savings_type VARCHAR(30) DEFAULT 'Hard',
    initiative_status VARCHAR(30) DEFAULT 'Pipeline',
    start_date DATE NOT NULL,
    target_completion_date DATE,
    initiative_owner VARCHAR(100),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_savings_category FOREIGN KEY (category_id) REFERENCES commodity_dimension(commodity_id),
    CONSTRAINT chk_initiative_type CHECK (initiative_type IN ('Price Negotiation', 'Demand Reduction', 'Process Improvement', 'Supplier Consolidation', 'Specification Change')),
    CONSTRAINT chk_savings_type CHECK (savings_type IN ('Hard', 'Soft', 'Cost Avoidance')),
    CONSTRAINT chk_initiative_status CHECK (initiative_status IN ('Pipeline', 'Committed', 'Realized', 'Validated', 'Cancelled')),
    CONSTRAINT chk_savings_amounts CHECK (baseline_amount >= 0 AND forecasted_savings >= 0 AND realized_savings >= 0)
);

-- Performance Indexes for Phase 1 Tables
-- =============================================================================

-- Contract Management Indexes
CREATE INDEX idx_contracts_vendor_id ON contracts(vendor_id);
CREATE INDEX idx_contracts_end_date ON contracts(end_date);
CREATE INDEX idx_contracts_status ON contracts(contract_status);
CREATE INDEX idx_contracts_renewal_alert ON contracts(end_date, auto_renewal_flag) WHERE contract_status = 'Active';

CREATE INDEX idx_contract_renewals_contract_id ON contract_renewals(contract_id);
CREATE INDEX idx_contract_renewals_date ON contract_renewals(renewal_date);

CREATE INDEX idx_contract_performance_contract_id ON contract_performance(contract_id);
CREATE INDEX idx_contract_performance_period ON contract_performance(reporting_period);

-- Supplier Performance Indexes
CREATE INDEX idx_supplier_scorecard_vendor_period ON supplier_scorecard(vendor_id, reporting_period);
CREATE INDEX idx_supplier_scorecard_tier ON supplier_scorecard(performance_tier);
CREATE INDEX idx_supplier_scorecard_score ON supplier_scorecard(overall_score);

CREATE INDEX idx_delivery_performance_vendor ON delivery_performance(vendor_id);
CREATE INDEX idx_delivery_performance_date ON delivery_performance(promised_date);
CREATE INDEX idx_delivery_performance_otif ON delivery_performance(otif_flag);

CREATE INDEX idx_quality_performance_vendor ON quality_performance(vendor_id);
CREATE INDEX idx_quality_performance_date ON quality_performance(inspection_date);
CREATE INDEX idx_quality_performance_rating ON quality_performance(quality_rating);

-- Financial Performance Indexes
CREATE INDEX idx_savings_initiatives_category ON savings_initiatives(category_id);
CREATE INDEX idx_savings_initiatives_status ON savings_initiatives(initiative_status);
CREATE INDEX idx_savings_initiatives_owner ON savings_initiatives(initiative_owner);
CREATE INDEX idx_savings_initiatives_dates ON savings_initiatives(start_date, target_completion_date);

-- Data Migration and Backfill Scripts
-- =============================================================================

-- Backfill contracts from existing spend data (example approach)
INSERT INTO contracts (
    contract_id,
    vendor_id,
    contract_name,
    contract_type,
    contract_value,
    start_date,
    end_date,
    contract_status,
    contract_owner
)
SELECT DISTINCT
    'LEGACY-' || vendor_id as contract_id,
    vendor_id,
    'Legacy Agreement - ' || vendor_name as contract_name,
    'Framework Agreement' as contract_type,
    total_spend as contract_value,
    min_date as start_date,
    CASE 
        WHEN max_date < DATE('2019-01-01') THEN DATE(max_date, '+2 years')
        ELSE DATE('2025-12-31')
    END as end_date,
    CASE 
        WHEN max_date < DATE('2020-01-01') THEN 'Expired'
        ELSE 'Active'
    END as contract_status,
    'System Migration' as contract_owner
FROM (
    SELECT 
        v.vendor_id,
        v.vendor_name,
        SUM(s.spend_amount) as total_spend,
        MIN(t.date) as min_date,
        MAX(t.date) as max_date
    FROM vendor_dimension v
    JOIN spend_fact s ON v.vendor_id = s.vendor_id
    JOIN time_dimension t ON s.time_id = t.time_id
    GROUP BY v.vendor_id, v.vendor_name
    HAVING SUM(s.spend_amount) > 10000  -- Only create contracts for significant suppliers
) vendor_summary;

-- Initialize supplier scorecards with baseline data
INSERT INTO supplier_scorecard (
    scorecard_id,
    vendor_id,
    reporting_period,
    overall_score,
    delivery_score,
    quality_score,
    cost_score,
    performance_tier
)
SELECT 
    'BASELINE-' || vendor_id || '-2024' as scorecard_id,
    vendor_id,
    'BASELINE-2024' as reporting_period,
    CASE 
        WHEN vendor_tier = 'Strategic' THEN 4.0
        WHEN vendor_tier = 'Preferred' THEN 3.5
        WHEN vendor_tier = 'Approved' THEN 3.0
        ELSE 2.5
    END as overall_score,
    3.0 as delivery_score,
    3.0 as quality_score,
    3.0 as cost_score,
    COALESCE(vendor_tier, 'Approved') as performance_tier
FROM vendor_dimension
WHERE vendor_status = 'Active';

-- Validation Queries
-- =============================================================================

-- Verify table creation and constraints
SELECT 
    table_name,
    COUNT(*) as row_count
FROM (
    SELECT 'contracts' as table_name, COUNT(*) as count FROM contracts
    UNION ALL
    SELECT 'contract_renewals', COUNT(*) FROM contract_renewals
    UNION ALL
    SELECT 'contract_performance', COUNT(*) FROM contract_performance
    UNION ALL
    SELECT 'supplier_scorecard', COUNT(*) FROM supplier_scorecard
    UNION ALL
    SELECT 'delivery_performance', COUNT(*) FROM delivery_performance
    UNION ALL
    SELECT 'quality_performance', COUNT(*) FROM quality_performance
    UNION ALL
    SELECT 'savings_initiatives', COUNT(*) FROM savings_initiatives
) table_counts;

-- Verify foreign key relationships
SELECT 
    'Contract-Vendor Links' as check_name,
    COUNT(*) as total_contracts,
    COUNT(DISTINCT v.vendor_id) as linked_vendors
FROM contracts c
LEFT JOIN vendor_dimension v ON c.vendor_id = v.vendor_id;

-- Performance test sample queries
SELECT 
    'Performance Test' as test_name,
    'Contract Expiry Report' as query_type,
    COUNT(*) as contracts_expiring_soon
FROM contracts 
WHERE end_date BETWEEN DATE('now') AND DATE('now', '+90 days')
  AND contract_status = 'Active';

-- =============================================================================
-- MIGRATION COMPLETE NOTIFICATION
-- =============================================================================

SELECT 
    'Phase 1 Migration Complete' as status,
    datetime('now') as completion_time,
    '7 tables created with indexes and constraints' as summary,
    'Ready for data population and testing' as next_steps;
