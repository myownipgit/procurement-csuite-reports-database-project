# Report Generation SQL Examples

## Executive Summary

This document provides practical SQL examples for generating all 17 C-Suite procurement reports using the enhanced database schema. Each example demonstrates how the new tables enable automated report generation with real-time data.

## High Priority Reports (Phase 1)

### 1. Supplier Performance Report

```sql
-- Executive Summary Section
SELECT 
    COUNT(DISTINCT s.supplier_id) as total_suppliers,
    AVG(sc.overall_score) as avg_performance_score,
    COUNT(CASE WHEN sr.risk_score >= 8 THEN 1 END) as high_risk_suppliers,
    SUM(CASE WHEN si.severity IN ('high', 'critical') THEN 1 ELSE 0 END) as critical_incidents
FROM vendors s
LEFT JOIN supplier_scorecards sc ON s.vendor_id = sc.supplier_id 
    AND sc.period_year = YEAR(CURRENT_DATE) 
    AND sc.period_quarter = QUARTER(CURRENT_DATE)
LEFT JOIN supplier_risk_assessment sr ON s.vendor_id = sr.supplier_id
LEFT JOIN supplier_incidents si ON s.vendor_id = si.supplier_id 
    AND si.incident_date >= DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY);

-- Supplier Performance Scorecard
SELECT 
    v.vendor_name,
    v.tier_classification,
    sc.overall_score,
    sc.delivery_score,
    sc.quality_score,
    sc.cost_score,
    sc.innovation_score,
    sdp.otif_percentage,
    sqm.defect_rate,
    COUNT(si.incident_id) as incident_count,
    CASE 
        WHEN sc.overall_score >= 90 THEN 'Excellent'
        WHEN sc.overall_score >= 80 THEN 'Good'
        WHEN sc.overall_score >= 70 THEN 'Satisfactory'
        ELSE 'Needs Improvement'
    END as performance_rating
FROM vendors v
LEFT JOIN supplier_scorecards sc ON v.vendor_id = sc.supplier_id 
    AND sc.period_year = YEAR(CURRENT_DATE)
LEFT JOIN supplier_delivery_performance sdp ON v.vendor_id = sdp.supplier_id
LEFT JOIN supplier_quality_metrics sqm ON v.vendor_id = sqm.supplier_id
LEFT JOIN supplier_incidents si ON v.vendor_id = si.supplier_id 
    AND si.incident_date >= DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY)
WHERE v.status = 'Active'
GROUP BY v.vendor_id, v.vendor_name, v.tier_classification, sc.overall_score, 
         sc.delivery_score, sc.quality_score, sc.cost_score, sc.innovation_score,
         sdp.otif_percentage, sqm.defect_rate
ORDER BY sc.overall_score DESC;

-- Top Performance Issues by Category
SELECT 
    pt.commodity_name,
    COUNT(si.incident_id) as incident_count,
    AVG(si.resolution_time_hours) as avg_resolution_hours,
    SUM(CASE WHEN si.severity = 'critical' THEN 1 ELSE 0 END) as critical_incidents,
    AVG(sc.overall_score) as avg_category_performance
FROM procurement_transactions pt
JOIN supplier_incidents si ON pt.vendor_id = si.supplier_id
JOIN supplier_scorecards sc ON pt.vendor_id = sc.supplier_id
WHERE si.incident_date >= DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY)
GROUP BY pt.commodity_name
ORDER BY incident_count DESC
LIMIT 10;
```

### 2. Savings Realisation Report

```sql
-- Savings Realization Executive Summary
SELECT 
    SUM(sr.forecasted_savings) as total_forecasted,
    SUM(sr.realized_savings) as total_realized,
    (SUM(sr.realized_savings) / SUM(sr.forecasted_savings)) * 100 as realization_rate,
    COUNT(DISTINCT si.initiative_id) as active_initiatives,
    SUM(CASE WHEN fv.finance_signoff = TRUE THEN sr.realized_savings ELSE 0 END) as validated_savings
FROM savings_realization sr
JOIN savings_initiatives si ON sr.initiative_id = si.initiative_id
LEFT JOIN financial_validation fv ON si.initiative_id = fv.initiative_id
WHERE sr.period_year = YEAR(CURRENT_DATE);

-- Detailed Initiative Performance
SELECT 
    si.initiative_name,
    si.category_id,
    si.owner,
    si.initiative_type,
    SUM(sr.forecasted_savings) as forecasted_savings,
    SUM(sr.realized_savings) as realized_savings,
    SUM(sr.variance) as total_variance,
    (SUM(sr.realized_savings) / SUM(sr.forecasted_savings)) * 100 as realization_rate,
    fv.finance_signoff,
    ss.duration_months,
    ss.repeatability,
    CASE 
        WHEN (SUM(sr.realized_savings) / SUM(sr.forecasted_savings)) >= 1.0 THEN 'Exceeded'
        WHEN (SUM(sr.realized_savings) / SUM(sr.forecasted_savings)) >= 0.9 THEN 'Met'
        WHEN (SUM(sr.realized_savings) / SUM(sr.forecasted_savings)) >= 0.8 THEN 'Nearly Met'
        ELSE 'Underperformed'
    END as performance_status
FROM savings_initiatives si
LEFT JOIN savings_realization sr ON si.initiative_id = sr.initiative_id
LEFT JOIN financial_validation fv ON si.initiative_id = fv.initiative_id
LEFT JOIN savings_sustainability ss ON si.initiative_id = ss.initiative_id
WHERE sr.period_year = YEAR(CURRENT_DATE)
GROUP BY si.initiative_id, si.initiative_name, si.category_id, si.owner, 
         si.initiative_type, fv.finance_signoff, ss.duration_months, ss.repeatability
ORDER BY realized_savings DESC;

-- ROI Analysis
SELECT 
    pri.period_year,
    pri.period_quarter,
    pri.procurement_cost,
    pri.value_delivered,
    pri.hard_savings,
    pri.cost_avoidance,
    pri.roi_ratio,
    (pri.value_delivered - pri.procurement_cost) as net_value,
    LAG(pri.roi_ratio) OVER (ORDER BY pri.period_year, pri.period_quarter) as previous_roi
FROM procurement_roi_metrics pri
WHERE pri.period_year >= YEAR(CURRENT_DATE) - 2
ORDER BY pri.period_year DESC, pri.period_quarter DESC;
```

### 3. Contract Expiry & Renewal Report

```sql
-- Contracts Expiring in Next 12 Months
SELECT 
    cec.expiry_date,
    cm.contract_name,
    v.vendor_name,
    cm.value_amount,
    cm.currency_code,
    cec.auto_renewal_flag,
    cec.notice_period_days,
    cec.renewal_deadline,
    cec.business_criticality,
    rp.renewal_strategy,
    rp.current_status,
    rp.assigned_owner,
    cp.kpi_score as contract_performance,
    DATEDIFF(cec.expiry_date, CURRENT_DATE) as days_to_expiry,
    CASE 
        WHEN DATEDIFF(cec.expiry_date, CURRENT_DATE) <= 30 THEN 'Urgent'
        WHEN DATEDIFF(cec.expiry_date, CURRENT_DATE) <= 90 THEN 'High Priority'
        WHEN DATEDIFF(cec.expiry_date, CURRENT_DATE) <= 180 THEN 'Medium Priority'
        ELSE 'Low Priority'
    END as renewal_urgency
FROM contract_expiry_calendar cec
JOIN contract_master cm ON cec.contract_id = cm.contract_id
JOIN vendors v ON cec.supplier_id = v.vendor_id
LEFT JOIN renewal_planning rp ON cm.contract_id = rp.contract_id
LEFT JOIN contract_performance cp ON cm.contract_id = cp.contract_id 
    AND cp.measurement_period = CONCAT(YEAR(CURRENT_DATE), '-Q', QUARTER(CURRENT_DATE))
WHERE cec.expiry_date BETWEEN CURRENT_DATE AND DATE_ADD(CURRENT_DATE, INTERVAL 12 MONTH)
ORDER BY cec.expiry_date ASC;

-- Auto-Renewal Risk Analysis
SELECT 
    COUNT(*) as contracts_at_risk,
    SUM(cm.value_amount) as total_value_at_risk,
    AVG(DATEDIFF(cec.renewal_deadline, CURRENT_DATE)) as avg_days_to_deadline,
    COUNT(CASE WHEN rp.renewal_strategy IS NULL THEN 1 END) as missing_renewal_plans
FROM contract_expiry_calendar cec
JOIN contract_master cm ON cec.contract_id = cm.contract_id
LEFT JOIN renewal_planning rp ON cm.contract_id = rp.contract_id
WHERE cec.auto_renewal_flag = TRUE 
AND cec.renewal_deadline <= DATE_ADD(CURRENT_DATE, INTERVAL 90 DAY);

-- Contract Performance Impact on Renewals
SELECT 
    cec.business_criticality,
    COUNT(*) as contract_count,
    AVG(cp.kpi_score) as avg_performance,
    AVG(cm.value_amount) as avg_contract_value,
    COUNT(CASE WHEN rp.renewal_strategy = 'retender' THEN 1 END) as retender_count,
    COUNT(CASE WHEN rp.renewal_strategy = 'renegotiate' THEN 1 END) as renegotiate_count
FROM contract_expiry_calendar cec
JOIN contract_master cm ON cec.contract_id = cm.contract_id
LEFT JOIN contract_performance cp ON cm.contract_id = cp.contract_id
LEFT JOIN renewal_planning rp ON cm.contract_id = rp.contract_id
WHERE cec.expiry_date BETWEEN CURRENT_DATE AND DATE_ADD(CURRENT_DATE, INTERVAL 12 MONTH)
GROUP BY cec.business_criticality
ORDER BY avg_contract_value DESC;
```

### 4. Risk Exposure Dashboard

```sql
-- Risk Overview Dashboard
SELECT 
    'Supplier Risk' as risk_category,
    COUNT(CASE WHEN sra.risk_score >= 8 THEN 1 END) as high_risk_count,
    COUNT(CASE WHEN sra.risk_score BETWEEN 5 AND 7 THEN 1 END) as medium_risk_count,
    COUNT(CASE WHEN sra.risk_score < 5 THEN 1 END) as low_risk_count,
    SUM(pt.amount_usd) as total_spend_at_risk
FROM supplier_risk_assessment sra
JOIN procurement_transactions pt ON sra.supplier_id = pt.vendor_id
WHERE pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
UNION ALL
SELECT 
    'Geographic Risk' as risk_category,
    COUNT(CASE WHEN gr.overall_risk_level = 'high' THEN 1 END) as high_risk_count,
    COUNT(CASE WHEN gr.overall_risk_level = 'medium' THEN 1 END) as medium_risk_count,
    COUNT(CASE WHEN gr.overall_risk_level = 'low' THEN 1 END) as low_risk_count,
    SUM(pt.amount_usd) as total_spend_at_risk
FROM geographic_risk gr
JOIN vendors v ON gr.country_code = v.country
JOIN procurement_transactions pt ON v.vendor_id = pt.vendor_id
WHERE pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);

-- Top Risk Suppliers
SELECT 
    v.vendor_name,
    v.tier_classification,
    sra.risk_score,
    sra.risk_category,
    sra.risk_type,
    SUM(pt.amount_usd) as annual_spend,
    COUNT(si.incident_id) as incident_count,
    rmp.mitigation_plan,
    rmp.current_status as mitigation_status
FROM supplier_risk_assessment sra
JOIN vendors v ON sra.supplier_id = v.vendor_id
JOIN procurement_transactions pt ON v.vendor_id = pt.vendor_id 
    AND pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
LEFT JOIN supplier_incidents si ON v.vendor_id = si.supplier_id 
    AND si.incident_date >= DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY)
LEFT JOIN risk_mitigation_plans rmp ON sra.risk_id = rmp.risk_id
WHERE sra.risk_score >= 7
GROUP BY v.vendor_id, v.vendor_name, v.tier_classification, sra.risk_score, 
         sra.risk_category, sra.risk_type, rmp.mitigation_plan, rmp.current_status
ORDER BY sra.risk_score DESC, annual_spend DESC;

-- Risk Mitigation Progress
SELECT 
    rmp.assigned_owner,
    COUNT(*) as total_mitigations,
    COUNT(CASE WHEN rmp.current_status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN rmp.current_status = 'in_progress' THEN 1 END) as in_progress,
    COUNT(CASE WHEN rmp.current_status = 'overdue' THEN 1 END) as overdue,
    AVG(rmp.effectiveness_score) as avg_effectiveness,
    SUM(rmp.cost_of_mitigation) as total_mitigation_cost
FROM risk_mitigation_plans rmp
GROUP BY rmp.assigned_owner
ORDER BY total_mitigations DESC;
```

## Medium Priority Reports (Phase 2)

### 5. Maverick Spend Analysis

```sql
-- Maverick Spend Overview
SELECT 
    COUNT(*) as total_maverick_transactions,
    SUM(msa.impact_amount) as total_maverick_spend,
    (SUM(msa.impact_amount) / SUM(pt.amount_usd)) * 100 as maverick_spend_percentage,
    COUNT(DISTINCT msa.reason_code) as unique_violation_types,
    AVG(msa.impact_amount) as avg_maverick_transaction_size
FROM maverick_spend_analysis msa
JOIN procurement_transactions pt ON msa.transaction_id = pt.transaction_id
WHERE pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);

-- Maverick Spend by Category and Reason
SELECT 
    pt.commodity_name,
    msa.reason_code,
    COUNT(*) as transaction_count,
    SUM(msa.impact_amount) as total_impact,
    AVG(msa.impact_amount) as avg_impact,
    COUNT(CASE WHEN msa.alternative_available = TRUE THEN 1 END) as alternatives_available
FROM maverick_spend_analysis msa
JOIN procurement_transactions pt ON msa.transaction_id = pt.transaction_id
WHERE pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
GROUP BY pt.commodity_name, msa.reason_code
ORDER BY total_impact DESC;

-- Policy Compliance by Department
SELECT 
    pt.cost_center_description,
    COUNT(pt.transaction_id) as total_transactions,
    COUNT(CASE WHEN ppc.compliance_status = 'compliant' THEN 1 END) as compliant_transactions,
    COUNT(CASE WHEN ppc.compliance_status = 'violation' THEN 1 END) as violation_transactions,
    (COUNT(CASE WHEN ppc.compliance_status = 'compliant' THEN 1 END) / COUNT(pt.transaction_id)) * 100 as compliance_rate,
    SUM(CASE WHEN ppc.compliance_status = 'violation' THEN pt.amount_usd ELSE 0 END) as violation_spend
FROM procurement_transactions pt
LEFT JOIN purchase_policy_compliance ppc ON pt.transaction_id = ppc.transaction_id
WHERE pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
GROUP BY pt.cost_center_description
ORDER BY compliance_rate ASC;
```

### 6. Working Capital Impact Report

```sql
-- DPO Trending Analysis
SELECT 
    wca.period_year,
    wca.period_month,
    wca.dpo_current,
    wca.dpo_target,
    wca.cash_locked_in_payables,
    wca.cash_released,
    wca.optimization_opportunity,
    LAG(wca.dpo_current) OVER (ORDER BY wca.period_year, wca.period_month) as previous_dpo,
    wca.dpo_current - LAG(wca.dpo_current) OVER (ORDER BY wca.period_year, wca.period_month) as dpo_change
FROM working_capital_analysis wca
WHERE wca.period_year >= YEAR(CURRENT_DATE) - 2
ORDER BY wca.period_year DESC, wca.period_month DESC;

-- Early Payment Discount Analysis
SELECT 
    v.vendor_name,
    pta.contracted_terms,
    pta.actual_avg_terms,
    pta.early_payment_discount_rate,
    pta.discount_uptake_rate,
    pta.savings_from_discounts,
    SUM(pt.amount_usd) as annual_spend,
    (pta.savings_from_discounts / SUM(pt.amount_usd)) * 100 as savings_rate,
    CASE 
        WHEN pta.discount_uptake_rate >= 80 THEN 'Excellent'
        WHEN pta.discount_uptake_rate >= 60 THEN 'Good'
        WHEN pta.discount_uptake_rate >= 40 THEN 'Fair'
        ELSE 'Poor'
    END as discount_performance
FROM payment_terms_analysis pta
JOIN vendors v ON pta.supplier_id = v.vendor_id
JOIN procurement_transactions pt ON v.vendor_id = pt.vendor_id 
    AND YEAR(pt.date) = pta.period_year
WHERE pta.period_year = YEAR(CURRENT_DATE)
AND pta.early_payment_discount_rate > 0
GROUP BY v.vendor_id, v.vendor_name, pta.contracted_terms, pta.actual_avg_terms,
         pta.early_payment_discount_rate, pta.discount_uptake_rate, pta.savings_from_discounts
ORDER BY savings_from_discounts DESC;

-- Payment Terms Optimization Opportunities
SELECT 
    v.tier_classification,
    COUNT(*) as supplier_count,
    AVG(pta.contracted_terms) as avg_contracted_terms,
    AVG(pta.actual_avg_terms) as avg_actual_terms,
    AVG(pta.variance_days) as avg_variance,
    SUM(pta.savings_from_discounts) as total_discount_savings,
    SUM(pt.amount_usd) as total_spend,
    CASE 
        WHEN AVG(pta.variance_days) > 5 THEN 'Opportunity to extend terms'
        WHEN AVG(pta.variance_days) < -5 THEN 'Risk of early payment'
        ELSE 'Terms aligned'
    END as optimization_recommendation
FROM payment_terms_analysis pta
JOIN vendors v ON pta.supplier_id = v.vendor_id
JOIN procurement_transactions pt ON v.vendor_id = pt.vendor_id 
    AND YEAR(pt.date) = pta.period_year
WHERE pta.period_year = YEAR(CURRENT_DATE)
GROUP BY v.tier_classification
ORDER BY total_spend DESC;
```

## Low Priority Reports (Phase 3)

### 7. ESG & Diversity Report

```sql
-- Diversity Spend Summary
SELECT 
    sdm.diversity_type,
    COUNT(DISTINCT sdm.supplier_id) as supplier_count,
    SUM(pt.amount_usd) as total_spend,
    (SUM(pt.amount_usd) / total_company_spend.total) * 100 as diversity_spend_percentage,
    AVG(esp.overall_esg_score) as avg_esg_score
FROM supplier_diversity_metrics sdm
JOIN procurement_transactions pt ON sdm.supplier_id = pt.vendor_id
JOIN esg_performance_scorecards esp ON sdm.supplier_id = esp.supplier_id
CROSS JOIN (
    SELECT SUM(amount_usd) as total 
    FROM procurement_transactions 
    WHERE date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
) total_company_spend
WHERE pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
AND esp.period_year = YEAR(CURRENT_DATE)
GROUP BY sdm.diversity_type, total_company_spend.total
ORDER BY total_spend DESC;

-- ESG Performance by Tier
SELECT 
    v.tier_classification,
    COUNT(DISTINCT v.vendor_id) as supplier_count,
    AVG(esp.environmental_score) as avg_environmental_score,
    AVG(esp.social_score) as avg_social_score,
    AVG(esp.governance_score) as avg_governance_score,
    AVG(esp.overall_esg_score) as avg_overall_esg_score,
    COUNT(CASE WHEN esp.esg_tier = 'platinum' THEN 1 END) as platinum_suppliers,
    COUNT(CASE WHEN esp.esg_tier = 'gold' THEN 1 END) as gold_suppliers,
    SUM(pt.amount_usd) as total_spend
FROM vendors v
LEFT JOIN esg_performance_scorecards esp ON v.vendor_id = esp.supplier_id 
    AND esp.period_year = YEAR(CURRENT_DATE)
LEFT JOIN procurement_transactions pt ON v.vendor_id = pt.vendor_id 
    AND pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
WHERE v.status = 'Active'
GROUP BY v.tier_classification
ORDER BY avg_overall_esg_score DESC;

-- Carbon Footprint Analysis
SELECT 
    pt.commodity_name,
    COUNT(DISTINCT cft.supplier_id) as suppliers_with_data,
    AVG(cft.total_emissions) as avg_total_emissions,
    SUM(cft.total_emissions * pt.amount_usd) / SUM(pt.amount_usd) as weighted_avg_emissions,
    SUM(pt.amount_usd) as category_spend,
    (SUM(cft.total_emissions * pt.amount_usd) / SUM(pt.amount_usd)) / SUM(pt.amount_usd) * 1000000 as emissions_per_million_spend
FROM carbon_footprint_tracking cft
JOIN procurement_transactions pt ON cft.supplier_id = pt.vendor_id
WHERE cft.measurement_year = YEAR(CURRENT_DATE) - 1
AND pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)
GROUP BY pt.commodity_name
ORDER BY emissions_per_million_spend DESC;
```

## Cross-Report KPI Dashboard

```sql
-- Comprehensive Executive KPI Summary
SELECT 
    'Supplier Performance' as metric_category,
    CONCAT(ROUND(AVG(sc.overall_score), 1), '%') as current_value,
    '>85%' as target_value,
    CASE WHEN AVG(sc.overall_score) >= 85 THEN 'Green' ELSE 'Red' END as status
FROM supplier_scorecards sc 
WHERE sc.period_year = YEAR(CURRENT_DATE)

UNION ALL

SELECT 
    'Savings Realization Rate',
    CONCAT(ROUND((SUM(sr.realized_savings) / SUM(sr.forecasted_savings)) * 100, 1), '%'),
    '>90%',
    CASE WHEN (SUM(sr.realized_savings) / SUM(sr.forecasted_savings)) >= 0.9 THEN 'Green' ELSE 'Red' END
FROM savings_realization sr 
WHERE sr.period_year = YEAR(CURRENT_DATE)

UNION ALL

SELECT 
    'Contract Coverage',
    CONCAT(ROUND((SUM(CASE WHEN cm.contract_id IS NOT NULL THEN pt.amount_usd ELSE 0 END) / SUM(pt.amount_usd)) * 100, 1), '%'),
    '>80%',
    CASE WHEN (SUM(CASE WHEN cm.contract_id IS NOT NULL THEN pt.amount_usd ELSE 0 END) / SUM(pt.amount_usd)) >= 0.8 THEN 'Green' ELSE 'Red' END
FROM procurement_transactions pt
LEFT JOIN contract_master cm ON pt.vendor_id = cm.supplier_id
WHERE pt.date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH)

UNION ALL

SELECT 
    'ESG Compliance',
    CONCAT(ROUND(AVG(esp.overall_esg_score), 1), '%'),
    '>75%',
    CASE WHEN AVG(esp.overall_esg_score) >= 75 THEN 'Green' ELSE 'Red' END
FROM esg_performance_scorecards esp 
WHERE esp.period_year = YEAR(CURRENT_DATE);
```

This comprehensive set of SQL examples demonstrates how the enhanced database schema enables automated generation of all 17 C-Suite procurement reports with real-time data and sophisticated analytics capabilities.
