-- ==============================================================================
-- Project 5: Multi-Channel E-Commerce & Customer Journey Analytics
-- Platform: Google Cloud BigQuery
-- Author: Qusai Tailor
-- Description: Multi-channel conversion funnel modeling calculating customer 
--              acquisition costs (CAC), lifetime value (LTV), and attribution.
-- ==============================================================================

WITH user_sessions AS (
    SELECT 
        session_id,
        user_id,
        traffic_source,
        device_category,
        session_start_timestamp,
        page_views,
        cart_additions,
        is_checkout_initiated
    FROM `your_project.ecommerce.web_sessions`
),

order_conversions AS (
    SELECT 
        order_id,
        user_id,
        session_id,
        order_timestamp,
        order_value_usd,
        discount_amount_usd,
        (order_value_usd - discount_amount_usd) AS net_revenue_usd
    FROM `your_project.ecommerce.orders`
),

funnel_attribution AS (
    SELECT 
        s.traffic_source,
        s.device_category,
        COUNT(DISTINCT s.session_id) AS total_sessions,
        SUM(s.cart_additions) AS total_cart_additions,
        SUM(s.is_checkout_initiated) AS total_checkouts_initiated,
        COUNT(DISTINCT o.order_id) AS total_completed_orders,
        SUM(o.net_revenue_usd) AS total_net_revenue
    FROM user_sessions s
    LEFT JOIN order_conversions o ON s.session_id = o.session_id
    GROUP BY s.traffic_source, s.device_category
)

SELECT 
    traffic_source,
    device_category,
    total_sessions,
    total_completed_orders,
    ROUND(SAFE_DIVIDE(total_completed_orders, total_sessions) * 100, 2) AS session_conversion_rate_pct,
    ROUND(SAFE_DIVIDE(total_completed_orders, total_checkouts_initiated) * 100, 2) AS checkout_completion_rate_pct,
    COALESCE(ROUND(total_net_revenue, 2), 0.00) AS total_net_revenue,
    COALESCE(ROUND(SAFE_DIVIDE(total_net_revenue, total_completed_orders), 2), 0.00) AS avg_order_value_usd
FROM funnel_attribution
ORDER BY total_net_revenue DESC;
