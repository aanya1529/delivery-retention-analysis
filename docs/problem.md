# Problem Statement: Does Late Delivery Reduce Repeat Purchase?

**Author:** Aanya Jha
**Date:** October 2026
**Dataset:** Olist Brazilian E-Commerce Public Dataset (Kaggle), ~100K orders, 2016–2018

## 1. Business context
Olist is a marketplace that connects small sellers to customers across Brazil.
For marketplaces, acquiring a customer is expensive, so repeat purchase is a
key driver of long-term growth. In this dataset, most customers place only one
order. This project examines whether delivery experience is one reason.

## 2. Question
Do customers whose orders arrive later than promised give lower review scores
and come back to buy again less often than customers whose orders arrive on
time or early?

## 3. Stakeholders
| Stakeholder | What they care about |
|---|---|
| Product team | Retention, customer experience, what to test next |
| Logistics / Operations | Delivery performance, which regions and sellers cause delays |
| Seller management | Which sellers and categories need intervention |

## 4. Hypotheses
- H1: Late deliveries are associated with lower review scores.
- H2: Late deliveries are associated with a lower 90-day repeat purchase rate.
- H3: The effect is stronger in some regions or categories.

## 5. Metrics
| Metric | Definition |
|---|---|
| Primary: 90-day repeat purchase rate | Share of customers who place a second order within 90 days of their first delivered order |
| Delivery delay (days) | Actual delivery date minus estimated delivery date (negative = early) |
| Delay bucket | Early, On time, 1–3 days late, 4+ days late |
| Review score | Average review score (1–5) per order |
| Guardrail (for the proposed A/B test) | Checkout conversion rate |

## 6. Scope and data rules
- Only delivered orders with a recorded delivery date are included.
- Customers are identified by `customer_unique_id` (not `customer_id`,
  which is generated per order).
- Only customers with at least 90 days of observation after their first
  order are included in repeat-rate calculations, to avoid bias from
  data cut-off.
- Out of scope: price elasticity, marketing channels, seller profitability.

## 7. Approach
1. Clean data and build an order-level base table in PostgreSQL.
2. Build monthly cohort retention.
3. Compare review score and 90-day repeat rate across delay buckets.
4. Segment by state, product category and order value.
5. Document limitations and design an A/B test for a delivery-promise change.

## 8. Decision this analysis informs
Whether the product team should test a change to the delivery promise shown at
checkout (for example, a more conservative estimate) or proactive delay
messaging, and which regions or categories to prioritize first.

## 9. Known limitations
- Observational data: late orders may differ from on-time orders in region,
  category or seller, so results show association, not proven causation.
- Data covers 2016–2018 and one Brazilian marketplace; findings may not
  generalize to other markets.
- Customers may buy from competitors, which this data cannot show.
