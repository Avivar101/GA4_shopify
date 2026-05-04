# Shopify GA4 dbt Project

This dbt project transforms raw Shopify and GA4 data into clean staging models for full-funnel growth, revenue, and profitability analysis.

The wider project goal is:

```text
traffic -> behavior -> conversion -> revenue -> profit -> lifetime value
```

This dbt layer is where raw source data becomes documented, tested, analytics-ready data.

## Project Structure

```text
shopify_ga4/
|-- dbt_project.yml
|-- profiles.yml
|-- packages.yml
|-- models/
|   `-- staging/
|       |-- __sources.yml
|       |-- ga4/
|       |   |-- _ga4__models.yml
|       |   |-- stg_ga4__events.sql
|       |   |-- stg_ga4__sessions.sql
|       |   `-- stg_ga4__purchases.sql
|       `-- shopify/
|           |-- _shopify__models.yml
|           |-- stg_shopify__orders.sql
|           |-- stg_shopify__order_line_items.sql
|           |-- stg_shopify__customers.sql
|           |-- stg_shopify__products.sql
|           `-- stg_shopify__product_variants.sql
|-- analyses/
|   `-- ga4_profile_events.sql
`-- tests/
    |-- ga4_purchases_have_transaction_id.sql
    |-- shopify_order_totals_are_non_negative.sql
    `-- shopify_order_line_quantities_are_positive.sql
```

## Sources

Sources are defined in:

```text
models/staging/__sources.yml
```

Current source groups:

- `shopify`: raw Shopify API data loaded into BigQuery.
- `ga4`: raw GA4 BigQuery export tables.

Shopify raw data is stored as append-only JSON payloads. GA4 data is stored as daily event export tables.

## Staging Models

### GA4

#### `stg_ga4__events`

One row per GA4 event.

This model extracts important fields from nested GA4 data:

- `event_key`
- `event_date`
- `event_timestamp`
- `event_name`
- `user_pseudo_id`
- `ga_session_id`
- `ga_session_number`
- `page_location`
- `page_title`
- `source`
- `medium`
- `campaign`
- `currency`
- `transaction_id`
- `purchase_revenue`
- `source_table_suffix`

This is the foundation for sessions, funnel analysis, and purchase reconciliation.

#### `stg_ga4__sessions`

One row per GA4 session, based on:

```text
user_pseudo_id + ga_session_id
```

This model summarizes funnel activity at the session level:

- event count
- page views
- product views
- add to carts
- checkouts
- purchases
- source / medium / campaign

#### `stg_ga4__purchases`

One row per GA4 purchase event.

This model is used to compare GA4 ecommerce tracking against Shopify orders.

Important fields:

- `event_key`
- `event_timestamp`
- `user_pseudo_id`
- `session_key`
- `transaction_id`
- `purchase_revenue`
- `currency`
- `source`
- `medium`
- `campaign`

### Shopify

#### `stg_shopify__orders`

One row per Shopify order.

This model deduplicates raw order payloads and extracts:

- order identifiers
- customer ID
- order timestamps
- financial status
- fulfillment status
- currency
- order totals

Shopify is treated as the source of truth for orders and revenue.

#### `stg_shopify__order_line_items`

One row per Shopify order line item.

This model unnests `line_items` from the raw Shopify order payload and extracts:

- order item ID
- product ID
- variant ID
- title
- SKU
- quantity
- unit price
- line discount
- line gross sales

This model is the foundation for product revenue and product profitability.

#### `stg_shopify__customers`

One row per Shopify customer available through the current API credentials.

At this stage, customer data is intentionally limited to non-sensitive fields such as:

- `customer_id`
- `created_at`
- `ingested_at`

Protected customer fields such as email, name, phone, and address require Shopify protected customer data approval.

#### `stg_shopify__products`

One row per Shopify product.

This model extracts:

- product ID
- title
- vendor
- product type
- status
- timestamps

#### `stg_shopify__product_variants`

One row per Shopify product variant.

This model unnests product variants and extracts:

- variant ID
- product ID
- variant title
- SKU
- price
- display position

## Tests

Model and column tests are defined in:

```text
models/staging/ga4/_ga4__models.yml
models/staging/shopify/_shopify__models.yml
```

Custom data tests are defined in:

```text
tests/
```

Current custom tests:

- `ga4_purchases_have_transaction_id`
- `shopify_order_totals_are_non_negative`
- `shopify_order_line_quantities_are_positive`

The goal of these tests is not only to catch errors, but to teach what assumptions the analytics layer depends on.

## Common Commands

Run from inside the `shopify_ga4` folder.

Parse project files:

```powershell
dbt parse
```

Build all staging models:

```powershell
dbt run --select path:models/staging
```

Build only GA4 staging:

```powershell
dbt run --select path:models/staging/ga4
```

Build only Shopify staging:

```powershell
dbt run --select path:models/staging/shopify
```

Run all staging tests:

```powershell
dbt test --select path:models/staging
```

Run only Shopify staging tests:

```powershell
dbt test --select path:models/staging/shopify
```

Run only GA4 staging tests:

```powershell
dbt test --select path:models/staging/ga4
```

Generate dbt documentation:

```powershell
dbt docs generate
```

Serve dbt documentation locally:

```powershell
dbt docs serve
```

## Current Validation Status

Latest known validation:

- GA4 staging models build successfully.
- Shopify staging models build successfully.
- Shopify staging tests pass.
- GA4 staging tests pass with known warnings for learning/data-quality investigation.

## Learning Notes

### `JSON_VALUE` vs `JSON_QUERY`

Use `JSON_VALUE` for scalar fields:

```sql
json_value(payload_json, '$.total_price')
json_value(payload_json, '$.created_at')
json_value(payload_json, '$.currency')
```

Use `JSON_QUERY_ARRAY` when extracting arrays:

```sql
json_query_array(payload_json, '$.line_items')
json_query_array(payload_json, '$.variants')
```

This distinction matters because staging models should convert raw JSON into typed, usable columns.

### Customer Data

The project can support LTV analysis with `customer_id`, orders, and revenue history. Email and name are not required for the first version of LTV.

Request protected Shopify customer data only when there is a clear need for personally identifiable fields such as email, name, phone, or address.

## Next Steps

Recommended next modeling steps:

1. Create a reconciliation model comparing GA4 purchases to Shopify orders.
2. Build a first full-funnel mart from GA4 sessions and purchases.
3. Build an order revenue mart from Shopify orders and line items.
4. Add profitability inputs such as product cost, shipping cost, refunds, and payment fees.
5. Build the first CAC vs LTV model once acquisition cost data is available.
