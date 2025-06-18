# Sample SQL Queries for C-Suite Reports

This directory contains practical SQL examples for generating the 17 C-Suite procurement reports. These queries demonstrate how to leverage both the current database and enhanced schema to create automated reporting capabilities.

## Report Generation Examples

### 1. Supplier Performance Report

#### Current Database (Limited Capability)
```sql
-- Basic Supplier Performance Analysis
-- Coverage: ~40% of full report requirements

WITH supplier_spend_summary AS (
    SELECT 
        v.vendor_id,
        v.vendor_name,
        v.vendor_tier,
        v.esg_score,
        v.risk_rating,
        v.country,
        COUNT(s.fact_id) as transaction_count,
        SUM(s.spend_amount) as total_spend,
        AVG(s.spend_amount) as avg_transaction_value,
        MIN(t.date) as first_transaction_date,
        MAX(t.date) as last_transaction_date
    FROM vendor_dimension v
    LEFT JOIN spend_fact s ON v.vendor_id = s.vendor_id
    LEFT JOIN time_dimension t ON s.time_id = t.time_id
    WHERE t.fiscal_year = 2018  -- Latest complete year
    GROUP BY v.vendor_id, v.vendor_name, v.vendor_tier, v.esg_score, v.risk_rating, v.country
),
performance_metrics AS (
    SELECT 
        vendor_id,
        -- Note: Most performance fields are NULL in current data
        AVG(CASE WHEN on_time_delivery IS NOT NULL THEN 
            CASE WHEN on_time_delivery = 1 THEN 100.0 ELSE 0.0 END 
            ELSE NULL END) as on_time_delivery_pct,
        AVG(quality_rating) as avg_quality_rating,
        AVG(supplier_performance_score) as avg_performance_score
    FROM spend_fact 
    WHERE time_id IN (SELECT time_id FROM time_dimension WHERE fiscal_year = 2018)
    GROUP BY vendor_id
)
SELECT 
    sss.vendor_name,
    sss.vendor_tier,
    sss.total_spend,
    sss.transaction_count,
    sss.esg_score,
    sss.risk_rating,
    sss.country,
    pm.on_time_delivery_pct,
    pm.avg_quality_rating,
    pm.avg_performance_score,
    CASE 
        WHEN sss.total_spend > 1000000 THEN 'Strategic'
        WHEN sss.total_spend > 100000 THEN 'Important' 
        ELSE 'Standard'
    END as spend_tier
FROM supplier_spend_summary sss
LEFT JOIN performance_metrics pm ON sss.vendor_id = pm.vendor_id
WHERE sss.total_spend > 0
ORDER BY sss.total_spend DESC;
```

#### Enhanced Database (Full Capability)
```sql
-- Comprehensive Supplier Performance Report
-- Coverage: ~95% of full report requirements

WITH performance_scorecard AS (
    SELECT 
        ss.vendor_id,
        ss.reporting_period,
        ss.overall_score,
        ss.delivery_score,
        ss.quality_score,
        ss.cost_score,
        ss.service_score,
        ss.innovation_score,
        ss.esg_score as current_esg_score,
        ss.performance_tier
    FROM supplier_scorecard ss
    WHERE ss.reporting_period = 'Q4-2024'
),
delivery_metrics AS (
    SELECT 
        dp.vendor_id,
        COUNT(*) as total_deliveries,
        SUM(CASE WHEN dp.on_time_flag = true THEN 1 ELSE 0 END) as on_time_deliveries,
        SUM(CASE WHEN dp.in_full_flag = true THEN 1 ELSE 0 END) as in_full_deliveries,
        SUM(CASE WHEN dp.otif_flag = true THEN 1 ELSE 0 END) as otif_deliveries,
        AVG(dp.delay_days) as avg_delay_days
    FROM delivery_performance dp
    WHERE dp.promised_date >= DATE('2024-10-01') 
      AND dp.promised_date <= DATE('2024-12-31')
    GROUP BY dp.vendor_id
),
quality_metrics AS (
    SELECT 
        qp.vendor_id,
        COUNT(*) as total_inspections,
        AVG(qp.defect_rate) as avg_defect_rate,
        AVG(qp.quality_rating) as avg_quality_rating,
        SUM(CASE WHEN qp.corrective_action_required = true THEN 1 ELSE 0 END) as corrective_actions
    FROM quality_performance qp
    WHERE qp.inspection_date >= DATE('2024-10-01')
      AND qp.inspection_date <= DATE('2024-12-31')
    GROUP BY qp.vendor_id
),
contract_performance AS (
    SELECT 
        cp.contract_id,
        c.vendor_id,
        cp.contract_utilization_pct,
        cp.savings_realized,
        cp.sla_compliance_pct,
        cp.performance_score as contract_score
    FROM contract_performance cp
    JOIN contracts c ON cp.contract_id = c.contract_id
    WHERE cp.reporting_period = 'Q4-2024'
),
risk_assessment AS (
    SELECT 
        sra.vendor_id,
        sra.overall_risk_rating,
        sra.financial_risk_score,
        sra.operational_risk_score,
        sra.esg_risk_score
    FROM supplier_risk_assessment sra
    WHERE sra.assessment_date = (
        SELECT MAX(assessment_date) 
        FROM supplier_risk_assessment sra2 
        WHERE sra2.vendor_id = sra.vendor_id
    )
)
SELECT 
    v.vendor_name,
    v.vendor_tier,
    v.country,
    
    -- Performance Scorecard
    ps.overall_score,
    ps.delivery_score,
    ps.quality_score,
    ps.cost_score,
    ps.service_score,
    ps.innovation_score,
    ps.performance_tier,
    
    -- Delivery Metrics
    COALESCE(dm.total_deliveries, 0) as total_deliveries,
    COALESCE(ROUND(dm.on_time_deliveries * 100.0 / NULLIF(dm.total_deliveries, 0), 2), 0) as otd_percentage,
    COALESCE(ROUND(dm.otif_deliveries * 100.0 / NULLIF(dm.total_deliveries, 0), 2), 0) as otif_percentage,
    COALESCE(dm.avg_delay_days, 0) as avg_delay_days,
    
    -- Quality Metrics
    COALESCE(qm.avg_defect_rate, 0) as defect_rate_pct,
    COALESCE(qm.avg_quality_rating, 0) as quality_rating,
    COALESCE(qm.corrective_actions, 0) as quality_issues,
    
    -- Contract Performance
    COALESCE(cp.contract_utilization_pct, 0) as contract_utilization,
    COALESCE(cp.savings_realized, 0) as savings_delivered,
    COALESCE(cp.sla_compliance_pct, 0) as sla_compliance,
    
    -- Risk Assessment
    COALESCE(ra.overall_risk_rating, 'Not Assessed') as risk_rating,
    COALESCE(ra.financial_risk_score, 0) as financial_risk,
    COALESCE(ra.operational_risk_score, 0) as operational_risk,
    
    -- Spend Analysis
    COALESCE(spend_summary.total_spend, 0) as ytd_spend,
    COALESCE(spend_summary.transaction_count, 0) as transaction_count

FROM vendor_dimension v
LEFT JOIN performance_scorecard ps ON v.vendor_id = ps.vendor_id
LEFT JOIN delivery_metrics dm ON v.vendor_id = dm.vendor_id
LEFT JOIN quality_metrics qm ON v.vendor_id = qm.vendor_id
LEFT JOIN contract_performance cp ON v.vendor_id = cp.vendor_id
LEFT JOIN risk_assessment ra ON v.vendor_id = ra.vendor_id
LEFT JOIN (
    SELECT 
        vendor_id,
        SUM(spend_amount) as total_spend,
        COUNT(*) as transaction_count
    FROM spend_fact sf
    JOIN time_dimension td ON sf.time_id = td.time_id
    WHERE td.fiscal_year = 2024
    GROUP BY vendor_id
) spend_summary ON v.vendor_id = spend_summary.vendor_id

WHERE v.vendor_status = 'Active'
  AND (ps.overall_score IS NOT NULL OR spend_summary.total_spend > 0)
ORDER BY ps.overall_score DESC, spend_summary.total_spend DESC;
```

### 2. Contract Expiry & Renewal Report

#### Enhanced Database Query
```sql
-- Contract Expiry & Renewal Report
-- Shows contracts expiring in next 12 months with renewal analysis

WITH contract_summary AS (
    SELECT 
        c.contract_id,
        c.vendor_id,
        c.contract_name,
        c.contract_type,
        c.contract_value,
        c.start_date,
        c.end_date,
        c.auto_renewal_flag,
        c.renewal_notice_days,
        c.contract_status,
        c.contract_owner,
        
        -- Calculate days until expiry
        (JULIANDAY(c.end_date) - JULIANDAY(DATE('now'))) as days_to_expiry,
        
        -- Determine renewal urgency
        CASE 
            WHEN (JULIANDAY(c.end_date) - JULIANDAY(DATE('now'))) <= 30 THEN 'Critical'
            WHEN (JULIANDAY(c.end_date) - JULIANDAY(DATE('now'))) <= 90 THEN 'High'
            WHEN (JULIANDAY(c.end_date) - JULIANDAY(DATE('now'))) <= 180 THEN 'Medium'
            ELSE 'Low'
        END as renewal_urgency,
        
        -- Check if notice period has passed
        CASE 
            WHEN (JULIANDAY(c.end_date) - JULIANDAY(DATE('now'))) <= c.renewal_notice_days THEN 'Action Required'
            ELSE 'Monitoring'
        END as notice_status
        
    FROM contracts c
    WHERE c.contract_status = 'Active'
      AND c.end_date >= DATE('now')
      AND c.end_date <= DATE('now', '+12 months')
),
renewal_tracking AS (
    SELECT 
        cr.contract_id,
        cr.renewal_type,
        cr.renewal_status,
        cr.stakeholder_approved,
        cr.renewal_rationale
    FROM contract_renewals cr
    WHERE cr.renewal_date >= DATE('now', '-6 months')
),
contract_performance_summary AS (
    SELECT 
        cp.contract_id,
        AVG(cp.contract_utilization_pct) as avg_utilization,
        AVG(cp.sla_compliance_pct) as avg_sla_compliance,
        AVG(cp.performance_score) as avg_performance_score,
        SUM(cp.savings_realized) as total_savings
    FROM contract_performance cp
    WHERE cp.reporting_period IN ('Q1-2024', 'Q2-2024', 'Q3-2024', 'Q4-2024')
    GROUP BY cp.contract_id
),
vendor_performance AS (
    SELECT 
        ss.vendor_id,
        ss.overall_score as vendor_score,
        ss.performance_tier
    FROM supplier_scorecard ss
    WHERE ss.reporting_period = 'Q4-2024'
),
spend_analysis AS (
    SELECT 
        sf.vendor_id,
        SUM(sf.spend_amount) as ytd_spend,
        COUNT(*) as transaction_count
    FROM spend_fact sf
    JOIN time_dimension td ON sf.time_id = td.time_id
    WHERE td.fiscal_year = 2024
    GROUP BY sf.vendor_id
)
SELECT 
    -- Contract Details
    cs.contract_id,
    cs.contract_name,
    v.vendor_name,
    cs.contract_type,
    cs.contract_value,
    cs.start_date,
    cs.end_date,
    cs.contract_owner,
    
    -- Renewal Analysis
    cs.days_to_expiry,
    cs.renewal_urgency,
    cs.notice_status,
    cs.auto_renewal_flag,
    cs.renewal_notice_days,
    
    -- Renewal Tracking
    COALESCE(rt.renewal_status, 'Not Started') as renewal_status,
    COALESCE(rt.renewal_type, 'TBD') as planned_renewal_approach,
    COALESCE(rt.stakeholder_approved, false) as stakeholder_approved,
    
    -- Performance Assessment
    COALESCE(cps.avg_utilization, 0) as contract_utilization_pct,
    COALESCE(cps.avg_sla_compliance, 0) as sla_compliance_pct,
    COALESCE(cps.avg_performance_score, 0) as contract_performance_score,
    COALESCE(cps.total_savings, 0) as savings_delivered,
    
    -- Vendor Assessment
    COALESCE(vp.vendor_score, 0) as vendor_performance_score,
    COALESCE(vp.performance_tier, 'Not Rated') as vendor_tier,
    v.risk_rating as vendor_risk_rating,
    
    -- Business Impact
    COALESCE(sa.ytd_spend, 0) as ytd_spend_volume,
    COALESCE(sa.transaction_count, 0) as ytd_transactions,
    
    -- Risk Assessment
    CASE 
        WHEN cs.contract_value > 1000000 AND cs.renewal_urgency IN ('Critical', 'High') THEN 'High Business Risk'
        WHEN cs.contract_value > 100000 AND cs.renewal_urgency = 'Critical' THEN 'Medium Business Risk'
        ELSE 'Low Business Risk'
    END as business_impact_risk,
    
    -- Recommended Actions
    CASE 
        WHEN cs.notice_status = 'Action Required' AND rt.renewal_status = 'Not Started' THEN 'Immediate Action Required'
        WHEN cs.auto_renewal_flag = true AND cs.days_to_expiry <= 30 THEN 'Review Auto-Renewal'
        WHEN cps.avg_performance_score < 3.0 THEN 'Performance Review Required'
        WHEN vp.vendor_score < 3.0 THEN 'Vendor Assessment Required'
        ELSE 'Normal Process'
    END as recommended_action

FROM contract_summary cs
JOIN vendor_dimension v ON cs.vendor_id = v.vendor_id
LEFT JOIN renewal_tracking rt ON cs.contract_id = rt.contract_id
LEFT JOIN contract_performance_summary cps ON cs.contract_id = cps.contract_id
LEFT JOIN vendor_performance vp ON cs.vendor_id = vp.vendor_id
LEFT JOIN spend_analysis sa ON cs.vendor_id = sa.vendor_id

ORDER BY 
    CASE cs.renewal_urgency 
        WHEN 'Critical' THEN 1 
        WHEN 'High' THEN 2 
        WHEN 'Medium' THEN 3 
        ELSE 4 
    END,
    cs.contract_value DESC;
```

### 3. Savings Realisation Report

#### Enhanced Database Query
```sql
-- Savings Realisation Report
-- Tracks forecasted vs actual savings with validation

WITH savings_summary AS (
    SELECT 
        si.initiative_id,
        si.initiative_name,
        si.category_id,
        si.initiative_type,
        si.baseline_amount,
        si.forecasted_savings,
        si.realized_savings,
        si.realization_rate,
        si.savings_type,
        si.initiative_status,
        si.start_date,
        si.target_completion_date,
        si.initiative_owner,
        
        -- Calculate variance
        (si.realized_savings - si.forecasted_savings) as savings_variance,
        
        -- Calculate realization percentage
        CASE 
            WHEN si.forecasted_savings > 0 THEN 
                ROUND((si.realized_savings / si.forecasted_savings) * 100, 2)
            ELSE 0 
        END as realization_percentage
    FROM savings_initiatives si
    WHERE si.start_date >= DATE('2024-01-01')
),
category_summary AS (
    SELECT 
        cd.parent_category,
        COUNT(ss.initiative_id) as initiative_count,
        SUM(ss.forecasted_savings) as total_forecasted,
        SUM(ss.realized_savings) as total_realized,
        AVG(ss.realization_percentage) as avg_realization_rate
    FROM savings_summary ss
    JOIN commodity_dimension cd ON ss.category_id = cd.commodity_id
    GROUP BY cd.parent_category
),
monthly_trend AS (
    SELECT 
        strftime('%Y-%m', ss.start_date) as month_year,
        SUM(ss.forecasted_savings) as monthly_forecast,
        SUM(ss.realized_savings) as monthly_realized,
        COUNT(*) as initiatives_count
    FROM savings_summary ss
    GROUP BY strftime('%Y-%m', ss.start_date)
),
roi_calculation AS (
    SELECT 
        pr.reporting_period,
        pr.procurement_costs,
        pr.total_savings_delivered,
        pr.roi_ratio
    FROM procurement_roi pr
    WHERE pr.reporting_period LIKE '2024%'
)
SELECT 
    -- Initiative Details
    ss.initiative_name,
    ss.initiative_type,
    ss.savings_type,
    ss.initiative_status,
    ss.initiative_owner,
    cd.parent_category as category,
    
    -- Financial Metrics
    ss.baseline_amount,
    ss.forecasted_savings,
    ss.realized_savings,
    ss.savings_variance,
    ss.realization_percentage,
    
    -- Timeline
    ss.start_date,
    ss.target_completion_date,
    
    -- Status Analysis
    CASE 
        WHEN ss.initiative_status = 'Realized' AND ss.realization_percentage >= 100 THEN 'Exceeded Target'
        WHEN ss.initiative_status = 'Realized' AND ss.realization_percentage >= 80 THEN 'Met Target'
        WHEN ss.initiative_status = 'Realized' AND ss.realization_percentage < 80 THEN 'Under Target'
        WHEN ss.initiative_status = 'Committed' THEN 'In Progress'
        WHEN ss.initiative_status = 'Pipeline' THEN 'Planned'
        ELSE 'At Risk'
    END as performance_status,
    
    -- Category Benchmarking
    cs.avg_realization_rate as category_avg_realization,
    
    -- Risk Indicators
    CASE 
        WHEN ss.target_completion_date < DATE('now') AND ss.initiative_status != 'Realized' THEN 'Overdue'
        WHEN ss.target_completion_date <= DATE('now', '+30 days') AND ss.initiative_status = 'Pipeline' THEN 'At Risk'
        ELSE 'On Track'
    END as timeline_risk,
    
    -- Value Classification
    CASE 
        WHEN ss.forecasted_savings >= 1000000 THEN 'High Value (>$1M)'
        WHEN ss.forecasted_savings >= 100000 THEN 'Medium Value ($100K-$1M)'
        ELSE 'Standard Value (<$100K)'
    END as value_tier

FROM savings_summary ss
JOIN commodity_dimension cd ON ss.category_id = cd.commodity_id
LEFT JOIN category_summary cs ON cd.parent_category = cs.parent_category

ORDER BY ss.forecasted_savings DESC, ss.realization_percentage DESC;

-- Summary Dashboard Query
SELECT 
    -- Overall Performance
    SUM(forecasted_savings) as total_forecasted_savings,
    SUM(realized_savings) as total_realized_savings,
    ROUND(AVG(realization_percentage), 2) as overall_realization_rate,
    COUNT(*) as total_initiatives,
    
    -- Status Breakdown
    SUM(CASE WHEN initiative_status = 'Realized' THEN 1 ELSE 0 END) as realized_count,
    SUM(CASE WHEN initiative_status = 'Committed' THEN 1 ELSE 0 END) as committed_count,
    SUM(CASE WHEN initiative_status = 'Pipeline' THEN 1 ELSE 0 END) as pipeline_count,
    
    -- Performance Tiers
    SUM(CASE WHEN realization_percentage >= 100 THEN realized_savings ELSE 0 END) as exceeded_savings,
    SUM(CASE WHEN realization_percentage BETWEEN 80 AND 99 THEN realized_savings ELSE 0 END) as met_savings,
    SUM(CASE WHEN realization_percentage < 80 THEN realized_savings ELSE 0 END) as under_savings

FROM savings_summary;
```

### 4. Risk Exposure Dashboard Query

```sql
-- Risk Exposure Dashboard
-- Comprehensive risk assessment across suppliers and categories

WITH supplier_risk_summary AS (
    SELECT 
        sra.vendor_id,
        sra.overall_risk_rating,
        sra.financial_risk_score,
        sra.operational_risk_score,
        sra.geopolitical_risk_score,
        sra.esg_risk_score,
        sra.cyber_risk_score,
        
        -- Calculate composite risk score
        (sra.financial_risk_score + sra.operational_risk_score + 
         sra.geopolitical_risk_score + sra.esg_risk_score + 
         sra.cyber_risk_score) / 5.0 as composite_risk_score
    FROM supplier_risk_assessment sra
    WHERE sra.assessment_date = (
        SELECT MAX(assessment_date) 
        FROM supplier_risk_assessment sra2 
        WHERE sra2.vendor_id = sra.vendor_id
    )
),
incident_summary AS (
    SELECT 
        ri.vendor_id,
        COUNT(*) as total_incidents,
        SUM(CASE WHEN ri.incident_severity = 'Critical' THEN 1 ELSE 0 END) as critical_incidents,
        SUM(CASE WHEN ri.incident_severity = 'High' THEN 1 ELSE 0 END) as high_incidents,
        SUM(CASE WHEN ri.status = 'Open' THEN 1 ELSE 0 END) as open_incidents,
        SUM(COALESCE(ri.financial_impact, 0)) as total_financial_impact
    FROM risk_incidents ri
    WHERE ri.incident_date >= DATE('2024-01-01')
    GROUP BY ri.vendor_id
),
spend_at_risk AS (
    SELECT 
        sf.vendor_id,
        SUM(sf.spend_amount) as ytd_spend
    FROM spend_fact sf
    JOIN time_dimension td ON sf.time_id = td.time_id
    WHERE td.fiscal_year = 2024
    GROUP BY sf.vendor_id
),
category_risk AS (
    SELECT 
        cd.parent_category,
        AVG(srs.composite_risk_score) as avg_category_risk,
        SUM(sar.ytd_spend) as category_spend_at_risk,
        COUNT(DISTINCT srs.vendor_id) as vendors_in_category
    FROM supplier_risk_summary srs
    JOIN vendor_dimension v ON srs.vendor_id = v.vendor_id
    JOIN spend_fact sf ON v.vendor_id = sf.vendor_id
    JOIN commodity_dimension cd ON sf.commodity_id = cd.commodity_id
    JOIN spend_at_risk sar ON v.vendor_id = sar.vendor_id
    GROUP BY cd.parent_category
)
SELECT 
    -- Supplier Information
    v.vendor_name,
    v.vendor_tier,
    v.country,
    cd.parent_category as primary_category,
    
    -- Risk Scores
    srs.overall_risk_rating,
    srs.composite_risk_score,
    srs.financial_risk_score,
    srs.operational_risk_score,
    srs.geopolitical_risk_score,
    srs.esg_risk_score,
    srs.cyber_risk_score,
    
    -- Incident History
    COALESCE(is_summary.total_incidents, 0) as incident_count_ytd,
    COALESCE(is_summary.critical_incidents, 0) as critical_incidents,
    COALESCE(is_summary.open_incidents, 0) as open_incidents,
    COALESCE(is_summary.total_financial_impact, 0) as incident_financial_impact,
    
    -- Financial Exposure
    COALESCE(sar.ytd_spend, 0) as spend_at_risk,
    
    -- Risk Indicators
    CASE 
        WHEN srs.overall_risk_rating = 'Critical' THEN 'Immediate Action Required'
        WHEN srs.overall_risk_rating = 'High' AND sar.ytd_spend > 500000 THEN 'High Priority Review'
        WHEN is_summary.open_incidents > 0 THEN 'Monitor Incidents'
        ELSE 'Standard Monitoring'
    END as risk_action_required,
    
    -- Category Benchmarking
    cr.avg_category_risk as category_avg_risk,
    
    -- Risk Trend (simplified)
    CASE 
        WHEN is_summary.total_incidents > 2 THEN 'Deteriorating'
        WHEN is_summary.total_incidents = 0 THEN 'Stable'
        ELSE 'Monitor'
    END as risk_trend

FROM supplier_risk_summary srs
JOIN vendor_dimension v ON srs.vendor_id = v.vendor_id
LEFT JOIN incident_summary is_summary ON srs.vendor_id = is_summary.vendor_id
LEFT JOIN spend_at_risk sar ON srs.vendor_id = sar.vendor_id
LEFT JOIN (
    SELECT vendor_id, MAX(parent_category) as parent_category
    FROM spend_fact sf
    JOIN commodity_dimension cd ON sf.commodity_id = cd.commodity_id
    GROUP BY vendor_id
) vendor_category ON srs.vendor_id = vendor_category.vendor_id
LEFT JOIN category_risk cr ON vendor_category.parent_category = cr.parent_category

WHERE srs.overall_risk_rating IN ('High', 'Critical') 
   OR sar.ytd_spend > 100000
   OR is_summary.open_incidents > 0

ORDER BY 
    CASE srs.overall_risk_rating 
        WHEN 'Critical' THEN 1 
        WHEN 'High' THEN 2 
        ELSE 3 
    END,
    sar.ytd_spend DESC;
```

## Usage Instructions

### 1. Current Database Queries
- Use these queries with the existing SQLite database
- Limited by current data availability (performance metrics mostly NULL)
- Suitable for initial analysis and proof of concept

### 2. Enhanced Database Queries  
- Require implementation of enhanced schema first
- Provide comprehensive reporting capabilities
- Support full automation of C-Suite reports

### 3. Migration Strategy
1. Start with current database queries to establish baseline
2. Implement Phase 1 schema enhancements
3. Gradually replace current queries with enhanced versions
4. Test and validate report accuracy throughout transition

### 4. Performance Optimization
- Add appropriate indexes as shown in schema design
- Consider partitioning for large datasets
- Monitor query performance and optimize as needed

## Next Steps

1. **Test Current Queries**: Run against existing database to validate baseline
2. **Implement Schema**: Begin with Phase 1 table creation
3. **Data Migration**: Populate new tables with historical and current data
4. **Report Automation**: Build automated report generation framework
5. **Dashboard Integration**: Connect to BI tools for executive dashboards

For complete implementation guidance, see the [Implementation Roadmap](../../docs/implementation/roadmap.md).
