--Significance test (Python):

/*from scipy.stats import chi2_contingency
import numpy as np

# rows: on-time vs late; columns: repeated vs not
table = np.array([[907, 68746 - 907],
                  [70, 6572 - 70]])
chi2, p, _, _ = chi2_contingency(table)
print(round(p, 3)) */

WITH max_date AS (SELECT MAX(purchased_at) AS d FROM order_base),
first_order AS (
  SELECT DISTINCT ON (customer_unique_id)
         customer_unique_id, purchased_at AS first_purchase,
         delivered_at AS first_delivery, delay_bucket
  FROM order_base
  ORDER BY customer_unique_id, purchased_at, order_id
),
next_order AS (
  SELECT f.customer_unique_id, f.first_purchase, f.first_delivery, f.delay_bucket,
         MIN(b.purchased_at) FILTER (
           WHERE b.purchased_at::date > f.first_purchase::date
         ) AS next_purchase
  FROM first_order f
  JOIN order_base b ON b.customer_unique_id = f.customer_unique_id
  GROUP BY f.customer_unique_id, f.first_purchase, f.first_delivery, f.delay_bucket
)
SELECT delay_bucket,
       COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE next_purchase > first_delivery
                        AND next_purchase <= first_delivery + INTERVAL '90 days') AS repeaters_90d_post_delivery,
       ROUND(100.0 * COUNT(*) FILTER (WHERE next_purchase > first_delivery
                        AND next_purchase <= first_delivery + INTERVAL '90 days')
             / COUNT(*), 2) AS repeat_rate
FROM next_order, max_date
WHERE first_delivery <= max_date.d - INTERVAL '90 days'
GROUP BY delay_bucket
ORDER BY delay_bucket;