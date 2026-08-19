-- ==============================================================================
-- Project 1: Supply Chain & Inventory Risk Control Center
-- Platform: Google Cloud BigQuery
-- Author: Qusai Tailor
-- Description: End-to-end data transformation pipeline calculating inventory turnover,
--              supplier lead-time variances, stockout risks, and SLA breach rates.
-- ==============================================================================

WITH inventory_base AS (
    SELECT 
        product_id,
        product_name,
        category,
        warehouse_location,
        current_stock_level,
        reorder_point,
        safety_stock_level,
        unit_cost,
        last_restock_date,
        LEAD_TIME_DAYS
    FROM `your_project.supply_chain.inventory_master`
),

order_fulfillment AS (
    SELECT 
        order_id,
        product_id,
        supplier_id,
        order_date,
        expected_delivery_date,
        actual_delivery_date,
        quantity_ordered,
        quantity_received,
        DATE_DIFF(actual_delivery_date, expected_delivery_date, DAY) AS delivery_delay_days,
        CASE 
            WHEN actual_delivery_date > expected_delivery_date THEN 1 
            ELSE 0 
        END AS is_sla_breach
    FROM `your_project.supply_chain.purchase_orders`
),

supplier_performance AS (
    SELECT 
        supplier_id,
        COUNT(order_id) AS total_orders,
        AVG(delivery_delay_days) AS avg_delay_days,
        SUM(is_sla_breach) AS total_sla_breaches,
        ROUND(SAFE_DIVIDE(SUM(is_sla_breach), COUNT(order_id)) * 100, 2) AS sla_breach_rate_pct
    FROM order_fulfillment
    GROUP BY supplier_id
)

SELECT 
    i.product_id,
    i.product_name,
    i.category,
    i.warehouse_location,
    i.current_stock_level,
    i.reorder_point,
    i.safety_stock_level,
    CASE 
        WHEN i.current_stock_level = 0 THEN 'Out of Stock'
        WHEN i.current_stock_level <= i.safety_stock_level THEN 'Critical Risk'
        WHEN i.current_stock_level <= i.reorder_point THEN 'Reorder Needed'
        ELSE 'Optimal'
    END AS stock_risk_status,
    sp.avg_delay_days,
    sp.sla_breach_rate_pct,
    ROUND(i.current_stock_level * i.unit_cost, 2) AS total_inventory_value
FROM inventory_base i
LEFT JOIN order_fulfillment o ON i.product_id = o.product_id
LEFT JOIN supplier_performance sp ON o.supplier_id = sp.supplier_id;
