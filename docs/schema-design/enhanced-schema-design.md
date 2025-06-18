# Enhanced Schema Design Specifications

## Overview

This document outlines the comprehensive database schema enhancements required to support all 17 C-Suite procurement reports. The enhanced schema introduces 35+ new tables across 6 business modules while maintaining compatibility with the existing database structure.

## Current Schema Assessment

### Existing Tables
- `time_dimension` (3,652 records) - Complete temporal framework
- `vendor_dimension` (2,716 records) - Comprehensive vendor master data
- `commodity_dimension` (6,569 records) - Category and commodity classification
- `spend_fact` (72,464 records) - Core transactional data

### Schema Strengths
- ✅ Strong dimensional modeling foundation
- ✅ Comprehensive vendor intelligence (ESG, diversity, risk ratings)
- ✅ Detailed commodity categorization and sourcing complexity
- ✅ Complete spend transaction history

### Critical Gaps
- ❌ No contract lifecycle management
- ❌ Limited supplier performance tracking
- ❌ Missing process compliance framework
- ❌ Absent financial analytics capabilities

## Enhanced Schema Architecture

### Module 1: Contract Lifecycle Management

#### 1.1 contracts
```sql
CREATE TABLE contracts (
    contract_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    contract_name VARCHAR(200) NOT NULL,
    contract_type VARCHAR(50), -- Master, Statement of Work, Purchase Order
    contract_value DECIMAL(15,2),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    auto_renewal_flag BOOLEAN DEFAULT FALSE,
    renewal_notice_days INTEGER DEFAULT 90,
    contract_status VARCHAR(30), -- Active, Expired, Terminated, Under Review
    contract_owner VARCHAR(100),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 1.2 contract_renewals
```sql
CREATE TABLE contract_renewals (
    renewal_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contracts(contract_id),
    renewal_type VARCHAR(30), -- Automatic, Negotiated, Re-tendered
    renewal_date DATE,
    new_end_date DATE,
    value_change_pct DECIMAL(5,2),
    renewal_status VARCHAR(30), -- Planned, In Progress, Completed
    stakeholder_approved BOOLEAN DEFAULT FALSE,
    renewal_rationale TEXT
);
```

#### 1.3 contract_performance
```sql
CREATE TABLE contract_performance (
    performance_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contracts(contract_id),
    reporting_period VARCHAR(20), -- Q1-2024, Jan-2024
    contract_utilization_pct DECIMAL(5,2),
    savings_realized DECIMAL(15,2),
    sla_compliance_pct DECIMAL(5,2),
    performance_score INTEGER CHECK (performance_score BETWEEN 1 AND 5),
    issues_reported INTEGER DEFAULT 0,
    escalations_count INTEGER DEFAULT 0
);
```

#### 1.4 contract_clauses
```sql
CREATE TABLE contract_clauses (
    clause_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contracts(contract_id),
    clause_type VARCHAR(50), -- Payment Terms, SLA, Penalty, Termination
    clause_description TEXT,
    compliance_required BOOLEAN DEFAULT TRUE,
    monitoring_required BOOLEAN DEFAULT FALSE,
    penalty_amount DECIMAL(15,2)
);
```

#### 1.5 contract_amendments
```sql
CREATE TABLE contract_amendments (
    amendment_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contracts(contract_id),
    amendment_date DATE NOT NULL,
    amendment_type VARCHAR(50), -- Price Change, Scope Change, Term Extension
    amendment_description TEXT,
    value_impact DECIMAL(15,2),
    approved_by VARCHAR(100),
    effective_date DATE
);
```

### Module 2: Supplier Performance Management

#### 2.1 supplier_scorecard
```sql
CREATE TABLE supplier_scorecard (
    scorecard_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    reporting_period VARCHAR(20),
    overall_score DECIMAL(4,2) CHECK (overall_score BETWEEN 0 AND 5),
    delivery_score DECIMAL(4,2) CHECK (delivery_score BETWEEN 0 AND 5),
    quality_score DECIMAL(4,2) CHECK (quality_score BETWEEN 0 AND 5),
    cost_score DECIMAL(4,2) CHECK (cost_score BETWEEN 0 AND 5),
    service_score DECIMAL(4,2) CHECK (service_score BETWEEN 0 AND 5),
    innovation_score DECIMAL(4,2) CHECK (innovation_score BETWEEN 0 AND 5),
    esg_score DECIMAL(4,2) CHECK (esg_score BETWEEN 0 AND 5),
    performance_tier VARCHAR(20), -- Strategic, Preferred, Approved, Monitor
    improvement_required BOOLEAN DEFAULT FALSE
);
```

#### 2.2 delivery_performance
```sql
CREATE TABLE delivery_performance (
    delivery_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    po_number VARCHAR(50),
    promised_date DATE,
    actual_delivery_date DATE,
    quantity_ordered INTEGER,
    quantity_delivered INTEGER,
    on_time_flag BOOLEAN,
    in_full_flag BOOLEAN,
    otif_flag BOOLEAN, -- On Time In Full
    delay_days INTEGER DEFAULT 0,
    delay_reason VARCHAR(100)
);
```

#### 2.3 quality_performance
```sql
CREATE TABLE quality_performance (
    quality_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    inspection_date DATE,
    commodity_id INTEGER REFERENCES commodity_dimension(commodity_id),
    total_quantity INTEGER,
    defective_quantity INTEGER DEFAULT 0,
    defect_rate DECIMAL(5,2),
    quality_rating INTEGER CHECK (quality_rating BETWEEN 1 AND 5),
    corrective_action_required BOOLEAN DEFAULT FALSE,
    corrective_action_description TEXT
);
```

#### 2.4 supplier_audits
```sql
CREATE TABLE supplier_audits (
    audit_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    audit_type VARCHAR(50), -- Quality, ESG, Financial, Compliance
    audit_date DATE,
    auditor_name VARCHAR(100),
    audit_score INTEGER CHECK (audit_score BETWEEN 0 AND 100),
    findings_summary TEXT,
    corrective_actions_required INTEGER DEFAULT 0,
    follow_up_date DATE,
    audit_status VARCHAR(30) -- Completed, In Progress, Scheduled
);
```

### Module 3: Risk & Incident Management

#### 3.1 supplier_risk_assessment
```sql
CREATE TABLE supplier_risk_assessment (
    risk_assessment_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    assessment_date DATE,
    financial_risk_score INTEGER CHECK (financial_risk_score BETWEEN 1 AND 5),
    operational_risk_score INTEGER CHECK (operational_risk_score BETWEEN 1 AND 5),
    geopolitical_risk_score INTEGER CHECK (geopolitical_risk_score BETWEEN 1 AND 5),
    esg_risk_score INTEGER CHECK (esg_risk_score BETWEEN 1 AND 5),
    cyber_risk_score INTEGER CHECK (cyber_risk_score BETWEEN 1 AND 5),
    overall_risk_rating VARCHAR(20), -- Low, Medium, High, Critical
    risk_appetite VARCHAR(20), -- Acceptable, Monitor, Mitigate, Exit
    next_review_date DATE
);
```

#### 3.2 risk_incidents
```sql
CREATE TABLE risk_incidents (
    incident_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    incident_date DATE,
    incident_type VARCHAR(50), -- Quality, Delivery, Financial, Compliance, Cyber
    incident_severity VARCHAR(20), -- Low, Medium, High, Critical
    incident_description TEXT,
    business_impact TEXT,
    financial_impact DECIMAL(15,2),
    resolution_date DATE,
    resolution_description TEXT,
    lessons_learned TEXT,
    status VARCHAR(30) -- Open, In Progress, Resolved, Closed
);
```

#### 3.3 risk_mitigation_plans
```sql
CREATE TABLE risk_mitigation_plans (
    mitigation_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    risk_type VARCHAR(50),
    mitigation_strategy TEXT,
    implementation_timeline VARCHAR(100),
    responsible_party VARCHAR(100),
    monitoring_frequency VARCHAR(30), -- Weekly, Monthly, Quarterly
    effectiveness_rating INTEGER CHECK (effectiveness_rating BETWEEN 1 AND 5),
    status VARCHAR(30), -- Planned, Active, Completed, Cancelled
    last_review_date DATE
);
```

#### 3.4 business_continuity
```sql
CREATE TABLE business_continuity (
    continuity_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    commodity_id INTEGER REFERENCES commodity_dimension(commodity_id),
    criticality_level VARCHAR(20), -- Critical, Important, Standard
    backup_supplier_id INTEGER REFERENCES vendor_dimension(vendor_id),
    recovery_time_objective_days INTEGER,
    recovery_point_objective_days INTEGER,
    continuity_plan_document VARCHAR(200),
    last_tested_date DATE,
    test_result VARCHAR(50), -- Successful, Partial, Failed
    next_test_date DATE
);
```

### Module 4: Financial Performance & Savings

#### 4.1 savings_initiatives
```sql
CREATE TABLE savings_initiatives (
    initiative_id VARCHAR(50) PRIMARY KEY,
    initiative_name VARCHAR(200),
    category_id INTEGER REFERENCES commodity_dimension(commodity_id),
    initiative_type VARCHAR(50), -- Price Negotiation, Demand Reduction, Process
    baseline_amount DECIMAL(15,2),
    forecasted_savings DECIMAL(15,2),
    realized_savings DECIMAL(15,2),
    realization_rate DECIMAL(5,2),
    savings_type VARCHAR(30), -- Hard, Soft, Cost Avoidance
    initiative_status VARCHAR(30), -- Pipeline, Committed, Realized, Validated
    start_date DATE,
    target_completion_date DATE,
    initiative_owner VARCHAR(100)
);
```

#### 4.2 payment_terms_analysis
```sql
CREATE TABLE payment_terms_analysis (
    analysis_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    contract_id VARCHAR(50) REFERENCES contracts(contract_id),
    payment_terms_days INTEGER,
    early_payment_discount_pct DECIMAL(5,2),
    discount_window_days INTEGER,
    average_payment_days DECIMAL(5,2),
    discount_utilization_rate DECIMAL(5,2),
    working_capital_impact DECIMAL(15,2),
    reporting_period VARCHAR(20)
);
```

#### 4.3 procurement_roi
```sql
CREATE TABLE procurement_roi (
    roi_id VARCHAR(50) PRIMARY KEY,
    reporting_period VARCHAR(20),
    procurement_costs DECIMAL(15,2),
    total_savings_delivered DECIMAL(15,2),
    cost_avoidance_value DECIMAL(15,2),
    process_efficiency_value DECIMAL(15,2),
    total_value_delivered DECIMAL(15,2),
    roi_ratio DECIMAL(5,2),
    category VARCHAR(100),
    business_unit VARCHAR(100)
);
```

### Module 5: Process Compliance & Automation

#### 5.1 procurement_transactions
```sql
CREATE TABLE procurement_transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    po_number VARCHAR(50),
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    commodity_id INTEGER REFERENCES commodity_dimension(commodity_id),
    transaction_date DATE,
    transaction_type VARCHAR(30), -- PO, Contract Release, Direct Buy
    approval_required BOOLEAN DEFAULT TRUE,
    approved_by VARCHAR(100),
    approval_date DATE,
    sourcing_method VARCHAR(50), -- RFQ, RFP, Auction, Direct Award
    competitive_quotes INTEGER DEFAULT 0,
    policy_compliance BOOLEAN DEFAULT TRUE,
    compliance_exceptions TEXT,
    automation_level VARCHAR(30) -- Manual, Semi-automated, Fully automated
);
```

#### 5.2 maverick_spend
```sql
CREATE TABLE maverick_spend (
    maverick_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    spend_amount DECIMAL(15,2),
    transaction_date DATE,
    business_unit VARCHAR(100),
    maverick_type VARCHAR(50), -- Off-contract, Unapproved Supplier, Policy Bypass
    reason_code VARCHAR(100),
    approval_override VARCHAR(100),
    compliance_risk_rating VARCHAR(20), -- Low, Medium, High
    corrective_action_required BOOLEAN DEFAULT FALSE,
    corrective_action_taken TEXT
);
```

#### 5.3 approval_workflows
```sql
CREATE TABLE approval_workflows (
    workflow_id VARCHAR(50) PRIMARY KEY,
    transaction_type VARCHAR(50),
    approval_threshold_amount DECIMAL(15,2),
    required_approvers TEXT, -- JSON array of approver roles
    approval_sequence INTEGER,
    current_approver VARCHAR(100),
    approval_status VARCHAR(30), -- Pending, Approved, Rejected, Escalated
    time_in_queue_hours INTEGER,
    sla_compliance BOOLEAN DEFAULT TRUE,
    escalation_triggered BOOLEAN DEFAULT FALSE
);
```

#### 5.4 digital_adoption
```sql
CREATE TABLE digital_adoption (
    adoption_id VARCHAR(50) PRIMARY KEY,
    process_area VARCHAR(50), -- Sourcing, Contracting, P2P, Analytics
    tool_name VARCHAR(100),
    user_count INTEGER,
    transaction_volume INTEGER,
    automation_rate DECIMAL(5,2),
    user_satisfaction_score DECIMAL(3,1),
    training_completion_rate DECIMAL(5,2),
    adoption_date DATE,
    reporting_period VARCHAR(20)
);
```

### Module 6: ESG & Sustainability

#### 6.1 esg_assessments
```sql
CREATE TABLE esg_assessments (
    assessment_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    assessment_date DATE,
    environmental_score INTEGER CHECK (environmental_score BETWEEN 0 AND 100),
    social_score INTEGER CHECK (social_score BETWEEN 0 AND 100),
    governance_score INTEGER CHECK (governance_score BETWEEN 0 AND 100),
    overall_esg_rating VARCHAR(20), -- A+, A, B+, B, C+, C, D
    carbon_footprint_scope1 DECIMAL(15,2),
    carbon_footprint_scope2 DECIMAL(15,2),
    carbon_footprint_scope3 DECIMAL(15,2),
    sustainability_certifications TEXT, -- JSON array
    assessment_provider VARCHAR(100) -- EcoVadis, CDP, Internal
);
```

#### 6.2 diversity_suppliers
```sql
CREATE TABLE diversity_suppliers (
    diversity_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    certification_type VARCHAR(50), -- Women-owned, Minority-owned, Veteran-owned
    certification_body VARCHAR(100),
    certification_date DATE,
    expiry_date DATE,
    certification_number VARCHAR(100),
    annual_spend_commitment DECIMAL(15,2),
    actual_annual_spend DECIMAL(15,2),
    performance_against_commitment DECIMAL(5,2)
);
```

#### 6.3 sustainability_tracking
```sql
CREATE TABLE sustainability_tracking (
    tracking_id VARCHAR(50) PRIMARY KEY,
    vendor_id INTEGER REFERENCES vendor_dimension(vendor_id),
    reporting_period VARCHAR(20),
    carbon_emissions_reduction_pct DECIMAL(5,2),
    renewable_energy_usage_pct DECIMAL(5,2),
    waste_reduction_pct DECIMAL(5,2),
    water_usage_efficiency_pct DECIMAL(5,2),
    sustainability_goals_met INTEGER,
    sustainability_initiatives_active INTEGER,
    green_product_percentage DECIMAL(5,2)
);
```

## Performance Optimization Strategy

### Indexing Strategy
```sql
-- Core relationship indexes
CREATE INDEX idx_contracts_vendor ON contracts(vendor_id);
CREATE INDEX idx_contracts_dates ON contracts(start_date, end_date);
CREATE INDEX idx_supplier_scorecard_vendor_period ON supplier_scorecard(vendor_id, reporting_period);
CREATE INDEX idx_delivery_performance_vendor ON delivery_performance(vendor_id);
CREATE INDEX idx_risk_incidents_vendor_date ON risk_incidents(vendor_id, incident_date);
CREATE INDEX idx_savings_initiatives_category ON savings_initiatives(category_id);
CREATE INDEX idx_procurement_transactions_vendor ON procurement_transactions(vendor_id);
CREATE INDEX idx_esg_assessments_vendor ON esg_assessments(vendor_id);

-- Reporting optimization indexes
CREATE INDEX idx_contracts_status_renewal ON contracts(contract_status, auto_renewal_flag);
CREATE INDEX idx_supplier_scorecard_performance_tier ON supplier_scorecard(performance_tier);
CREATE INDEX idx_delivery_performance_otif ON delivery_performance(otif_flag);
CREATE INDEX idx_risk_assessment_rating ON supplier_risk_assessment(overall_risk_rating);
```

### Database Size Estimation
- **Current Database**: ~50MB
- **Enhanced Schema**: ~500MB (estimated with 5 years of enhanced data)
- **Recommended Migration**: SQLite → PostgreSQL for production scale

## Migration Strategy

### Phase 1: Foundation (Months 1-2)
1. **Contract Management Tables**: contracts, contract_renewals, contract_performance
2. **Basic Performance Tracking**: supplier_scorecard, delivery_performance
3. **Core Financial Tables**: savings_initiatives, procurement_roi

### Phase 2: Process Excellence (Months 3-4)
1. **Risk Management**: supplier_risk_assessment, risk_incidents
2. **Compliance Tracking**: procurement_transactions, maverick_spend
3. **Quality Management**: quality_performance, supplier_audits

### Phase 3: Strategic Intelligence (Months 5-6)
1. **ESG Framework**: esg_assessments, diversity_suppliers, sustainability_tracking
2. **Advanced Analytics**: business_continuity, risk_mitigation_plans
3. **Digital Maturity**: digital_adoption, approval_workflows

## Data Integration Points

### Existing System Integration
- **ERP Systems**: Purchase orders, invoices, payments
- **Contract Management**: Contract documents and terms
- **Supplier Portals**: Performance data and certifications
- **Risk Platforms**: Third-party risk ratings and assessments

### Real-Time Data Feeds
- **Financial Systems**: Payment terms and working capital metrics
- **Quality Systems**: Inspection results and defect tracking
- **Logistics Systems**: Delivery performance and lead times
- **ESG Platforms**: Sustainability scores and certifications

## Conclusion

This enhanced schema design provides a comprehensive foundation for supporting all 17 C-Suite reports while maintaining performance and scalability. The modular approach enables phased implementation with immediate value delivery in Phase 1.

**Next Steps**: Review [Implementation Roadmap](../implementation/roadmap.md) for detailed deployment planning.
