# GA4 + Shopify Analytics System

This project is an analytics system for combining Shopify commerce data with GA4 user behavior data. The business goal is to provide visibility across the full customer journey:

```text
user behavior -> conversion -> revenue -> profitability
```

The system is intended to help merchants understand which users, channels, campaigns, products, and journeys drive revenue and profit.

## Objectives

- Track user behavior from GA4 events and sessions.
- Connect behavioral data to Shopify conversions and orders.
- Model revenue, refunds, discounts, product costs, and profitability.
- Provide analytics-ready tables for reporting and decision making.
- Embed analytics inside a Shopify app experience.
- Orchestrate ingestion and processing reliably.

## Business Requirements

The system should answer questions such as:

- Which channels and campaigns drive the most revenue?
- Which user journeys lead to conversion?
- Which products generate the best gross margin?
- Where do users drop off before purchase?
- How do Shopify revenue numbers compare with GA4 purchase events?
- Which customers, products, and cohorts are most profitable?

## Functional Requirements

### Data Ingestion

Ingest data from:

- Shopify Admin API
  - Orders
  - Products
  - Customers
  - Future: refunds, fulfillments, inventory, transactions, cost data
- GA4 BigQuery export or GA4 Data API
  - Events
  - Sessions
  - Traffic source data
  - Purchase events

Current Shopify ingestion loads raw records into BigQuery append-only tables and tracks incremental progress with a `pipeline_state` table.

### Data Modeling

Create modeled tables for analytics, such as:

- `dim_customers`
- `dim_products`
- `fact_orders`
- `fact_order_lines`
- `fact_ga4_events`
- `fact_sessions`
- `fact_attribution`
- `fact_profitability`

Recommended modeling layers:

- `raw`: unmodified API payloads
- `staging`: cleaned and typed source-specific tables
- `mart`: business-ready reporting tables

### Data Processing

Transform raw Shopify and GA4 data into consistent analytics tables.

Processing should handle:

- Deduplication
- Incremental updates
- Late-arriving data
- Refund and cancellation adjustments
- Currency normalization
- Order and line-item flattening
- Identity stitching between GA4 users and Shopify customers/orders

### Analytics

The analytics layer should support:

- Funnel analysis
- Conversion rate analysis
- Revenue reporting
- Campaign attribution
- Product performance
- Customer cohort analysis
- Profitability and margin reporting
- GA4 vs Shopify reconciliation

### Shopify App Embedding

The analytics experience should eventually be embedded into a Shopify app.

The embedded app should provide:

- Merchant-facing dashboards
- Filters by date, channel, campaign, product, and customer cohort
- Revenue and profitability summaries
- Conversion and funnel views
- Data freshness/status indicators

### Orchestration

Pipelines should be scheduled and monitored.

Recommended orchestration responsibilities:

- Run Shopify ingestion
- Run GA4 ingestion or sync validation
- Run transformation jobs
- Update reporting tables
- Track pipeline state
- Alert on failures
- Monitor data freshness

## Non-Functional Requirements

### Performance

- Use incremental ingestion where possible.
- Partition large BigQuery tables by event/order date.
- Cluster high-volume tables by common filter keys such as `shop_domain`, `customer_id`, `order_id`, or `event_name`.
- Avoid scanning raw JSON tables directly for dashboards.
- Build reporting marts for repeated dashboard queries.

### Data Consistency

- Maintain one source of truth for Shopify orders and revenue.
- Reconcile GA4 purchase events against Shopify orders.
- Use deterministic keys for deduplication.
- Track pipeline checkpoints in BigQuery.
- Keep raw source payloads for auditability.

### Reliability

- Make ingestion jobs idempotent where possible.
- Log pipeline start/end times, row counts, and checkpoints.
- Fail loudly on API or BigQuery errors.
- Add retries for transient API failures.
- Monitor pipeline freshness and missing data.
- Protect secrets with environment variables and never commit `.env`.

## Current Project Structure

```text
.
|-- ingestion/
|   |-- ingest_data.py              # Shopify -> BigQuery raw ingestion
|   |-- run_shopify_ingestion.py    # Entrypoint for Shopify ingestion
|   |-- shopify_client.py           # Shopify API client helpers
|   `-- test.py                     # GraphQL/API exploration script
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

## Recommended Next Steps

Before moving further into dashboards or the Shopify embedded app, prioritize these foundations:

1. Add source-specific raw table constraints and deduplication strategy.
2. Create staging models for Shopify orders, order lines, products, and customers.
3. Create GA4 staging models for events, sessions, users, and purchases.
4. Build a reconciliation table comparing Shopify orders to GA4 purchases.
5. Define attribution rules for connecting sessions/campaigns to orders.
6. Add profitability inputs such as product cost, shipping cost, discounts, refunds, and transaction fees.
7. Add orchestration with scheduled runs, logging, retries, and freshness checks.
8. Add tests for timestamp parsing, checkpoint behavior, deduplication, and model logic.

## Suggested Analytics Marts

### Revenue Mart

Tracks order-level and line-item revenue.

Key metrics:

- Gross sales
- Discounts
- Net sales
- Taxes
- Shipping
- Refunds
- Total revenue

### Conversion Mart

Connects GA4 user/session behavior to Shopify purchases.

Key metrics:

- Sessions
- Product views
- Add to carts
- Checkouts
- Purchases
- Conversion rate
- Revenue per session

### Profitability Mart

Tracks profit by order, product, customer, and channel.

Key metrics:

- Net revenue
- Product cost
- Shipping cost
- Payment fees
- Refunds
- Gross profit
- Gross margin

## Notes

This project is currently in the early ingestion and modeling stage. The most important design choice is to keep raw source data immutable, then build clean staging and business marts on top. That gives the system auditability while keeping dashboards fast and consistent.
