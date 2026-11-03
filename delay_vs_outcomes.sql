--Step 1: Add delay buckets to order_base

ALTER TABLE order_base ADD COLUMN IF NOT EXISTS delay_bucket TEXT;

UPDATE order_base
SET delay_bucket = CASE
  WHEN delay_days <= 0 THEN '1. On time or early'
  WHEN delay_days <= 3 THEN '2. 1-3 days late'
  WHEN delay_days <= 7 THEN '3. 4-7 days late'
  ELSE '4. 8+ days late'
END;

--Step 2: Check bucket sizes

SELECT delay_bucket,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM order_base
GROUP BY delay_bucket
ORDER BY delay_bucket;

--Step 3: Review score by bucket (all orders)

SELECT delay_bucket,
       COUNT(*) AS orders,
       ROUND(AVG(review_score), 2) AS avg_review,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2)
             / COUNT(review_score), 1) AS pct_low_reviews
FROM order_base
GROUP BY delay_bucket
ORDER BY delay_bucket;

--Step 4: 90-day repeat rate by the first order’s delay bucket

WITH max_date AS (SELECT MAX(purchased_at) AS d FROM order_base),
first_order AS (
  SELECT DISTINCT ON (customer_unique_id)
         customer_unique_id,
         purchased_at AS first_purchase,
         delay_bucket,
         delay_days
  FROM order_base
  ORDER BY customer_unique_id, purchased_at, order_id
),
next_order AS (
  SELECT f.customer_unique_id, f.first_purchase, f.delay_bucket, f.delay_days,
         MIN(b.purchased_at) FILTER (
           WHERE b.purchased_at::date > f.first_purchase::date
         ) AS next_purchase
  FROM first_order f
  JOIN order_base b ON b.customer_unique_id = f.customer_unique_id
  GROUP BY f.customer_unique_id, f.first_purchase, f.delay_bucket, f.delay_days
)
SELECT delay_bucket,
       COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE next_purchase <= first_purchase + INTERVAL '90 days') AS repeaters_90d,
       ROUND(100.0 * COUNT(*) FILTER (WHERE next_purchase <= first_purchase + INTERVAL '90 days')
             / COUNT(*), 2) AS repeat_rate_90d
FROM next_order, max_date
WHERE first_purchase <= max_date.d - INTERVAL '90 days'
GROUP BY delay_bucket
ORDER BY delay_bucket;