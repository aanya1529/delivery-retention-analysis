-- Baselines for customers in the nine high-late states
SELECT
  COUNT(*) AS orders,
  ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / COUNT(review_score), 2) AS pct_low_reviews,
  ROUND(100.0 * COUNT(*) FILTER (WHERE delay_days > 0) / COUNT(*), 2) AS pct_late
FROM order_base
WHERE customer_state IN ('MA','CE','BA','RJ','PA','ES','MS','PB','PE');

WITH max_date AS (SELECT MAX(purchased_at) AS d FROM order_base),
first_order AS (
  SELECT DISTINCT ON (customer_unique_id)
         customer_unique_id, purchased_at AS first_purchase, delivered_at AS first_delivery
  FROM order_base
  WHERE customer_state IN ('MA','CE','BA','RJ','PA','ES','MS','PB','PE')
  ORDER BY customer_unique_id, purchased_at, order_id
),
next_order AS (
  SELECT f.customer_unique_id, f.first_purchase, f.first_delivery,
         MIN(b.purchased_at) FILTER (WHERE b.purchased_at::date > f.first_purchase::date) AS next_purchase
  FROM first_order f
  JOIN order_base b ON b.customer_unique_id = f.customer_unique_id
  GROUP BY f.customer_unique_id, f.first_purchase, f.first_delivery
)
SELECT COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE next_purchase > first_delivery
                        AND next_purchase <= first_delivery + INTERVAL '90 days') AS repeaters,
       ROUND(100.0 * COUNT(*) FILTER (WHERE next_purchase > first_delivery
                        AND next_purchase <= first_delivery + INTERVAL '90 days') / COUNT(*), 2) AS repeat_rate
FROM next_order, max_date
WHERE first_delivery <= max_date.d - INTERVAL '90 days';

--on time rate
SELECT
  ROUND(100.0 * COUNT(*) FILTER (WHERE delay_days <= 0) / COUNT(*), 1) AS on_time_rate,
  ROUND(AVG(review_score), 2) AS avg_review
FROM order_base;