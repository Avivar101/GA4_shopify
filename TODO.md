# Project Milestones and TODO

Project: Shopify + GA4: Full-Funnel Growth & Revenue Attribution Engine

This file tracks what has been achieved and what remains before closing this learning project. The core ingestion, modeling, attribution, and dashboard work is complete.

## Achieved So Far

### 1. Project Direction Clarified

- Reframed the project as a full-funnel growth and revenue attribution analytics system.
- Defined the main analytics path:

```text
traffic -> behavior -> conversion -> revenue -> attribution
```

- Clarified the core business goal: understand user behavior, conversion, Shopify revenue truth, purchase reconciliation, and channel attribution.

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
- Confirmed that `customer_id` is enough for future customer-level modeling without needing protected customer PII.

### 8. Purchase Reconciliation Built

- Built `int_ga4_shopify__purchase_reconciliation`.
- Confirmed the primary match rule:

```text
GA4 transaction_id = Shopify order_id
```

- Preserved GA4 purchase events as the reconciliation grain.
- Classified matched and unmatched GA4 purchases.
- Identified useful tracking-quality gaps:
  - missing transaction IDs
  - `not_set` transaction IDs
  - possible revenue differences between GA4 and Shopify

### 9. Full-Funnel Mart Built

- Built `fct__funnel`.
- Grain:

```text
event_date + source + medium + campaign
```

- Modeled session-based funnel metrics from GA4 behavior.
- Joined matched Shopify order revenue through reconciliation.
- Added tests for grain, non-negative metrics, and rates.
- Kept step rates over 1 as a tracking-quality warning rather than a hard failure.

### 10. Revenue Mart Built

- Built `fct__orders`.
- Built `fct__order_lines`.
- Kept Shopify as the source of truth for order and line-item revenue.
- Used incremental logic for order and order-line facts.
- Added an analysis scratchpad for inspecting `fct__orders` without previewing inside incremental CTE logic.

### 11. Purchase-Session Attribution Built

- Built `int_ga4_shopify__order_attribution`.
- Built `fct__attributed_orders`.
- Built `fct__channel_revenue`.
- Current attribution rule:

```text
Attribute each Shopify order to the source / medium / campaign of the matched GA4 purchase session.
```

- Preserved all Shopify orders in attribution outputs.
- Kept unmatched orders in an `unattributed` bucket so revenue totals can still tie back to Shopify.
- Deduped matched GA4 purchases inside the attribution layer to preserve one row per Shopify order.
- Added docs and tests for attribution grain and channel revenue grain.

### 12. Looker Studio Dashboard Built

- Built a four-page dashboard on top of the completed dbt marts:
  - Executive Overview
  - Funnel Performance
  - Channel & Revenue Attribution
  - Reconciliation & Data Quality
- Added dashboard screenshots to the `assets/` folder.
- Added dashboard interpretation notes in `docs/dashboard_notes.md`.
- Documented the current test/debug data limitation so sparse channel attribution is explained clearly.

## Current Validation Status

- Shopify staging models build successfully.
- Shopify staging tests pass.
- GA4 staging models build successfully.
- GA4 staging tests mostly pass, with useful warnings to investigate.
- Purchase reconciliation model builds successfully.
- Funnel mart builds successfully.
- Revenue marts build successfully.
- Attribution models build successfully.
- Focused attribution tests pass:

```text
26 passed
```

Known GA4 learning signals:

- Some GA4 event keys may not be perfectly unique.
- Some GA4 purchase events may have missing purchase revenue.
- Some Shopify orders may be unattributed because GA4 purchase tracking is missing, duplicated, or has unusable transaction IDs.

## Final Milestone: Digest, Validate, and Close

The remaining milestone is not to add more modeling scope. This project has reached its intended learning boundary.

The focus now is to review what has been built, validate the model outputs, and document the lessons clearly before starting a new project.

Goal:

```text
raw data -> staging -> reconciliation -> funnel -> revenue -> attribution
```

Why this matters:

- The project already covers the core Shopify + GA4 analytics bridge.
- Adding profitability, CAC, or LTV now would increase scope before the current work is fully digested.
- The current project is strong enough to serve as a portfolio-quality foundation for a future, more advanced analytics project.

### TODO: Final Review

- [ ] Review each model and write down:
  - grain
  - source tables
  - business purpose
  - important assumptions
  - known data-quality signals

- [ ] Compare high-level totals:
  - Shopify staging orders vs `fct__orders`
  - `fct__orders` revenue vs `fct__attributed_orders` revenue
  - `fct__attributed_orders` revenue vs `fct__channel_revenue` revenue

- [ ] Review attribution coverage:
  - attributed orders
  - unattributed orders
  - attributed revenue
  - unattributed revenue
  - attribution coverage rates

- [x] Update README files with the final project scope and current model list.
- [x] Add dashboard screenshots to the repository.
- [x] Add dashboard notes and known limitations.
- [x] Keep profitability, CAC, and LTV as future-project ideas rather than TODOs for this repository.

Questions to answer:

- Can you explain why Shopify is the revenue source of truth?
- Can you explain why GA4 is used for behavior and attribution?
- Can you explain why reconciliation stays event-grain while attribution becomes order-grain?
- Can you explain why unattributed revenue is kept instead of filtered out?
- Can you explain the difference between purchase-session attribution and full customer journey attribution?

## Remaining Wrap-Up

- [ ] Run the main dbt build/test commands.
- [ ] Record remaining warnings and explain which are expected data-quality signals.
- [ ] Freeze the current scope.
- [ ] Note what would be done differently in a production version.
- [ ] List future project ideas separately from current project TODOs.

## Out of Scope for This Project

These are intentionally skipped for this project and can become part of a future project:

- Profitability inputs
- Profitability marts
- Attributed profitability
- Customer LTV
- CAC vs LTV
- Embedded Shopify app

## Completed Milestones

- Shopify ingestion
- GA4 raw data understanding
- dbt project setup
- Shopify staging
- GA4 staging
- Purchase reconciliation
- Full-funnel mart
- Revenue mart
- Purchase-session attribution
- Looker Studio dashboard
- Dashboard screenshots and notes

## Guiding Principle

Move in this order:

```text
understand raw data -> stage clean data -> reconcile truth -> build marts -> explain the model
```

Do not keep expanding scope before the current model layers are understood deeply enough to explain and defend.
