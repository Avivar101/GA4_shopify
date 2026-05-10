# Shopify + GA4: Full-Funnel Growth & Revenue Attribution Engine

This project combines Shopify commerce data with GA4 behavioral data to analyze the full customer journey:

```text
traffic -> behavior -> conversion -> revenue -> attribution
```

The goal is to build an analytics system that helps a merchant understand what users do before they buy, whether GA4 purchase tracking reconciles to Shopify order truth, and which channels/campaigns are associated with real Shopify revenue.

This is also a learning project. The focus is not only to produce dashboards, but to understand how raw ecommerce and behavioral data becomes trustworthy analytics. Profitability, CAC, and LTV are intentionally out of scope for this project and can be explored in a future project.

## Objective

The objective of this project is to build a system that allows end-users to analyze Shopify revenue, GA4 behavior, purchase reconciliation, full-funnel performance, and purchase-session attribution using Shopify and GA4 data.

## Core Objectives

Provide visibility into:

- Full-funnel user behavior from GA4.
- Shopify conversion and revenue performance.
- Gaps between GA4 purchase tracking and Shopify order reality.
- Revenue attribution by source, medium, and campaign.
- Dashboard-ready marts for Metabase.
- Scheduled ingestion and transformation through Dagster orchestration.

## Business Questions

The system should help answer:

- Which channels and campaigns bring users who actually convert?
- Where do users drop off before purchase?
- Which channels and campaigns are associated with Shopify revenue?
- Do GA4 purchase events match Shopify orders?
- How much revenue is attributed vs unattributed?
- Are the dbt marts reliable enough for a BI dashboard?

## Current Data Understanding

### GA4

GA4 BigQuery export stores behavioral data as daily event tables:

```text
analytics_XXXXXXXXX.events_YYYYMMDD
```

Each table represents one exported day of GA4 events.

Each row represents one event, such as:

- `page_view`
- `session_start`
- `view_item`
- `add_to_cart`
- `begin_checkout`
- `purchase`

Important GA4 fields include:

- `event_name`: the action that happened.
- `event_timestamp`: when the event happened.
- `event_date`: the exported event date.
- `user_pseudo_id`: GA4 anonymous user identifier.
- `event_params`: nested key-value parameters.
- `items`: nested ecommerce item data.

Important event parameters to extract during staging:

- `ga_session_id`
- `ga_session_number`
- `page_location`
- `page_title`
- `source`
- `medium`
- `campaign`
- `transaction_id`
- `value`
- `currency`

The early modeling goal is to turn GA4's nested event export into clean staging models for events, sessions, ecommerce actions, and purchases.

### Shopify

Shopify is the source of truth for commerce outcomes:

- Orders
- Customers
- Products
- Line items
- Discounts
- Refunds
- Revenue

Shopify data is ingested into BigQuery as raw append-only records, with incremental progress tracked by a `pipeline_state` table.

## Functional Requirements

### Data Ingestion

Ingest data from:

- Shopify Admin API
  - Orders
  - Products
  - Customers
  - Future project ideas: refunds, transactions, fulfillments, inventory, product costs
- GA4 BigQuery export
  - Daily event tables
  - Event parameters
  - Ecommerce events
  - Item arrays

### Data Modeling

Recommended layers:

- `raw`: unmodified source data.
- `staging`: cleaned, typed, source-specific models.
- `intermediate`: joins and business logic.
- `marts`: analytics-ready tables for dashboards and app views.

Suggested models:

- `stg_ga4__events`
- `stg_ga4__event_params`
- `stg_ga4__sessions`
- `stg_ga4__items`
- `stg_ga4__purchases`
- `stg_shopify__orders`
- `stg_shopify__order_lines`
- `stg_shopify__customers`
- `stg_shopify__products`
- `int_order_attribution`
- `int_ga4_shopify__purchase_reconciliation`
- `int_ga4_shopify__order_attribution`
- `fct__funnel`
- `fct__orders`
- `fct__order_lines`
- `fct__attributed_orders`
- `fct__channel_revenue`

### Data Processing

Processing should handle:

- GA4 daily sharded tables.
- Nested GA4 event parameters.
- Nested GA4 item arrays.
- Shopify raw JSON payload parsing.
- Deduplication.
- Incremental updates.
- Late-arriving GA4 data.
- Refunds and cancellations.
- Identity matching between GA4 users, sessions, and Shopify orders.

### Analytics

The analytics layer should support:

- Full-funnel analysis.
- Conversion rate analysis.
- Revenue reporting.
- Product performance.
- Campaign attribution.
- GA4 vs Shopify purchase reconciliation.
- Attribution coverage reporting.

### Metabase Dashboards

The analytics experience for this project will be delivered through Metabase dashboards on top of dbt marts.

Dashboard views should include:

- Funnel dashboard.
- Revenue dashboard.
- Attribution dashboard.
- Channel revenue dashboard.
- GA4 vs Shopify reconciliation dashboard.
- Data freshness and pipeline status.

### Dagster Orchestration

Pipelines should be scheduled and monitored with Dagster.

Recommended orchestration responsibilities:

- Run Shopify ingestion.
- Validate GA4 export freshness.
- Run dbt staging models.
- Run dbt intermediate models and marts.
- Run dbt tests.
- Track pipeline state.
- Log row counts and failures.
- Alert on missing or stale data.

## Non-Functional Requirements

### Performance

- Use incremental processing where possible.
- Partition large BigQuery tables by date.
- Cluster large tables by common filters such as `event_name`, `user_pseudo_id`, `order_id`, or `customer_id`.
- Avoid running dashboards directly on raw nested GA4 tables.
- Build marts for repeated reporting queries.

### Data Consistency

- Treat Shopify as the source of truth for orders and revenue.
- Treat GA4 as the source of truth for behavioral events.
- Reconcile GA4 purchases with Shopify orders.
- Use deterministic keys for deduplication.
- Keep raw payloads for auditability.

### Reliability

- Make ingestion idempotent where possible.
- Track incremental checkpoints.
- Log pipeline row counts and checkpoints.
- Add retries for transient API failures.
- Monitor data freshness.
- Protect credentials with environment variables.

## Current Project Structure

```text
.
|-- ingestion/
|   |-- ingest_data.py              # Shopify -> BigQuery raw ingestion
|   |-- run_shopify_ingestion.py    # Entrypoint for Shopify ingestion
|   |-- shopify_client.py           # Shopify API client helpers
|   `-- test.py                     # API exploration script
|-- shopify_ga4/
|   |-- dbt_project.yml
|   |-- profiles.yml
|   |-- packages.yml
|   `-- models/
|       |-- staging/
|       |-- intermediate/
|       `-- marts/
|-- main.py
|-- pyproject.toml
|-- uv.lock
`-- README.md
```

## Current Shopify Ingestion Flow

1. Load environment variables.
2. Create or reuse the configured BigQuery dataset.
3. Create or reuse raw Shopify tables.
4. Read the last processed `updated_at` checkpoint from `pipeline_state`.
5. Fetch Shopify records using `updated_at_min`.
6. Skip records at or before the previous checkpoint.
7. Append raw records to BigQuery.
8. Update `pipeline_state` with the maximum processed `updated_at`.

## Environment Variables

Create a local `.env` file with the required configuration.

```env
SHOPIFY_STORE_URL=your-store.myshopify.com
SHOPIFY_API_VERSION=2025-01
SHOPIFY_CLIENT_ID=your_client_id
SHOPIFY_CLIENT_SECRET=your_client_secret

GCP_PROJECT_ID=your-gcp-project-id
BQ_DATASET=shopify_raw
```

Do not commit `.env`.

## Running Shopify Ingestion

Using the project virtual environment:

```powershell
.\.venv\Scripts\python.exe ingestion\run_shopify_ingestion.py
```

The ingestion currently loads:

- Orders into `raw_shopify_orders`
- Products into `raw_shopify_products`
- Customers into `raw_shopify_customers`

## Learning Roadmap

### Step 1: Profile Raw GA4 Data

Understand what events and parameters exist before modeling.

Questions to answer:

- Which event names exist?
- Which events are ecommerce-related?
- Which parameters exist on each event?
- Is `transaction_id` populated on purchase events?
- Does GA4 `transaction_id` match Shopify order data?

### Step 2: Build GA4 Staging Models

Start simple:

1. `stg_ga4__events`: one row per event.
2. `stg_ga4__event_params`: one row per event parameter.
3. `stg_ga4__sessions`: one row per user session.
4. `stg_ga4__items`: one row per ecommerce item event.
5. `stg_ga4__purchases`: one row per GA4 purchase event.

### Step 3: Build Shopify Staging Models

Create clean Shopify models:

1. `stg_shopify__orders`
2. `stg_shopify__order_lines`
3. `stg_shopify__customers`
4. `stg_shopify__products`

### Step 4: Reconcile GA4 Purchases With Shopify Orders

Compare:

- GA4 purchase count vs Shopify order count.
- GA4 purchase revenue vs Shopify order revenue.
- GA4 `transaction_id` vs Shopify order identifiers.

This step is important before attribution and dashboard reporting.

### Step 5: Build Full-Funnel Model

Create a model that counts users and sessions through the funnel:

```text
session_start -> view_item -> add_to_cart -> begin_checkout -> purchase
```

Key metrics:

- Sessions
- Product views
- Add to carts
- Checkouts
- Purchases
- Conversion rate
- Revenue per session

### Step 6: Build Revenue Marts

Create Shopify-truth order and line-item facts:

- `fct__orders`: one row per Shopify order.
- `fct__order_lines`: one row per Shopify order line item.

### Step 7: Build Attribution Models

Attach GA4 purchase-session context to Shopify orders:

- `int_ga4_shopify__order_attribution`: one row per Shopify order.
- `fct__attributed_orders`: reporting-ready attributed order fact.
- `fct__channel_revenue`: daily revenue by attributed source, medium, and campaign.

### Step 8: Build Metabase Dashboards

Create dashboards for the completed marts:

- Funnel performance.
- Revenue performance.
- Channel attribution.
- Attribution coverage.
- Reconciliation quality.

### Step 9: Add Dagster Orchestration

Use Dagster to orchestrate:

- Shopify ingestion.
- dbt model runs.
- dbt tests.
- freshness checks.
- basic monitoring/logging.

## Suggested Analytics Marts

### Full-Funnel Mart

Tracks user movement from session to purchase.

Key metrics:

- Sessions
- Product views
- Add to carts
- Checkouts
- Purchases
- Conversion rate
- Revenue per session

### Revenue Mart

Tracks Shopify order and line-item revenue.

Key metrics:

- Orders
- Order lines
- Gross line sales
- Discounts
- Taxes
- Total revenue

### Attribution Mart

Tracks Shopify revenue with GA4 purchase-session attribution.

Key metrics:

- Attributed orders
- Unattributed orders
- Attributed revenue
- Unattributed revenue
- Attribution coverage rate
- Revenue by source / medium / campaign

### Out of Scope for This Project

The following are intentionally skipped here and reserved for a future project:

- Profitability inputs
- Profitability marts
- Customer LTV
- CAC vs LTV
- Embedded Shopify app

## Notes

The project should move in small, understandable steps. First understand the raw GA4 event structure, then build staging models, then reconcile GA4 purchases to Shopify orders, then build revenue and attribution marts, then expose the marts through Metabase and orchestrate the pipeline with Dagster.
