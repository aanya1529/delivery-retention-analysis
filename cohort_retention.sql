--Step 1: Check the date range and monthly volume

SELECT DATE_TRUNC('month', purchased_at) AS month,
       COUNT(*) AS orders
FROM order_base
GROUP BY 1
ORDER BY 1;

--Step 2: Build the cohort table
DROP TABLE IF EXISTS cohort_activity;

CREATE TABLE cohort_activity AS
WITH first_order AS (
  SELECT customer_unique_id,
         DATE_TRUNC('month', MIN(purchased_at)) AS cohort_month
  FROM order_base
  GROUP BY customer_unique_id
)
SELECT
  f.cohort_month,
  (EXTRACT(YEAR FROM AGE(DATE_TRUNC('month', b.purchased_at), f.cohort_month)) * 12
   + EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', b.purchased_at), f.cohort_month)))::int AS month_number,
  COUNT(DISTINCT b.customer_unique_id) AS active_customers
FROM order_base b
JOIN first_order f ON b.customer_unique_id = f.customer_unique_id
GROUP BY 1, 2;

--Step 3: Calculate retention percentages

SELECT
  cohort_month,
  month_number,
  active_customers,
  ROUND(100.0 * active_customers /
        FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_number), 2) AS retention_pct
FROM cohort_activity
WHERE cohort_month >= '2017-01-01'
ORDER BY cohort_month, month_number;

--Step 4: Calculate the 90-day repeat rate
WITH max_date AS (
  SELECT MAX(purchased_at) AS d FROM order_base
),
first_order AS (
  SELECT customer_unique_id, MIN(purchased_at) AS first_purchase
  FROM order_base
  GROUP BY customer_unique_id
),
next_order AS (
  SELECT f.customer_unique_id, f.first_purchase,
         MIN(b.purchased_at) FILTER (WHERE b.purchased_at > f.first_purchase) AS next_purchase
  FROM first_order f
  JOIN order_base b ON b.customer_unique_id = f.customer_unique_id
  GROUP BY f.customer_unique_id, f.first_purchase
)
SELECT
  COUNT(*) AS eligible_customers,
  COUNT(*) FILTER (WHERE next_purchase <= first_purchase + INTERVAL '90 days') AS repeaters_90d,
  ROUND(100.0 * COUNT(*) FILTER (WHERE next_purchase <= first_purchase + INTERVAL '90 days')
        / COUNT(*), 2) AS repeat_rate_90d
FROM next_order, max_date
WHERE first_purchase <= max_date.d - INTERVAL '90 days';
