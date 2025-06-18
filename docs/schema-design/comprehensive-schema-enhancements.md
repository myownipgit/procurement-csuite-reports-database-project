# Comprehensive Schema Enhancement Specifications

## Executive Summary

This document provides detailed database schema enhancements required to support all 17 C-Suite procurement reports. The enhancement includes 47 new tables organized into 6 business modules, designed to transform the current database into a comprehensive procurement intelligence platform.

## Current Database Foundation

Based on the existing schema analysis:
- **Transactions**: 72,464 records ($509.9M spend, 2009-2018)
- **Vendors**: 2,716 active suppliers with tier/diversity/ESG classifications  
- **Categories**: 6,569 commodity categories tracked
- **Geographic**: Multi-country coverage with spend distribution

## Enhancement Architecture

### Module 1: Contract Lifecycle Management (9 tables)

```sql
-- Core contract management
CREATE TABLE contract_master (
    contract_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    contract_name VARCHAR(200),
    contract_type VARCHAR(50),
    start_date DATE,
    end_date DATE,
    value_amount DECIMAL(15,2),
    currency_code VARCHAR(3),
    auto_renewal BOOLEAN DEFAULT FALSE,
    status VARCHAR(20),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_contract_supplier (supplier_id),
    INDEX idx_contract_expiry (end_date)
);

-- Contract terms and conditions
CREATE TABLE contract_terms (
    term_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contract_master(contract_id),
    term_type VARCHAR(50), -- payment_terms, sla, warranty, etc.
    description TEXT,
    notice_period_days INTEGER,
    renewal_clause TEXT,
    effective_date DATE,
    INDEX idx_terms_contract (contract_id)
);

-- Contract renewal planning
CREATE TABLE renewal_planning (
    renewal_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contract_master(contract_id),
    renewal_strategy VARCHAR(50), -- renegotiate, retender, extend, terminate
    current_status VARCHAR(30),
    assigned_owner VARCHAR(50),
    target_completion_date DATE,
    stakeholder_approval_status VARCHAR(30),
    business_case TEXT,
    INDEX idx_renewal_contract (contract_id),
    INDEX idx_renewal_date (target_completion_date)
);

-- Contract performance tracking
CREATE TABLE contract_performance (
    performance_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contract_master(contract_id),
    measurement_period VARCHAR(20),
    kpi_score DECIMAL(5,2),
    compliance_rating VARCHAR(10),
    issues_count INTEGER DEFAULT 0,
    performance_notes TEXT,
    recorded_date DATE,
    INDEX idx_performance_contract (contract_id),
    INDEX idx_performance_period (measurement_period)
);

-- Legal and compliance requirements
CREATE TABLE legal_requirements (
    requirement_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contract_master(contract_id),
    requirement_type VARCHAR(50), -- insurance, certifications, regulatory
    description TEXT,
    status VARCHAR(20),
    review_date DATE,
    compliance_status VARCHAR(20),
    responsible_party VARCHAR(100),
    INDEX idx_legal_contract (contract_id)
);

-- Contract financials and projections
CREATE TABLE contract_financials (
    financial_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contract_master(contract_id),
    current_value DECIMAL(15,2),
    projected_value DECIMAL(15,2),
    cost_delta DECIMAL(15,2),
    budget_impact DECIMAL(15,2),
    currency_code VARCHAR(3),
    analysis_date DATE,
    INDEX idx_financials_contract (contract_id)
);

-- Contract expiry calendar view
CREATE TABLE contract_expiry_calendar (
    calendar_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contract_master(contract_id),
    supplier_id VARCHAR(50),
    expiry_date DATE,
    auto_renewal_flag BOOLEAN,
    notice_period_days INTEGER,
    renewal_deadline DATE,
    business_criticality VARCHAR(20),
    INDEX idx_expiry_date (expiry_date),
    INDEX idx_expiry_supplier (supplier_id)
);

-- Contract utilization tracking
CREATE TABLE contract_utilization (
    utilization_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contract_master(contract_id),
    period_year INTEGER,
    period_month INTEGER,
    available_spend DECIMAL(15,2),
    actual_spend DECIMAL(15,2),
    utilization_rate DECIMAL(5,2),
    leakage_amount DECIMAL(15,2),
    INDEX idx_util_contract (contract_id),
    INDEX idx_util_period (period_year, period_month)
);

-- Contract leakage analysis
CREATE TABLE contract_leakage_analysis (
    leakage_id VARCHAR(50) PRIMARY KEY,
    contract_id VARCHAR(50) REFERENCES contract_master(contract_id),
    alternative_supplier_id VARCHAR(50),
    leakage_amount DECIMAL(15,2),
    reason_code VARCHAR(50),
    business_justification TEXT,
    identified_date DATE,
    INDEX idx_leakage_contract (contract_id)
);
```

### Module 2: Supplier Performance Management (8 tables)

```sql
-- Core supplier performance metrics
CREATE TABLE supplier_performance_metrics (
    metric_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    metric_type VARCHAR(50), -- otif, quality, cost, delivery
    metric_value DECIMAL(10,4),
    target_value DECIMAL(10,4),
    measurement_period VARCHAR(20),
    unit_of_measure VARCHAR(20),
    performance_trend VARCHAR(10), -- improving, declining, stable
    INDEX idx_perf_supplier (supplier_id),
    INDEX idx_perf_type (metric_type)
);

-- Quality performance tracking
CREATE TABLE supplier_quality_metrics (
    quality_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    defect_rate DECIMAL(8,4),
    return_rate DECIMAL(8,4),
    warranty_claims_count INTEGER,
    audit_score DECIMAL(5,2),
    measurement_date DATE,
    quality_certification VARCHAR(50),
    INDEX idx_quality_supplier (supplier_id),
    INDEX idx_quality_date (measurement_date)
);

-- Delivery performance tracking
CREATE TABLE supplier_delivery_performance (
    delivery_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    otif_percentage DECIMAL(5,2),
    lead_time_actual INTEGER,
    lead_time_target INTEGER,
    delivery_variance INTEGER,
    measurement_period VARCHAR(20),
    on_time_deliveries INTEGER,
    total_deliveries INTEGER,
    INDEX idx_delivery_supplier (supplier_id)
);

-- Supplier incidents and issues
CREATE TABLE supplier_incidents (
    incident_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    incident_type VARCHAR(50), -- quality, delivery, service, compliance
    severity VARCHAR(10), -- low, medium, high, critical
    impact_description TEXT,
    incident_date DATE,
    resolution_date DATE,
    resolution_time_hours INTEGER,
    status VARCHAR(20),
    assigned_owner VARCHAR(50),
    INDEX idx_incident_supplier (supplier_id),
    INDEX idx_incident_date (incident_date)
);

-- SLA tracking and compliance
CREATE TABLE supplier_sla_tracking (
    sla_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    sla_type VARCHAR(50),
    target_value DECIMAL(10,2),
    actual_value DECIMAL(10,2),
    compliance_status VARCHAR(20),
    measurement_period VARCHAR(20),
    penalty_amount DECIMAL(10,2) DEFAULT 0,
    INDEX idx_sla_supplier (supplier_id)
);

-- Innovation and collaboration tracking
CREATE TABLE supplier_innovation_tracking (
    innovation_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    project_name VARCHAR(200),
    innovation_type VARCHAR(50), -- cost_reduction, process_improvement, product_innovation
    value_delivered DECIMAL(12,2),
    project_status VARCHAR(20),
    start_date DATE,
    completion_date DATE,
    business_impact_description TEXT,
    INDEX idx_innovation_supplier (supplier_id)
);

-- Performance scorecards
CREATE TABLE supplier_scorecards (
    scorecard_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    overall_score DECIMAL(5,2),
    delivery_score DECIMAL(5,2),
    quality_score DECIMAL(5,2),
    cost_score DECIMAL(5,2),
    service_score DECIMAL(5,2),
    innovation_score DECIMAL(5,2),
    period_year INTEGER,
    period_quarter INTEGER,
    tier_classification VARCHAR(20),
    INDEX idx_scorecard_supplier (supplier_id),
    INDEX idx_scorecard_period (period_year, period_quarter)
);

-- Strategic supplier roadmap
CREATE TABLE strategic_supplier_roadmap (
    roadmap_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    strategic_objective TEXT,
    target_completion_date DATE,
    current_status VARCHAR(30),
    milestone_description TEXT,
    business_impact TEXT,
    assigned_owner VARCHAR(50),
    INDEX idx_roadmap_supplier (supplier_id)
);
```

### Module 3: Risk & Incident Management (7 tables)

```sql
-- Comprehensive supplier risk assessment
CREATE TABLE supplier_risk_assessment (
    risk_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    risk_category VARCHAR(50), -- financial, operational, strategic, compliance
    risk_type VARCHAR(50),
    risk_score INTEGER CHECK (risk_score BETWEEN 1 AND 10),
    probability VARCHAR(10), -- low, medium, high
    impact VARCHAR(10), -- low, medium, high
    assessment_date DATE,
    assessor VARCHAR(50),
    mitigation_plan TEXT,
    INDEX idx_risk_supplier (supplier_id),
    INDEX idx_risk_category (risk_category)
);

-- Geographic and country risk data
CREATE TABLE geographic_risk (
    geo_risk_id VARCHAR(50) PRIMARY KEY,
    country_code VARCHAR(3),
    country_name VARCHAR(100),
    political_risk_score INTEGER,
    economic_risk_score INTEGER,
    operational_risk_score INTEGER,
    overall_risk_level VARCHAR(10),
    last_updated DATE,
    risk_trend VARCHAR(10),
    INDEX idx_geo_country (country_code)
);

-- Category-specific risk profiles
CREATE TABLE category_risk_profile (
    category_risk_id VARCHAR(50) PRIMARY KEY,
    category_id VARCHAR(50),
    category_name VARCHAR(200),
    supply_security_score INTEGER,
    price_volatility_index DECIMAL(5,2),
    regulatory_complexity VARCHAR(10),
    market_concentration VARCHAR(10),
    overall_category_risk VARCHAR(10),
    last_assessment_date DATE,
    INDEX idx_cat_risk_category (category_id)
);

-- Operational risk tracking
CREATE TABLE operational_risks (
    operational_risk_id VARCHAR(50) PRIMARY KEY,
    risk_type VARCHAR(50), -- single_source, capacity, quality, cyber
    risk_description TEXT,
    impact_level VARCHAR(10),
    probability_score INTEGER,
    affected_suppliers TEXT, -- JSON array or comma-separated
    affected_categories TEXT, -- JSON array or comma-separated
    mitigation_status VARCHAR(20),
    owner VARCHAR(50),
    INDEX idx_op_risk_type (risk_type)
);

-- Compliance violations and tracking
CREATE TABLE compliance_violations (
    violation_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    violation_type VARCHAR(50), -- esg, regulatory, contractual, policy
    severity VARCHAR(10),
    violation_description TEXT,
    identified_date DATE,
    resolution_status VARCHAR(20),
    resolution_date DATE,
    financial_impact DECIMAL(12,2),
    corrective_actions TEXT,
    INDEX idx_violation_supplier (supplier_id),
    INDEX idx_violation_date (identified_date)
);

-- Risk mitigation planning and tracking
CREATE TABLE risk_mitigation_plans (
    mitigation_id VARCHAR(50) PRIMARY KEY,
    risk_id VARCHAR(50) REFERENCES supplier_risk_assessment(risk_id),
    mitigation_action TEXT,
    assigned_owner VARCHAR(50),
    target_completion_date DATE,
    current_status VARCHAR(20),
    effectiveness_score INTEGER,
    cost_of_mitigation DECIMAL(10,2),
    INDEX idx_mitigation_risk (risk_id)
);

-- Business continuity and disruption tracking
CREATE TABLE business_continuity_tracking (
    continuity_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    disruption_type VARCHAR(50),
    disruption_date DATE,
    impact_duration_hours INTEGER,
    business_impact_description TEXT,
    recovery_actions TEXT,
    lessons_learned TEXT,
    INDEX idx_continuity_supplier (supplier_id)
);
```

### Module 4: Financial Performance & Savings (8 tables)

```sql
-- Savings initiative tracking
CREATE TABLE savings_initiatives (
    initiative_id VARCHAR(50) PRIMARY KEY,
    initiative_name VARCHAR(200),
    category_id VARCHAR(50),
    initiative_type VARCHAR(50), -- negotiation, consolidation, specification
    owner VARCHAR(50),
    forecast_savings DECIMAL(12,2),
    target_completion_date DATE,
    current_status VARCHAR(20),
    methodology VARCHAR(100),
    INDEX idx_savings_category (category_id),
    INDEX idx_savings_owner (owner)
);

-- Baseline pricing and benchmarking
CREATE TABLE baseline_pricing (
    baseline_id VARCHAR(50) PRIMARY KEY,
    item_code VARCHAR(50),
    item_description VARCHAR(200),
    baseline_price DECIMAL(10,4),
    effective_date DATE,
    inflation_rate DECIMAL(5,4),
    volume_basis VARCHAR(50),
    pricing_source VARCHAR(50),
    INDEX idx_baseline_item (item_code),
    INDEX idx_baseline_date (effective_date)
);

-- Savings realization tracking
CREATE TABLE savings_realization (
    realization_id VARCHAR(50) PRIMARY KEY,
    initiative_id VARCHAR(50) REFERENCES savings_initiatives(initiative_id),
    period_year INTEGER,
    period_month INTEGER,
    forecasted_savings DECIMAL(12,2),
    realized_savings DECIMAL(12,2),
    variance DECIMAL(12,2),
    variance_reason TEXT,
    validation_status VARCHAR(20),
    INDEX idx_real_initiative (initiative_id),
    INDEX idx_real_period (period_year, period_month)
);

-- Financial validation and sign-off
CREATE TABLE financial_validation (
    validation_id VARCHAR(50) PRIMARY KEY,
    initiative_id VARCHAR(50) REFERENCES savings_initiatives(initiative_id),
    finance_signoff BOOLEAN DEFAULT FALSE,
    signoff_by VARCHAR(50),
    signoff_date DATE,
    gl_account VARCHAR(20),
    booking_date DATE,
    validation_notes TEXT,
    INDEX idx_validation_initiative (initiative_id)
);

-- Savings sustainability assessment
CREATE TABLE savings_sustainability (
    sustainability_id VARCHAR(50) PRIMARY KEY,
    initiative_id VARCHAR(50) REFERENCES savings_initiatives(initiative_id),
    duration_months INTEGER,
    repeatability VARCHAR(20), -- one_time, recurring, renewable
    sustainability_risk VARCHAR(10),
    risk_factors TEXT,
    monitoring_plan TEXT,
    INDEX idx_sustain_initiative (initiative_id)
);

-- Procurement ROI metrics
CREATE TABLE procurement_roi_metrics (
    roi_id VARCHAR(50) PRIMARY KEY,
    period_year INTEGER,
    period_quarter INTEGER,
    procurement_cost DECIMAL(12,2),
    value_delivered DECIMAL(12,2),
    hard_savings DECIMAL(12,2),
    cost_avoidance DECIMAL(12,2),
    process_efficiency_value DECIMAL(12,2),
    roi_ratio DECIMAL(8,4),
    INDEX idx_roi_period (period_year, period_quarter)
);

-- Working capital optimization
CREATE TABLE working_capital_analysis (
    wc_id VARCHAR(50) PRIMARY KEY,
    period_year INTEGER,
    period_month INTEGER,
    cash_locked_in_payables DECIMAL(15,2),
    cash_released DECIMAL(15,2),
    optimization_opportunity DECIMAL(15,2),
    dpo_current DECIMAL(5,2),
    dpo_target DECIMAL(5,2),
    payment_term_improvements TEXT,
    INDEX idx_wc_period (period_year, period_month)
);

-- Payment terms and DPO tracking
CREATE TABLE payment_terms_analysis (
    terms_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    contracted_terms INTEGER,
    actual_avg_terms DECIMAL(5,2),
    variance_days DECIMAL(5,2),
    early_payment_discount_rate DECIMAL(5,4),
    discount_uptake_rate DECIMAL(5,2),
    savings_from_discounts DECIMAL(10,2),
    period_year INTEGER,
    period_month INTEGER,
    INDEX idx_terms_supplier (supplier_id)
);
```

### Module 5: Process Compliance & Automation (9 tables)

```sql
-- Procurement policy definitions
CREATE TABLE procurement_policies (
    policy_id VARCHAR(50) PRIMARY KEY,
    policy_name VARCHAR(200),
    policy_type VARCHAR(50), -- approval, sourcing, compliance
    threshold_amount DECIMAL(12,2),
    approval_required BOOLEAN,
    competitive_sourcing_required BOOLEAN,
    documentation_requirements TEXT,
    effective_date DATE,
    INDEX idx_policy_type (policy_type)
);

-- Purchase policy compliance tracking
CREATE TABLE purchase_policy_compliance (
    compliance_id VARCHAR(50) PRIMARY KEY,
    transaction_id VARCHAR(50),
    policy_id VARCHAR(50) REFERENCES procurement_policies(policy_id),
    compliance_status VARCHAR(20),
    violation_type VARCHAR(50),
    exception_justification TEXT,
    approver VARCHAR(50),
    compliance_date DATE,
    INDEX idx_compliance_transaction (transaction_id),
    INDEX idx_compliance_policy (policy_id)
);

-- Audit trail and documentation
CREATE TABLE audit_trail_tracking (
    audit_id VARCHAR(50) PRIMARY KEY,
    transaction_id VARCHAR(50),
    documentation_complete BOOLEAN,
    approval_chain_complete BOOLEAN,
    required_documents TEXT, -- JSON array
    missing_documents TEXT, -- JSON array
    compliance_score DECIMAL(5,2),
    audit_date DATE,
    auditor VARCHAR(50),
    INDEX idx_audit_transaction (transaction_id)
);

-- Threshold monitoring and violations
CREATE TABLE threshold_violations (
    violation_id VARCHAR(50) PRIMARY KEY,
    transaction_id VARCHAR(50),
    threshold_type VARCHAR(50),
    threshold_amount DECIMAL(12,2),
    actual_amount DECIMAL(12,2),
    approval_bypassed BOOLEAN,
    justification TEXT,
    violation_date DATE,
    resolution_status VARCHAR(20),
    INDEX idx_threshold_transaction (transaction_id)
);

-- Maverick spend identification
CREATE TABLE maverick_spend_analysis (
    maverick_id VARCHAR(50) PRIMARY KEY,
    transaction_id VARCHAR(50),
    reason_code VARCHAR(50), -- no_contract, emergency, ease_of_use
    policy_violation VARCHAR(50),
    impact_amount DECIMAL(12,2),
    alternative_available BOOLEAN,
    business_justification TEXT,
    identified_date DATE,
    INDEX idx_maverick_transaction (transaction_id)
);

-- Digital maturity assessment
CREATE TABLE digital_maturity_metrics (
    maturity_id VARCHAR(50) PRIMARY KEY,
    process_area VARCHAR(50), -- p2p, sourcing, contracts, analytics
    automation_rate DECIMAL(5,2),
    manual_touchpoints INTEGER,
    user_adoption_rate DECIMAL(5,2),
    efficiency_gain DECIMAL(5,2),
    assessment_date DATE,
    target_maturity_score DECIMAL(5,2),
    current_maturity_score DECIMAL(5,2),
    INDEX idx_maturity_area (process_area)
);

-- User training and competency
CREATE TABLE user_training_tracking (
    training_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50),
    training_type VARCHAR(50),
    competency_area VARCHAR(50),
    completion_date DATE,
    score DECIMAL(5,2),
    certification_status VARCHAR(20),
    expiry_date DATE,
    INDEX idx_training_user (user_id),
    INDEX idx_training_competency (competency_area)
);

-- Process automation metrics
CREATE TABLE process_automation_tracking (
    automation_id VARCHAR(50) PRIMARY KEY,
    process_name VARCHAR(100),
    automation_level DECIMAL(5,2),
    manual_steps_count INTEGER,
    automated_steps_count INTEGER,
    cycle_time_baseline INTEGER,
    cycle_time_current INTEGER,
    efficiency_improvement DECIMAL(5,2),
    last_assessment_date DATE,
    INDEX idx_automation_process (process_name)
);

-- Supplier due diligence compliance
CREATE TABLE supplier_due_diligence (
    diligence_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    requirement_type VARCHAR(50), -- insurance, certifications, financial
    requirement_description TEXT,
    status VARCHAR(20), -- current, expired, missing, pending
    effective_date DATE,
    expiry_date DATE,
    compliance_level VARCHAR(10),
    INDEX idx_diligence_supplier (supplier_id),
    INDEX idx_diligence_expiry (expiry_date)
);
```

### Module 6: ESG & Sustainability (8 tables)

```sql
-- Supplier diversity classification
CREATE TABLE supplier_diversity_metrics (
    diversity_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    diversity_type VARCHAR(50), -- women_owned, minority_owned, small_business
    certification_body VARCHAR(100),
    certification_number VARCHAR(50),
    verified_date DATE,
    expiry_date DATE,
    annual_revenue DECIMAL(15,2),
    employee_count INTEGER,
    INDEX idx_diversity_supplier (supplier_id),
    INDEX idx_diversity_type (diversity_type)
);

-- Environmental impact metrics
CREATE TABLE environmental_metrics (
    env_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    co2_emissions_annual DECIMAL(12,2), -- tons CO2e
    renewable_energy_pct DECIMAL(5,2),
    waste_reduction_pct DECIMAL(5,2),
    water_consumption DECIMAL(12,2),
    environmental_certifications TEXT, -- JSON array: ISO14001, etc.
    carbon_footprint_per_unit DECIMAL(8,4),
    measurement_year INTEGER,
    INDEX idx_env_supplier (supplier_id),
    INDEX idx_env_year (measurement_year)
);

-- Social compliance and labor practices
CREATE TABLE social_compliance_metrics (
    social_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    labor_audit_score DECIMAL(5,2),
    human_rights_compliance VARCHAR(20),
    fair_labor_certification BOOLEAN,
    community_impact_score DECIMAL(5,2),
    ethical_sourcing_compliance VARCHAR(20),
    worker_safety_score DECIMAL(5,2),
    last_audit_date DATE,
    next_audit_due DATE,
    INDEX idx_social_supplier (supplier_id)
);

-- ESG performance scorecards
CREATE TABLE esg_performance_scorecards (
    esg_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    period_year INTEGER,
    environmental_score DECIMAL(5,2),
    social_score DECIMAL(5,2),
    governance_score DECIMAL(5,2),
    overall_esg_score DECIMAL(5,2),
    esg_tier VARCHAR(10), -- platinum, gold, silver, bronze
    improvement_areas TEXT,
    INDEX idx_esg_supplier (supplier_id),
    INDEX idx_esg_period (period_year)
);

-- Sustainability initiatives tracking
CREATE TABLE sustainability_initiatives (
    sustainability_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    initiative_name VARCHAR(200),
    initiative_type VARCHAR(50), -- carbon_reduction, waste_reduction, etc.
    target_value DECIMAL(10,2),
    current_progress DECIMAL(10,2),
    unit_of_measure VARCHAR(20),
    start_date DATE,
    target_completion_date DATE,
    status VARCHAR(20),
    INDEX idx_sustain_supplier (supplier_id)
);

-- ESG audit results and findings
CREATE TABLE esg_audit_results (
    audit_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    audit_type VARCHAR(50), -- environmental, social, governance
    audit_score DECIMAL(5,2),
    critical_findings INTEGER,
    medium_findings INTEGER,
    low_findings INTEGER,
    audit_date DATE,
    auditor VARCHAR(100),
    corrective_action_plan TEXT,
    follow_up_date DATE,
    INDEX idx_audit_supplier (supplier_id),
    INDEX idx_audit_date (audit_date)
);

-- Carbon footprint and emissions tracking
CREATE TABLE carbon_footprint_tracking (
    carbon_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    scope1_emissions DECIMAL(12,2),
    scope2_emissions DECIMAL(12,2),
    scope3_emissions DECIMAL(12,2),
    total_emissions DECIMAL(12,2),
    emissions_per_revenue DECIMAL(8,4), -- CO2e per $ revenue
    baseline_year INTEGER,
    measurement_year INTEGER,
    reduction_target_pct DECIMAL(5,2),
    INDEX idx_carbon_supplier (supplier_id),
    INDEX idx_carbon_year (measurement_year)
);

-- Supplier ESG improvement plans
CREATE TABLE esg_improvement_plans (
    improvement_id VARCHAR(50) PRIMARY KEY,
    supplier_id VARCHAR(50) REFERENCES vendors(vendor_id),
    focus_area VARCHAR(50), -- environmental, social, governance
    current_score DECIMAL(5,2),
    target_score DECIMAL(5,2),
    improvement_actions TEXT,
    investment_required DECIMAL(10,2),
    timeline_months INTEGER,
    progress_status VARCHAR(20),
    INDEX idx_improvement_supplier (supplier_id)
);
```

## Implementation Guidelines

### Phase 1 (Months 1-6): Foundation Tables
**Priority**: Critical business operations
- Contract Lifecycle Management (9 tables)
- Supplier Performance Management (8 tables)  
- Core Risk Management (4 tables)
- Basic Financial Tracking (4 tables)

### Phase 2 (Months 7-12): Process Excellence
**Priority**: Operational optimization
- Complete Risk & Incident Management (3 remaining tables)
- Process Compliance & Automation (9 tables)
- Enhanced Financial Performance (4 remaining tables)

### Phase 3 (Months 13-18): Strategic Intelligence
**Priority**: Strategic capabilities
- ESG & Sustainability (8 tables)
- Advanced Analytics and Reporting
- Integration with external systems

## Data Migration Strategy

### Current Database Mapping
```sql
-- Example mapping from existing to new schema
INSERT INTO supplier_performance_metrics (supplier_id, metric_type, metric_value, measurement_period)
SELECT 
    vendor_id,
    'spend_volume',
    SUM(amount_usd),
    CONCAT(YEAR(date), '-Q', QUARTER(date))
FROM procurement_transactions 
GROUP BY vendor_id, YEAR(date), QUARTER(date);
```

### Quality Assurance
- **Data Validation**: Automated checks for referential integrity
- **Performance Testing**: Query optimization for large datasets
- **User Acceptance**: Stakeholder validation of report outputs

## Success Metrics

| Metric | Current | Phase 1 Target | Final Target |
|--------|---------|---------------|--------------|
| Automated Reports | 3/17 (18%) | 9/17 (53%) | 17/17 (100%) |
| Data Coverage | 35% | 75% | 95% |
| Report Generation Time | 8 hours | 2 hours | 5 minutes |
| Data Quality Score | 75% | 90% | 98% |

This comprehensive schema enhancement provides the foundation for transforming procurement reporting from manual, external data-dependent processes to fully automated, real-time intelligence systems.
