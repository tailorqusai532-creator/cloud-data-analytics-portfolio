-- ==============================================================================
-- Project 4: Financial Accounting & Ledger Audit Analytics
-- Platform: Google Cloud BigQuery
-- Author: Qusai Tailor
-- Description: Financial ledger reconciliation pipeline detecting journal entry 
--              anomalies, unposted debit/credit imbalances, and cost-center variance.
-- ==============================================================================

WITH journal_entries AS (
    SELECT 
        entry_id,
        account_code,
        account_description,
        cost_center,
        entry_date,
        posting_status,
        debit_amount,
        credit_amount,
        (debit_amount - credit_amount) AS net_balance_impact
    FROM `your_project.finance_audit.general_ledger`
),

daily_reconciliation AS (
    SELECT 
        entry_date,
        cost_center,
        COUNT(entry_id) AS total_journal_entries,
        SUM(debit_amount) AS total_debits,
        SUM(credit_amount) AS total_credits,
        ROUND(SUM(debit_amount) - SUM(credit_amount), 2) AS out_of_balance_amount
    FROM journal_entries
    WHERE posting_status = 'POSTED'
    GROUP BY entry_date, cost_center
),

variance_flagging AS (
    SELECT 
        j.entry_id,
        j.account_code,
        j.account_description,
        j.cost_center,
        j.entry_date,
        j.debit_amount,
        j.credit_amount,
        r.out_of_balance_amount,
        CASE 
            WHEN r.out_of_balance_amount != 0 THEN 'Unbalanced Daily Ledger'
            WHEN j.debit_amount > 50000 OR j.credit_amount > 50000 THEN 'High-Value Entry (Manual Audit Req)'
            ELSE 'Verified'
        END AS audit_status
    FROM journal_entries j
    JOIN daily_reconciliation r 
      ON j.entry_date = r.entry_date 
     AND j.cost_center = r.cost_center
)

SELECT 
    audit_status,
    cost_center,
    COUNT(entry_id) AS entry_count,
    ROUND(SUM(debit_amount), 2) AS aggregate_debits,
    ROUND(SUM(credit_amount), 2) AS aggregate_credits,
    ROUND(SUM(out_of_balance_amount), 2) AS net_variance
FROM variance_flagging
GROUP BY audit_status, cost_center
ORDER BY net_variance DESC;
