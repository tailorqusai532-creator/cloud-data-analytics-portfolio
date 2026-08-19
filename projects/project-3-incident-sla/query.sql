-- ==============================================================================
-- Project 3: Operational Incident & SLA Performance Analytics
-- Platform: Google Cloud BigQuery
-- Author: Qusai Tailor
-- Description: Incident lifecycle transformation analyzing response times, Mean
--              Time to Resolution (MTTR), SLA breach trends, and severity tiers.
-- ==============================================================================

WITH incident_base AS (
    SELECT 
        incident_id,
        service_name,
        severity_tier, -- P1, P2, P3, P4
        assigned_team,
        created_at,
        acknowledged_at,
        resolved_at,
        sla_target_hours,
        TIMESTAMP_DIFF(acknowledged_at, created_at, MINUTE) AS time_to_acknowledge_min,
        ROUND(TIMESTAMP_DIFF(resolved_at, created_at, MINUTE) / 60.0, 2) AS resolution_time_hours
    FROM `your_project.operations.incidents_master`
),

sla_evaluations AS (
    SELECT 
        incident_id,
        service_name,
        severity_tier,
        assigned_team,
        time_to_acknowledge_min,
        resolution_time_hours,
        sla_target_hours,
        CASE 
            WHEN resolution_time_hours > sla_target_hours THEN 1 
            ELSE 0 
        END AS is_sla_breached
    FROM incident_base
)

SELECT 
    service_name,
    severity_tier,
    assigned_team,
    COUNT(incident_id) AS total_incidents,
    ROUND(AVG(time_to_acknowledge_min), 2) AS avg_time_to_acknowledge_min,
    ROUND(AVG(resolution_time_hours), 2) AS mttr_hours, -- Mean Time To Resolution
    SUM(is_sla_breached) AS total_sla_breaches,
    ROUND(SAFE_DIVIDE(SUM(is_sla_breached), COUNT(incident_id)) * 100, 2) AS sla_breach_rate_pct
FROM sla_evaluations
GROUP BY 
    service_name, 
    severity_tier, 
    assigned_team;
