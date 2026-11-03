--Step 1: Late rate and reviews by customer state

SELECT customer_state,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE delay_days > 0) / COUNT(*), 1) AS pct_late,
       ROUND(AVG(delay_days), 1) AS avg_delay_days,
       ROUND(AVG(review_score), 2) AS avg_review
FROM order_base
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY pct_late DESC;

--Step 2: Late rate and reviews by product category

WITH order_category AS (
  SELECT DISTINCT ON (oi.order_id)
         oi.order_id,
         COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category
  FROM olist_order_items_dataset oi
  LEFT JOIN olist_products_dataset p ON oi.product_id = p.product_id
  LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
  ORDER BY oi.order_id, oi.order_item_id
)
SELECT oc.category,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE b.delay_days > 0) / COUNT(*), 1) AS pct_late,
       ROUND(AVG(b.review_score), 2) AS avg_review
FROM order_base b
JOIN order_category oc ON b.order_id = oc.order_id
GROUP BY oc.category
HAVING COUNT(*) >= 500
ORDER BY pct_late DESC;

--Step 3: Late rate by seller

WITH order_seller AS (
  SELECT DISTINCT ON (order_id) order_id, seller_id
  FROM olist_order_items_dataset
  ORDER BY order_id, order_item_id
)
SELECT os.seller_id,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE b.delay_days > 0) / COUNT(*), 1) AS pct_late,
       ROUND(AVG(b.review_score), 2) AS avg_review
FROM order_base b
JOIN order_seller os ON b.order_id = os.order_id
GROUP BY os.seller_id
HAVING COUNT(*) >= 100
ORDER BY pct_late DESC
LIMIT 20;

--Step 4: Concentration check

WITH order_seller AS (
  SELECT DISTINCT ON (order_id) order_id, seller_id
  FROM olist_order_items_dataset
  ORDER BY order_id, order_item_id
),
seller_late AS (
  SELECT os.seller_id,
         COUNT(*) FILTER (WHERE b.delay_days > 0) AS late_orders
  FROM order_base b
  JOIN order_seller os ON b.order_id = os.order_id
  GROUP BY os.seller_id
),
ranked AS (
  SELECT late_orders,
         SUM(late_orders) OVER (ORDER BY late_orders DESC, seller_id) AS running_total,
         ROW_NUMBER() OVER (ORDER BY late_orders DESC, seller_id) AS rn
  FROM seller_late
)
SELECT
  (SELECT COUNT(*) FROM seller_late) AS total_sellers,
  (SELECT SUM(late_orders) FROM seller_late) AS total_late_orders,
  (SELECT running_total FROM ranked WHERE rn = 100) AS late_orders_from_top_100_sellers;

--concentrated check 
  WITH order_seller AS (
  SELECT DISTINCT ON (order_id) order_id, seller_id
  FROM olist_order_items_dataset
  ORDER BY order_id, order_item_id
),
seller_stats AS (
  SELECT os.seller_id,
         COUNT(*) AS orders,
         COUNT(*) FILTER (WHERE b.delay_days > 0) AS late_orders
  FROM order_base b
  JOIN order_seller os ON b.order_id = os.order_id
  GROUP BY os.seller_id
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (ORDER BY late_orders DESC, seller_id) AS rn
  FROM seller_stats
)

SELECT
  ROUND(100.0 * SUM(orders) FILTER (WHERE rn <= 100) / SUM(orders), 1) AS pct_of_orders_top100,
  ROUND(100.0 * SUM(late_orders) FILTER (WHERE rn <= 100) / SUM(late_orders), 1) AS pct_of_late_top100,
  ROUND(100.0 * SUM(late_orders) FILTER (WHERE rn <= 100)
        / SUM(orders) FILTER (WHERE rn <= 100), 1) AS late_rate_top100,
  ROUND(100.0 * SUM(late_orders) FILTER (WHERE rn > 100)
        / SUM(orders) FILTER (WHERE rn > 100), 1) AS late_rate_rest
FROM ranked;

-- Seller concentration check: top 100 sellers by late orders vs. their share of total orders

SELECT
  ROUND(100.0 * COUNT(*) FILTER (WHERE customer_state IN ('MA','CE','BA','RJ','PA','ES','MS','PB','PE')) / COUNT(*), 1) AS pct_of_orders_high_late_states,
  ROUND(100.0 * COUNT(*) FILTER (WHERE customer_state IN ('MA','CE','BA','RJ','PA','ES','MS','PB','PE') AND delay_days > 0)
        / COUNT(*) FILTER (WHERE delay_days > 0), 1) AS pct_of_late_orders_high_late_states,
  ROUND(100.0 * COUNT(*) FILTER (WHERE customer_state IN ('MA','CE','BA','RJ','PA','ES','MS','PB','PE') AND delay_days > 0)
        / COUNT(*) FILTER (WHERE customer_state IN ('MA','CE','BA','RJ','PA','ES','MS','PB','PE')), 1) AS late_rate_high_states,
  ROUND(100.0 * COUNT(*) FILTER (WHERE customer_state NOT IN ('MA','CE','BA','RJ','PA','ES','MS','PB','PE') AND delay_days > 0)
        / COUNT(*) FILTER (WHERE customer_state NOT IN ('MA','CE','BA','RJ','PA','ES','MS','PB','PE')), 1) AS late_rate_other_states
FROM order_base;