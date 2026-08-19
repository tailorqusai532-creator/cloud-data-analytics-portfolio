-- ==============================================================================
-- Project 2: SaaS Revenue & Churn Analytics Platform
-- Platform: Google Cloud BigQuery
-- Author: Qusai Tailor
-- Description: Multi-table transformation calculating Monthly Recurring Revenue (MRR),
--              ARR, expansion velocity, active subscriber cohorts, and net churn rate.
-- ==============================================================================

WITH subscriber_activity AS (
    SELECT 
        subscription_id,
        customer_id,
        plan_tier,
        billing_cycle,
        mrr_amount,
        status,
        start_date,
        cancellation_date,
        DATE_TRUNC(start_date, MONTH) AS signup_cohort_month,
        DATE_TRUNC(cancellation_date, MONTH) AS churn_month
    FROM `your_project.saas_analytics.subscriptions`
),

mrr_movements AS (
    SELECT 
        customer_id,
        subscription_id,
        plan_tier,
        mrr_amount,
        status,
        signup_cohort_month,
        mrr_amount * 12 AS arr_amount,
        LAG(mrr_amount) OVER (PARTITION BY customer_id ORDER BY start_date) AS previous_mrr,
        LEAD(mrr_amount) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_mrr
    FROM subscriber_activity
),

churn_metrics AS (
    SELECT 
        signup_cohort_month,
        COUNT(DISTINCT customer_id) AS total_cohort_customers,
        COUNT(DISTINCT CASE WHEN status = 'Cancelled' THEN customer_id END) AS churned_customers,
        SUM(mrr_amount) AS total_cohort_mrr,
        SUM(CASE WHEN status = 'Cancelled' THEN mrr_amount ELSE 0 END) AS churned_mrr
    FROM subscriber_activity
    GROUP BY signup_cohort_month
)

SELECT 
    m.signup_cohort_month,
    c.total_cohort_customers,
    c.churned_customers,
    ROUND(SAFE_DIVIDE(c.churned_customers, c.total_cohort_customers) * 100, 2) AS customer_churn_rate_pct,
    c.total_cohort_mrr,
    c.churned_mrr,
    ROUND(SAFE_DIVIDE(c.churned_mrr, c.total_cohort_mrr) * 100, 2) AS revenue_churn_rate_pct,
    SUM(m.arr_amount) AS total_projected_arr
FROM mrr_movements m
JOIN churn_metrics c ON m.signup_cohort_month = c.signup_cohort_month
GROUP BY 
    m.signup_cohort_month, 
    c.total_cohort_customers, 
    c.churned_customers, 
    c.total_cohort_mrr, 
    c.churned_mrr;
