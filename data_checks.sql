CREATE TABLE olist_orders_dataset (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

SELECT *
FROM olist_orders_dataset
LIMIT 10;


CREATE TABLE IF NOT EXISTS olist_customers_dataset (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city TEXT,
    customer_state VARCHAR(2)
);

CREATE TABLE IF NOT EXISTS olist_geolocation_dataset (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DOUBLE PRECISION,
    geolocation_lng DOUBLE PRECISION,
    geolocation_city TEXT,
    geolocation_state VARCHAR(2)
);

CREATE TABLE IF NOT EXISTS olist_order_items_dataset (
    order_id VARCHAR(50),
    order_item_id INTEGER,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2)
);

CREATE TABLE IF NOT EXISTS olist_order_payments_dataset (
    order_id VARCHAR(50),
    payment_sequential INTEGER,
    payment_type VARCHAR(30),
    payment_installments INTEGER,
    payment_value NUMERIC(12,2)
);

CREATE TABLE IF NOT EXISTS olist_order_reviews_dataset (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

CREATE TABLE IF NOT EXISTS olist_products_dataset (
    product_id VARCHAR(50),
    product_category_name TEXT,
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

CREATE TABLE IF NOT EXISTS olist_sellers_dataset (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(10),
    seller_city TEXT,
    seller_state VARCHAR(2)
);

CREATE TABLE IF NOT EXISTS product_category_name_translation (
    product_category_name TEXT,
    product_category_name_english TEXT
);

--Step 1: Confirm the tables loaded correctly
SELECT 'orders' AS tbl, COUNT(*) FROM olist_orders_dataset
UNION ALL SELECT 'customers', COUNT(*) FROM olist_customers_dataset
UNION ALL SELECT 'reviews', COUNT(*) FROM olist_order_reviews_dataset
UNION ALL SELECT 'items', COUNT(*) FROM olist_order_items_dataset;

--Step 2: Check column data types
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'olist_orders_dataset';

--Step 3: Look at order statuses
SELECT order_status, COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY orders DESC;

--Step 4: Check for missing dates
SELECT
  COUNT(*) AS delivered_orders,
  COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_delivery_date,
  COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS missing_estimate
FROM olist_orders_dataset
WHERE order_status = 'delivered';

--Step 5: Check for duplicates (two important traps)
--Reviews per order (some orders have more than one review):
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (
  SELECT order_id FROM olist_order_reviews_dataset
  GROUP BY order_id HAVING COUNT(*) > 1
) t;

--Customer ID vs. unique ID:

SELECT COUNT(DISTINCT customer_id) AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM olist_customers_dataset;

--Step 6: Check for impossible values

SELECT COUNT(*) AS delivered_before_purchase
FROM olist_orders_dataset
WHERE order_delivered_customer_date::timestamp < order_purchase_timestamp::timestamp;

--Step 7: Build the base table
DROP TABLE IF EXISTS order_base;
CREATE TABLE order_base AS
WITH reviews_dedup AS (
  SELECT order_id, AVG(review_score) AS review_score
  FROM olist_order_reviews_dataset
  GROUP BY order_id
),
orders_clean AS (
  SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp::timestamp AS purchased_at,
    o.order_delivered_customer_date::timestamp AS delivered_at,
    o.order_estimated_delivery_date::timestamp AS estimated_at
  FROM olist_orders_dataset o
  JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
  oc.*,
  ROUND(EXTRACT(EPOCH FROM (delivered_at - estimated_at)) / 86400.0, 1) AS delay_days,
  r.review_score
FROM orders_clean oc
LEFT JOIN reviews_dedup r ON oc.order_id = r.order_id
WHERE oc.delivered_at >= oc.purchased_at;

--Step 8: Verify the base table

-- One row per order?
SELECT COUNT(*) AS rows, COUNT(DISTINCT order_id) AS distinct_orders FROM order_base;

-- Delay distribution and review coverage
SELECT
  MIN(delay_days) AS min_delay,
  ROUND(AVG(delay_days), 1) AS avg_delay,
  MAX(delay_days) AS max_delay,
  COUNT(*) FILTER (WHERE review_score IS NULL) AS missing_reviews
FROM order_base;

SELECT 'customers' AS tbl, COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS distinct_ids FROM olist_customers_dataset
UNION ALL
SELECT 'reviews', COUNT(*), COUNT(DISTINCT review_id) FROM olist_order_reviews_dataset
UNION ALL
SELECT 'items', COUNT(*), COUNT(DISTINCT (order_id, order_item_id)) FROM olist_order_items_dataset;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id) AS distinct_orders
FROM olist_orders_dataset;

SELECT order_status, COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY orders DESC;