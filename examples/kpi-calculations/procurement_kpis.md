# Key Performance Indicator (KPI) Calculations

This document provides SQL implementations for calculating essential procurement KPIs that support C-Suite reporting and decision-making.

## Core Procurement KPIs

### 1. Supplier Performance KPIs

#### On-Time Delivery (OTD) Percentage
```sql
-- Calculate OTD percentage by supplier for last 12 months
WITH delivery_metrics AS (
    SELECT 
        v.vendor_id,
        v.vendor_name,
        COUNT(*) as total_deliveries,
        SUM(CASE WHEN dp.on_time_flag = true THEN 1 ELSE 0 END) as on_time_deliveries,
        SUM(CASE WHEN dp.delay_days > 0 THEN dp.delay_days ELSE 0 END) as total_delay_days
    FROM vendor_dimension v
    JOIN delivery_performance dp ON v.vendor_id = dp.vendor_id
    WHERE dp.promised_date >= DATE('now', '-12 months')
    GROUP BY v.vendor_id, v.vendor_name
)
SELECT 
    vendor_name,
    total_deliveries,
    on_time_deliveries,
    ROUND((on_time_deliveries * 100.0 / total_deliveries), 2) as otd_percentage,
    ROUND((total_delay_days / NULLIF(total_deliveries, 0)), 1) as avg_delay_days,
    
    -- Performance Rating
    CASE 
        WHEN (on_time_deliveries * 100.0 / total_deliveries) >= 95 THEN 'Excellent'
        WHEN (on_time_deliveries * 100.0 / total_deliveries) >= 90 THEN 'Good'
        WHEN (on_time_deliveries * 100.0 / total_deliveries) >= 80 THEN 'Acceptable'
        ELSE 'Poor'
    END as otd_rating
FROM delivery_metrics
WHERE total_deliveries >= 5  -- Minimum deliveries for meaningful metric
ORDER BY otd_percentage DESC;
```

#### On-Time In-Full (OTIF) Performance
```sql
-- Calculate OTIF percentage with trend analysis
SELECT 
    v.vendor_name,
    strftime('%Y-%m', dp.promised_date) as delivery_month,
    COUNT(*) as total_orders,
    SUM(CASE WHEN dp.otif_flag = true THEN 1 ELSE 0 END) as otif_orders,
    ROUND((SUM(CASE WHEN dp.otif_flag = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2) as otif_percentage,
    
    -- Breakdown analysis
    ROUND((SUM(CASE WHEN dp.on_time_flag = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2) as on_time_pct,
    ROUND((SUM(CASE WHEN dp.in_full_flag = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2) as in_full_pct
    
FROM vendor_dimension v
JOIN delivery_performance dp ON v.vendor_id = dp.vendor_id
WHERE dp.promised_date >= DATE('now', '-6 months')
  AND v.vendor_tier IN ('Strategic', 'Preferred')
GROUP BY v.vendor_id, v.vendor_name, strftime('%Y-%m', dp.promised_date)
HAVING COUNT(*) >= 3  -- Minimum orders per month
ORDER BY v.vendor_name, delivery_month;
```

#### Supplier Quality Rating
```sql
-- Calculate quality performance with defect analysis
WITH quality_metrics AS (
    SELECT 
        v.vendor_id,
        v.vendor_name,
        v.vendor_tier,
        COUNT(qp.quality_id) as total_inspections,
        AVG(qp.quality_rating) as avg_quality_rating,
        AVG(qp.defect_rate) as avg_defect_rate,
        SUM(CASE WHEN qp.corrective_action_required = true THEN 1 ELSE 0 END) as corrective_actions,
        SUM(qp.total_quantity) as total_quantity_inspected,
        SUM(qp.defective_quantity) as total_defective_quantity
    FROM vendor_dimension v
    LEFT JOIN quality_performance qp ON v.vendor_id = qp.vendor_id
        AND qp.inspection_date >= DATE('now', '-12 months')
    WHERE v.vendor_status = 'Active'
    GROUP BY v.vendor_id, v.vendor_name, v.vendor_tier
),
spend_context AS (
    SELECT 
        sf.vendor_id,
        SUM(sf.spend_amount) as ytd_spend
    FROM spend_fact sf
    JOIN time_dimension td ON sf.time_id = td.time_id
    WHERE td.fiscal_year = 2024
    GROUP BY sf.vendor_id
)
SELECT 
    qm.vendor_name,
    qm.vendor_tier,
    sc.ytd_spend,
    qm.total_inspections,
    ROUND(qm.avg_quality_rating, 2) as avg_quality_rating,
    ROUND(qm.avg_defect_rate, 3) as avg_defect_rate_pct,
    qm.corrective_actions,
    
    -- Overall Quality Score (weighted)
    ROUND(
        (qm.avg_quality_rating * 0.6) + 
        ((5 - (qm.avg_defect_rate * 20)) * 0.3) + 
        ((5 - (qm.corrective_actions * 0.5)) * 0.1), 
        2
    ) as composite_quality_score,
    
    -- Quality Tier
    CASE 
        WHEN qm.avg_quality_rating >= 4.5 AND qm.avg_defect_rate <= 0.01 THEN 'World Class'
        WHEN qm.avg_quality_rating >= 4.0 AND qm.avg_defect_rate <= 0.03 THEN 'Excellent'
        WHEN qm.avg_quality_rating >= 3.5 AND qm.avg_defect_rate <= 0.05 THEN 'Good'
        WHEN qm.avg_quality_rating >= 3.0 THEN 'Acceptable'
        ELSE 'Improvement Required'
    END as quality_tier
    
FROM quality_metrics qm
LEFT JOIN spend_context sc ON qm.vendor_id = sc.vendor_id
WHERE qm.total_inspections > 0 OR sc.ytd_spend > 50000
ORDER BY composite_quality_score DESC;
```

### 2. Financial Performance KPIs

#### Savings Realization Rate
```sql
-- Calculate savings realization with variance analysis
WITH savings_performance AS (
    SELECT 
        si.initiative_type,
        cd.parent_category,
        si.initiative_owner,
        COUNT(*) as total_initiatives,
        SUM(si.forecasted_savings) as total_forecasted,
        SUM(si.realized_savings) as total_realized,
        SUM(si.realized_savings - si.forecasted_savings) as total_variance,
        
        -- Calculate realization rate
        CASE 
            WHEN SUM(si.forecasted_savings) > 0 THEN 
                ROUND((SUM(si.realized_savings) / SUM(si.forecasted_savings)) * 100, 2)
            ELSE 0 
        END as realization_rate_pct
        
    FROM savings_initiatives si
    LEFT JOIN commodity_dimension cd ON si.category_id = cd.commodity_id
    WHERE si.start_date >= DATE('2024-01-01')
      AND si.initiative_status IN ('Realized', 'Validated')
    GROUP BY si.initiative_type, cd.parent_category, si.initiative_owner
)
SELECT 
    initiative_type,
    parent_category,
    initiative_owner,
    total_initiatives,
    total_forecasted,
    total_realized,
    total_variance,
    realization_rate_pct,
    
    -- Performance Classification
    CASE 
        WHEN realization_rate_pct >= 100 THEN 'Exceeded Target'
        WHEN realization_rate_pct >= 90 THEN 'Met Target'
        WHEN realization_rate_pct >= 80 THEN 'Near Target'
        WHEN realization_rate_pct >= 70 THEN 'Below Target'
        ELSE 'Significantly Below'
    END as performance_classification,
    
    -- Value per Initiative
    ROUND(total_realized / NULLIF(total_initiatives, 0), 0) as avg_savings_per_initiative
    
FROM savings_performance
WHERE total_forecasted > 0
ORDER BY realization_rate_pct DESC, total_realized DESC;
```

#### Procurement ROI Calculation
```sql
-- Calculate comprehensive Procurement ROI
WITH procurement_costs AS (
    SELECT 
        '2024' as reporting_year,
        1200000 as total_procurement_headcount_cost,  -- Example: adjust for actual costs
        300000 as procurement_technology_cost,
        150000 as procurement_training_cost,
        200000 as external_consulting_cost
),
value_delivered AS (
    SELECT 
        SUM(si.realized_savings) as total_hard_savings,
        SUM(CASE WHEN si.savings_type = 'Cost Avoidance' THEN si.realized_savings ELSE 0 END) as cost_avoidance,
        COUNT(DISTINCT si.category_id) as categories_with_savings,
        
        -- Process efficiency value (estimated)
        500000 as process_efficiency_value,  -- Time savings, automation benefits
        
        -- Risk mitigation value (estimated)
        300000 as risk_mitigation_value     -- Avoided incidents, compliance
    FROM savings_initiatives si
    WHERE si.start_date >= DATE('2024-01-01')
      AND si.initiative_status IN ('Realized', 'Validated')
),
spend_managed AS (
    SELECT 
        SUM(sf.spend_amount) as total_managed_spend
    FROM spend_fact sf
    JOIN time_dimension td ON sf.time_id = td.time_id
    WHERE td.fiscal_year = 2024
)
SELECT 
    pc.reporting_year,
    
    -- Cost Components
    pc.total_procurement_headcount_cost,
    pc.procurement_technology_cost,
    pc.procurement_training_cost,
    pc.external_consulting_cost,
    (pc.total_procurement_headcount_cost + pc.procurement_technology_cost + 
     pc.procurement_training_cost + pc.external_consulting_cost) as total_procurement_cost,
    
    -- Value Components
    vd.total_hard_savings,
    vd.cost_avoidance,
    vd.process_efficiency_value,
    vd.risk_mitigation_value,
    (vd.total_hard_savings + vd.cost_avoidance + vd.process_efficiency_value + 
     vd.risk_mitigation_value) as total_value_delivered,
    
    -- ROI Calculations
    ROUND(
        ((vd.total_hard_savings + vd.cost_avoidance + vd.process_efficiency_value + vd.risk_mitigation_value) - 
         (pc.total_procurement_headcount_cost + pc.procurement_technology_cost + pc.procurement_training_cost + pc.external_consulting_cost)) /
        NULLIF((pc.total_procurement_headcount_cost + pc.procurement_technology_cost + pc.procurement_training_cost + pc.external_consulting_cost), 0) * 100, 
        2
    ) as procurement_roi_percentage,
    
    -- Benchmarking Metrics
    sm.total_managed_spend,
    ROUND((pc.total_procurement_headcount_cost + pc.procurement_technology_cost + 
           pc.procurement_training_cost + pc.external_consulting_cost) / 
          NULLIF(sm.total_managed_spend, 0) * 100, 3) as procurement_cost_as_pct_of_spend,
    
    ROUND(vd.total_hard_savings / NULLIF(sm.total_managed_spend, 0) * 100, 2) as savings_as_pct_of_spend
    
FROM procurement_costs pc
CROSS JOIN value_delivered vd
CROSS JOIN spend_managed sm;
```

### 3. Contract Management KPIs

#### Contract Expiry Risk Analysis
```sql
-- Identify contract expiry risks with business impact
WITH contract_risk_analysis AS (
    SELECT 
        c.contract_id,
        c.contract_name,
        v.vendor_name,
        v.vendor_tier,
        c.contract_value,
        c.end_date,
        c.auto_renewal_flag,
        c.renewal_notice_days,
        
        -- Calculate risk factors
        (JULIANDAY(c.end_date) - JULIANDAY(DATE('now'))) as days_to_expiry,
        
        -- Get recent spend to assess business impact
        COALESCE(recent_spend.spend_amount, 0) as recent_annual_spend,
        
        -- Contract performance context
        COALESCE(cp.avg_performance_score, 3.0) as avg_contract_performance,
        COALESCE(cp.avg_sla_compliance, 85.0) as avg_sla_compliance
        
    FROM contracts c
    JOIN vendor_dimension v ON c.vendor_id = v.vendor_id
    LEFT JOIN (
        SELECT 
            sf.vendor_id,
            SUM(sf.spend_amount) as spend_amount
        FROM spend_fact sf
        JOIN time_dimension td ON sf.time_id = td.time_id
        WHERE td.date >= DATE('now', '-12 months')
        GROUP BY sf.vendor_id
    ) recent_spend ON v.vendor_id = recent_spend.vendor_id
    LEFT JOIN (
        SELECT 
            contract_id,
            AVG(performance_score) as avg_performance_score,
            AVG(sla_compliance_pct) as avg_sla_compliance
        FROM contract_performance
        WHERE reporting_period LIKE '2024%'
        GROUP BY contract_id
    ) cp ON c.contract_id = cp.contract_id
    
    WHERE c.contract_status = 'Active'
      AND c.end_date >= DATE('now')
      AND c.end_date <= DATE('now', '+24 months')
)
SELECT 
    contract_name,
    vendor_name,
    vendor_tier,
    contract_value,
    recent_annual_spend,
    end_date,
    days_to_expiry,
    auto_renewal_flag,
    renewal_notice_days,
    avg_contract_performance,
    avg_sla_compliance,
    
    -- Risk Classification
    CASE 
        WHEN days_to_expiry <= 30 THEN 'Critical - Immediate Action'
        WHEN days_to_expiry <= 90 THEN 'High - Action Required'
        WHEN days_to_expiry <= 180 THEN 'Medium - Plan Renewal'
        ELSE 'Low - Monitor'
    END as expiry_risk_level,
    
    -- Business Impact Assessment
    CASE 
        WHEN recent_annual_spend > 1000000 OR contract_value > 1000000 THEN 'High Business Impact'
        WHEN recent_annual_spend > 100000 OR contract_value > 100000 THEN 'Medium Business Impact'
        ELSE 'Low Business Impact'
    END as business_impact,
    
    -- Renewal Recommendation
    CASE 
        WHEN avg_contract_performance >= 4.0 AND avg_sla_compliance >= 95 THEN 'Recommend Renewal'
        WHEN avg_contract_performance >= 3.5 AND avg_sla_compliance >= 85 THEN 'Conditional Renewal'
        WHEN avg_contract_performance >= 3.0 THEN 'Renegotiate Terms'
        ELSE 'Consider Alternative Suppliers'
    END as renewal_recommendation,
    
    -- Auto-renewal Alert
    CASE 
        WHEN auto_renewal_flag = true AND days_to_expiry <= renewal_notice_days THEN 'Auto-Renewal Alert'
        ELSE 'Manual Process'
    END as renewal_process_alert
    
FROM contract_risk_analysis
ORDER BY 
    CASE 
        WHEN days_to_expiry <= 30 THEN 1
        WHEN days_to_expiry <= 90 THEN 2
        WHEN days_to_expiry <= 180 THEN 3
        ELSE 4
    END,
    recent_annual_spend DESC;
```

### 4. Risk Management KPIs

#### Supplier Risk Score Calculation
```sql
-- Calculate comprehensive supplier risk scores
WITH risk_factors AS (
    SELECT 
        v.vendor_id,
        v.vendor_name,
        v.vendor_tier,
        v.risk_rating as current_risk_rating,
        
        -- Financial risk indicators
        CASE v.risk_rating
            WHEN 'Low' THEN 1
            WHEN 'Medium' THEN 3
            WHEN 'High' THEN 4
            WHEN 'Critical' THEN 5
            ELSE 3
        END as financial_risk_score,
        
        -- Performance risk (from quality and delivery)
        COALESCE(perf.performance_risk_score, 3) as performance_risk_score,
        
        -- Incident history risk
        COALESCE(incidents.incident_risk_score, 1) as incident_risk_score,
        
        -- Concentration risk (single sourcing)
        CASE 
            WHEN spend.spend_share > 0.5 THEN 5  -- >50% of category spend
            WHEN spend.spend_share > 0.3 THEN 4  -- >30% of category spend
            WHEN spend.spend_share > 0.2 THEN 3  -- >20% of category spend
            ELSE 2
        END as concentration_risk_score,
        
        -- Geographic risk
        CASE 
            WHEN v.country IN ('United States', 'Canada', 'Germany', 'United Kingdom', 'Australia') THEN 1
            WHEN v.country IN ('China', 'India', 'Mexico', 'Brazil') THEN 3
            ELSE 2
        END as geographic_risk_score
        
    FROM vendor_dimension v
    
    -- Performance-based risk
    LEFT JOIN (
        SELECT 
            vendor_id,
            CASE 
                WHEN AVG(overall_score) >= 4.0 THEN 1
                WHEN AVG(overall_score) >= 3.5 THEN 2
                WHEN AVG(overall_score) >= 3.0 THEN 3
                WHEN AVG(overall_score) >= 2.5 THEN 4
                ELSE 5
            END as performance_risk_score
        FROM supplier_scorecard
        WHERE reporting_period LIKE '2024%'
        GROUP BY vendor_id
    ) perf ON v.vendor_id = perf.vendor_id
    
    -- Incident-based risk
    LEFT JOIN (
        SELECT 
            vendor_id,
            CASE 
                WHEN COUNT(*) = 0 THEN 1
                WHEN COUNT(*) <= 2 THEN 2
                WHEN COUNT(*) <= 5 THEN 3
                WHEN COUNT(*) <= 10 THEN 4
                ELSE 5
            END as incident_risk_score
        FROM risk_incidents
        WHERE incident_date >= DATE('now', '-12 months')
        GROUP BY vendor_id
    ) incidents ON v.vendor_id = incidents.vendor_id
    
    -- Spend concentration risk
    LEFT JOIN (
        SELECT 
            sf.vendor_id,
            SUM(sf.spend_amount) as vendor_spend,
            category_totals.category_spend,
            SUM(sf.spend_amount) / category_totals.category_spend as spend_share
        FROM spend_fact sf
        JOIN time_dimension td ON sf.time_id = td.time_id
        JOIN commodity_dimension cd ON sf.commodity_id = cd.commodity_id
        JOIN (
            SELECT 
                cd2.parent_category,
                SUM(sf2.spend_amount) as category_spend
            FROM spend_fact sf2
            JOIN time_dimension td2 ON sf2.time_id = td2.time_id
            JOIN commodity_dimension cd2 ON sf2.commodity_id = cd2.commodity_id
            WHERE td2.fiscal_year = 2024
            GROUP BY cd2.parent_category
        ) category_totals ON cd.parent_category = category_totals.parent_category
        WHERE td.fiscal_year = 2024
        GROUP BY sf.vendor_id, category_totals.category_spend
    ) spend ON v.vendor_id = spend.vendor_id
)
SELECT 
    vendor_name,
    vendor_tier,
    current_risk_rating,
    
    -- Individual risk scores
    financial_risk_score,
    performance_risk_score,
    incident_risk_score,
    concentration_risk_score,
    geographic_risk_score,
    
    -- Composite risk score (weighted)
    ROUND(
        (financial_risk_score * 0.25) +
        (performance_risk_score * 0.25) +
        (incident_risk_score * 0.20) +
        (concentration_risk_score * 0.20) +
        (geographic_risk_score * 0.10),
        2
    ) as composite_risk_score,
    
    -- Risk tier based on composite score
    CASE 
        WHEN ROUND(
            (financial_risk_score * 0.25) +
            (performance_risk_score * 0.25) +
            (incident_risk_score * 0.20) +
            (concentration_risk_score * 0.20) +
            (geographic_risk_score * 0.10),
            2
        ) >= 4.5 THEN 'Critical Risk'
        WHEN ROUND(
            (financial_risk_score * 0.25) +
            (performance_risk_score * 0.25) +
            (incident_risk_score * 0.20) +
            (concentration_risk_score * 0.20) +
            (geographic_risk_score * 0.10),
            2
        ) >= 3.5 THEN 'High Risk'
        WHEN ROUND(
            (financial_risk_score * 0.25) +
            (performance_risk_score * 0.25) +
            (incident_risk_score * 0.20) +
            (concentration_risk_score * 0.20) +
            (geographic_risk_score * 0.10),
            2
        ) >= 2.5 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as calculated_risk_tier,
    
    -- Risk change indicator
    CASE 
        WHEN current_risk_rating = 'Low' AND 
             ROUND(
                (financial_risk_score * 0.25) +
                (performance_risk_score * 0.25) +
                (incident_risk_score * 0.20) +
                (concentration_risk_score * 0.20) +
                (geographic_risk_score * 0.10),
                2
             ) >= 3.5 THEN 'Risk Elevated'
        WHEN current_risk_rating = 'High' AND 
             ROUND(
                (financial_risk_score * 0.25) +
                (performance_risk_score * 0.25) +
                (incident_risk_score * 0.20) +
                (concentration_risk_score * 0.20) +
                (geographic_risk_score * 0.10),
                2
             ) <= 2.5 THEN 'Risk Improved'
        ELSE 'Stable'
    END as risk_trend
    
FROM risk_factors
WHERE vendor_tier IN ('Strategic', 'Preferred', 'Approved')
ORDER BY composite_risk_score DESC;
```

## KPI Dashboard Summary

### Executive Summary Query
```sql
-- Executive KPI Dashboard - Key Metrics Summary
WITH kpi_summary AS (
    -- Supplier Performance
    SELECT 
        'Supplier Performance' as kpi_category,
        'Average Supplier Score' as kpi_name,
        ROUND(AVG(overall_score), 2) as kpi_value,
        '5.0' as target_value,
        'Score' as unit
    FROM supplier_scorecard 
    WHERE reporting_period = 'Q4-2024'
    
    UNION ALL
    
    -- On-Time Delivery
    SELECT 
        'Supplier Performance' as kpi_category,
        'On-Time Delivery %' as kpi_name,
        ROUND(AVG(CASE WHEN on_time_flag = true THEN 100.0 ELSE 0.0 END), 1) as kpi_value,
        '95.0' as target_value,
        '%' as unit
    FROM delivery_performance 
    WHERE promised_date >= DATE('now', '-3 months')
    
    UNION ALL
    
    -- Savings Realization
    SELECT 
        'Financial Performance' as kpi_category,
        'Savings Realization Rate %' as kpi_name,
        ROUND((SUM(realized_savings) / NULLIF(SUM(forecasted_savings), 0)) * 100, 1) as kpi_value,
        '90.0' as target_value,
        '%' as unit
    FROM savings_initiatives 
    WHERE initiative_status IN ('Realized', 'Validated')
      AND start_date >= DATE('2024-01-01')
    
    UNION ALL
    
    -- Contract Coverage
    SELECT 
        'Contract Management' as kpi_category,
        'Contract Coverage %' as kpi_name,
        ROUND((contracted_spend.total / total_spend.total) * 100, 1) as kpi_value,
        '85.0' as target_value,
        '%' as unit
    FROM (
        SELECT SUM(sf.spend_amount) as total
        FROM spend_fact sf
        JOIN time_dimension td ON sf.time_id = td.time_id
        JOIN contracts c ON sf.vendor_id = c.vendor_id
        WHERE td.fiscal_year = 2024 AND c.contract_status = 'Active'
    ) contracted_spend
    CROSS JOIN (
        SELECT SUM(sf.spend_amount) as total
        FROM spend_fact sf
        JOIN time_dimension td ON sf.time_id = td.time_id
        WHERE td.fiscal_year = 2024
    ) total_spend
)
SELECT 
    kpi_category,
    kpi_name,
    kpi_value,
    CAST(target_value AS REAL) as target_value,
    unit,
    
    -- Performance vs Target
    ROUND((kpi_value / CAST(target_value AS REAL)) * 100, 1) as performance_vs_target_pct,
    
    -- Performance Rating
    CASE 
        WHEN (kpi_value / CAST(target_value AS REAL)) >= 1.0 THEN 'Exceeds Target'
        WHEN (kpi_value / CAST(target_value AS REAL)) >= 0.9 THEN 'Meets Target'
        WHEN (kpi_value / CAST(target_value AS REAL)) >= 0.8 THEN 'Near Target'
        ELSE 'Below Target'
    END as performance_rating
    
FROM kpi_summary
ORDER BY kpi_category, kpi_name;
```

## Usage Guidelines

### 1. Implementation Notes
- Adjust time periods and thresholds based on your organization's requirements
- Customize scoring weights to reflect your procurement priorities
- Validate calculations against known baseline data before production use

### 2. Performance Considerations
- Add appropriate indexes for date ranges and vendor lookups
- Consider creating materialized views for complex calculations
- Schedule regular KPI calculations to avoid real-time performance impact

### 3. Data Quality Requirements
- Ensure consistent data entry for accurate calculations
- Implement data validation rules for critical KPI inputs
- Monitor data completeness for meaningful KPI results

These KPI calculations provide the foundation for automated C-Suite reporting and procurement performance management.
