# Does Late Delivery Reduce Repeat Purchase? (Olist Marketplace Analysis)

A product analytics project using about 100K Brazilian e-commerce orders (2016 to 2018) to test whether delivery delays hurt review scores and 90-day repeat purchase, to find where late delivery is concentrated, and to design an A/B test for a delivery-promise change.

**Tools:** PostgreSQL, Python (pandas, scipy, statsmodels), Power BI
**Dataset:** [Olist Brazilian E-Commerce Public Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (CC BY-NC-SA 4.0; raw files are not included in this repo)
**Problem statement:** [docs/problem.md](docs/problem.md)

![Dashboard preview](dashboard/dashboard_preview.png)

## Question

Do customers whose orders arrive later than promised give lower review scores and come back to buy again less often? The result informs whether a product team should test a change to the delivery promise shown at checkout, and where to prioritize it.

## Key findings

1. **Late delivery strongly lowers reviews.** The average review falls from 4.29 (on time or early) to 1.73 (8+ days late), and the share of 1 to 2 star reviews rises from 9.2% to 78.3%. About 8% of orders arrive late.
2. **Repeat purchase is rare for everyone.** Only 1.30% of eligible customers place a second order on a later day within 90 days of their first.
3. **Late customers repeat slightly less, but the effect is small.** Measured from delivery, 0.80% of late-delivery customers repeat vs. 1.14% of on-time customers (p = 0.019). Measured from purchase, the gap is 1.07% vs. 1.32% (p = 0.092). Direction is consistent; the difference is about 0.3 percentage points.
4. **Late delivery is concentrated geographically.** Nine states (MA, CE, BA, RJ, PA, ES, MS, PB, PE) account for 24.2% of orders but 40.1% of late orders. Late rates by state range from 5.0% to 19.5%, versus roughly 7% to 10% across product categories.
5. **Seller concentration is mostly a volume effect.** The top 100 sellers by late orders handle 42.9% of orders and 49.6% of late orders (late rate 9.3% vs. 7.1% for other sellers).

**Takeaway:** delivery problems mainly damage satisfaction and have only a modest association with retention. Fixing delivery would protect reviews; it is unlikely to fix low repeat purchase on its own.

## Proposed A/B test

In the nine high-late states, randomize new customers to the current delivery estimate or a more realistic, longer estimate.

| Element | Design |
|---|---|
| Primary metric | Share of 1 to 2 star reviews (baseline 17.24%) |
| Secondary metric | 90-day repeat rate from delivery (baseline 1.00%) |
| Guardrail | Checkout conversion (baseline must come from the company; this dataset has no session data) |
| Sample size | 2,308 customers per arm to detect a 3-point drop in low reviews (5% significance, 80% power) |

Repeat rate is not feasible as the primary metric: even a +0.5-point gain needs 7,673 customers per arm, and a +0.3-point gain needs 19,743 per arm, more than the 17,952 eligible customers in these states.

## Method

1. **Data checks** ([sql/01_data_checks.sql](sql/01_data_checks.sql)): row counts, statuses, missing dates, duplicate reviews, customer_id vs. customer_unique_id, impossible timestamps.
2. **Analysis table** ([sql/02_build_order_base.sql](sql/02_build_order_base.sql)): one row per delivered order with delay in days (actual minus estimated delivery) and one review score per order.
3. **Cohort retention and repeat rate** ([sql/03_cohort_retention.sql](sql/03_cohort_retention.sql)).
4. **Delay vs. outcomes** ([sql/04_delay_vs_outcomes.sql](sql/04_delay_vs_outcomes.sql)): delay buckets, review score and repeat rate by bucket, plus a sensitivity check measuring the 90 days from delivery instead of purchase.
5. **Segments** ([sql/05_segments.sql](sql/05_segments.sql)): late rate by state, category and seller, with a check of seller concentration against order volume.
6. **Statistical tests and sample sizes** ([notebooks/](notebooks/)): chi-square tests on repeat rates; power calculations for the A/B test.
7. **Dashboard** ([dashboard/](dashboard/)): Power BI report built from the exported summary tables in `outputs/`.

### Key definitions

- **Delay (days):** actual delivery date minus estimated delivery date; negative means early.
- **Repeat purchase:** a second order on a later calendar day within 90 days. Same-day second orders are excluded as likely split purchases (counting them would give 2.01% instead of 1.30%).
- **Eligible customers:** customers with at least 90 days of follow-up before the end of the data.
- **Customer identity:** `customer_unique_id`, not `customer_id` (which is generated per order).

## Data quality notes

- The orders table was initially imported twice (exactly double the expected rows); caught by comparing row counts to distinct order IDs, then fixed by re-importing once.
- 8 delivered orders had no delivery date and were excluded; 547 orders had more than one review and were averaged to one score; 646 orders had no review and were kept but left out of review averages.
- Only cohorts from January 2017 onward are used, since 2016 has very few orders.

## Limitations

- Observational data: results show association, not causation. Late orders may differ in region, category or seller.
- One Brazilian marketplace from 2016 to 2018; findings may not generalize.
- Repeat purchase is rare, so repeat-rate differences rest on small numbers of customers. The delivery-based measure reached significance (p = 0.019) while the purchase-based one did not (p = 0.092); the delivery-based definition was chosen after seeing the first result, so both are reported.
- State groupings for the segment comparison were chosen after seeing late rates, so that gap is descriptive, not a test.
- Why some states have more late orders is not established by this data; distance from sellers is an untested hypothesis.

## Repository structure

```
data/         raw Olist CSVs (not committed; see Kaggle link)
sql/          01 to 05, run in order
notebooks/    significance tests and A/B test sample sizes
outputs/      exported summary tables used by the dashboard
dashboard/    Power BI file and preview image
docs/         problem statement, data notes, findings
```

## How to reproduce

1. Download the dataset from Kaggle and place the 9 CSVs in `data/`.
2. Create a PostgreSQL database and load each CSV into a table named as in the Olist file (for example `olist_orders_dataset`). Import each file once, with the header row enabled, and verify row counts (orders: 99,441).
3. Run the files in `sql/` in order (01 to 05).
4. Export the result tables to `outputs/` and open `dashboard/olist_delivery_dashboard.pbix`, or rebuild the visuals from those files.
5. Run the notebooks in `notebooks/` for the significance tests and sample-size calculations.

## Author

Aanya Jha, Computer Science graduate (DTU, 2026). [LinkedIn](https://linkedin.com/in/aanyajha) | [GitHub](https://github.com/aanya1529)
