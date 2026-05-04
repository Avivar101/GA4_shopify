# Project Milestones and TODO

Project: Shopify + GA4: Full-Funnel Growth & Profitability Engine

This file tracks what has been achieved and what to work on next. The goal is to keep the project moving in small, understandable steps.

## Achieved So Far

### 1. Project Direction Clarified

- Reframed the project as a full-funnel growth and profitability analytics system.
- Defined the main analytics path:

```text
traffic -> behavior -> conversion -> revenue -> profit -> lifetime value
```

- Clarified the core business goal: understand user behavior, conversion, revenue, profitability, CAC, and LTV.

### 2. Shopify Ingestion Built

- Built Shopify API ingestion into BigQuery.
- Ingested raw Shopify data for:
  - Orders
  - Products
  - Customers
- Added incremental loading using Shopify `updated_at`.
- Added `pipeline_state` logic to avoid repeatedly ingesting the same records.
- Kept raw Shopify payloads for auditability.

### 3. GA4 Raw Data Understood

- Confirmed GA4 exports data as daily event tables.
- Learned that each GA4 row represents one event.
- Identified important GA4 fields:
  - `event_name`
  - `event_timestamp`
  - `event_date`
  - `user_pseudo_id`
  - `event_params`
  - `items`
- Started extracting important event parameters:
  - `ga_session_id`
  - `ga_session_number`
  - `page_location`
  - `source`
  - `medium`
  - `campaign`

### 4. dbt Project Started

- Created a dbt project under `shopify_ga4`.
- Defined Shopify and GA4 sources.
- Added staging model folders for:
  - GA4
  - Shopify
- Added dbt documentation files for staging models.

### 5. GA4 Staging Models Built

- Built `stg_ga4__events`.
- Built `stg_ga4__sessions`.
- Built `stg_ga4__purchases`.
- Added schema documentation and tests for GA4 staging.
- Added a custom test for missing GA4 purchase transaction IDs.

### 6. Shopify Staging Models Built

- Built `stg_shopify__orders`.
- Built `stg_shopify__order_line_items`.
- Built `stg_shopify__customers`.
- Built `stg_shopify__products`.
- Built `stg_shopify__product_variants`.
- Added schema documentation and tests for Shopify staging.
- Added custom tests for:
  - Non-negative order totals
  - Positive order line quantities

### 7. Data Modeling Lessons Learned

- Learned the difference between `JSON_VALUE` and `JSON_QUERY`.
- Fixed Shopify JSON parsing issues in staging models.
- Learned that Shopify customer PII fields may require protected customer data approval.
- Confirmed that `customer_id` is enough to start LTV modeling.

## Current Validation Status

- Shopify staging models build successfully.
- Shopify staging tests pass.
- GA4 staging models build successfully.
- GA4 staging tests mostly pass, with useful warnings to investigate.

Known GA4 learning signals:

- Some GA4 event keys may not be perfectly unique.
- Some GA4 purchase events may have missing purchase revenue.

## Next Milestone: Reconciliation

The next major milestone is to compare GA4 purchases against Shopify orders.

Goal:

```text
Do GA4 purchase events match real Shopify orders?
```

Why this matters:

- Shopify is the source of truth for orders and revenue.
- GA4 is the source of truth for behavior and attribution.
- Before building funnel, CAC, or LTV analysis, the purchase bridge must be trusted.

### TODO: Build Reconciliation Model

Create an intermediate model:

```text
shopify_ga4/models/intermediate/int_ga4_shopify__purchase_reconciliation.sql
```

Compare:

- GA4 `transaction_id`
- Shopify `order_id`
- Shopify `order_number`
- Shopify `order_name`
- GA4 purchase revenue
- Shopify total price
- purchase timestamps

Questions to answer:

- Does GA4 `transaction_id` match Shopify `order_id`?
- Does it match Shopify `order_number`?
- Does it match Shopify `order_name`?
- Are any GA4 purchases missing in Shopify?
- Are any Shopify orders missing in GA4?
- How different are GA4 purchase revenue and Shopify total price?

## Upcoming Milestones

### Milestone 1: Purchase Reconciliation

- Build GA4 vs Shopify purchase reconciliation.
- Identify the correct transaction join key.
- Add reconciliation tests.
- Document known tracking gaps.

### Milestone 2: Full-Funnel Mart

- Build a funnel model from GA4 sessions/events.
- Track:
  - sessions
  - product views
  - add to carts
  - checkouts
  - purchases
  - conversion rate
  - revenue per session

### Milestone 3: Revenue Mart

- Build order and line-item revenue facts from Shopify.
- Track:
  - gross sales
  - discounts
  - taxes
  - total revenue
  - line item revenue

### Milestone 4: Profitability Inputs

- Add or ingest cost data.
- Decide how to represent:
  - product cost
  - shipping cost
  - transaction fees
  - refunds
  - discounts

### Milestone 5: Profitability Mart

- Calculate order-level profit.
- Calculate product-level profit.
- Calculate customer-level profit.
- Calculate channel/campaign profitability once attribution is available.

### Milestone 6: CAC vs LTV

- Add acquisition cost data.
- Build customer LTV.
- Compare CAC to:
  - first order value
  - lifetime revenue
  - lifetime gross profit
- Calculate LTV:CAC ratio and payback period.

### Milestone 7: Embedded Shopify App

- Design merchant-facing dashboard views.
- Start with:
  - funnel overview
  - revenue overview
  - profitability overview
  - CAC vs LTV overview
  - data freshness status

## Guiding Principle

Move in this order:

```text
understand raw data -> stage clean data -> reconcile truth -> build marts -> dashboard
```

Do not rush into dashboards before the staging and reconciliation layers are trustworthy.
