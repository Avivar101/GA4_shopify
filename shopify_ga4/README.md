# Shopify GA4 dbt Project

This dbt project transforms raw Shopify and GA4 data into clean staging, reconciliation, funnel, revenue, and attribution models.

The wider project goal is:

```text
traffic -> behavior -> conversion -> revenue -> attribution
```

This dbt layer is where raw source data becomes documented, tested, analytics-ready data for the Looker Studio dashboard. Profitability, CAC, and LTV are intentionally out of scope for this project.

## Project Structure

```text
shopify_ga4/
|-- dbt_project.yml
|-- profiles.yml
|-- packages.yml
|-- models/
|   |-- staging/
|       |-- __sources.yml
|       |-- ga4/
|       |   |-- _ga4__models.yml
|       |   |-- stg_ga4__events.sql
|       |   |-- stg_ga4__items.sql
|       |   |-- stg_ga4__sessions.sql
|       |   `-- stg_ga4__purchases.sql
|       `-- shopify/
|           |-- _shopify__models.yml
|           |-- stg_shopify__orders.sql
|           |-- stg_shopify__order_line_items.sql
|           |-- stg_shopify__customers.sql
|           |-- stg_shopify__products.sql
|           `-- stg_shopify__product_variants.sql
|   |-- intermediate/
|   |   |-- _intermediate__models.yml
|   |   |-- int_ga4_shopify__purchase_reconciliation.sql
|   |   `-- int_ga4_shopify__order_attribution.sql
|   `-- marts/
|       |-- fct__orders.sql
|       |-- fct__order_lines.sql
|       `-- growth/
|           |-- _growth__models.yml
|           |-- fct__funnel.sql
|           |-- fct__attributed_orders.sql
|           `-- fct__channel_revenue.sql
|-- analyses/
|   |-- ga4_profile_events.sql
|   `-- fct_orders_profile.sql
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
- `items`
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

#### `stg_ga4__items`

One row per item inside a GA4 ecommerce event.

This model unnests the GA4 `items` array and keeps item-level values such as:

- `event_key`
- `event_name`
- `transaction_id`
- `item_index`
- `item_id`
- `item_name`
- `item_brand`
- `item_variant`
- `item_category`
- `price`
- `quantity`
- `item_revenue`

Use this model for product-level funnel analysis, such as products viewed, added to cart, checked out, and purchased.

Do not use this model as the first purchase-to-order reconciliation grain, because one purchase can contain multiple items.

## Reconciliation Grain

The first GA4-to-Shopify reconciliation should compare:

```text
stg_ga4__purchases -> stg_shopify__orders
```

This is purchase-to-order grain.

Use `stg_ga4__items` later for product-level reconciliation against Shopify order line items:

```text
stg_ga4__items -> stg_shopify__order_line_items
```

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

This model is the foundation for product revenue analysis.

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

## Intermediate Models

### `int_ga4_shopify__purchase_reconciliation`

Grain: one row per GA4 purchase event.

This model compares GA4 purchase events to Shopify orders. The current confirmed match rule is:

```text
GA4 transaction_id = Shopify order_id
```

It keeps matched and unmatched GA4 purchases so tracking gaps stay visible.

### `int_ga4_shopify__order_attribution`

Grain: one row per Shopify order.

This model preserves all Shopify orders and attaches one deduped matched GA4 purchase-session attribution record when available.

Current attribution rule:

```text
Attribute each Shopify order to the source / medium / campaign of the matched GA4 purchase session.
```

Unmatched Shopify orders are kept as unattributed rather than filtered out.

## Mart Models

### `fct__orders`

Grain: one row per Shopify order.

Shopify-truth order revenue fact table used for revenue reporting.

### `fct__order_lines`

Grain: one row per Shopify order line item.

Shopify-truth line-item revenue fact table used for product and item-level revenue analysis.

### `fct__funnel`

Grain: one row per event date, source, medium, and campaign.

Session-based GA4 funnel mart with matched Shopify revenue from reconciliation.

### `fct__attributed_orders`

Grain: one row per Shopify order.

Reporting-ready order fact table with Shopify revenue truth and purchase-session attribution fields.

### `fct__channel_revenue`

Grain: one row per revenue date, currency, attributed source, attributed medium, and attributed campaign.

Aggregated channel revenue mart for Looker Studio dashboard reporting. Revenue remains Shopify-truth; GA4 provides attribution dimensions.

## Tests

Model and column tests are defined in:

```text
models/staging/ga4/_ga4__models.yml
models/staging/shopify/_shopify__models.yml
models/intermediate/_intermediate__models.yml
models/marts/growth/_growth__models.yml
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

Build the completed attribution chain:

```powershell
dbt run --select int_ga4_shopify__order_attribution+
```

Test the attribution and channel revenue models:

```powershell
dbt test --select int_ga4_shopify__order_attribution fct__attributed_orders fct__channel_revenue
```

Generate a dbt Fusion catalog:

```powershell
dbt compile --write-catalog
```

Note: dbt Fusion does not support `dbt docs generate`. Use `dbt compile --write-catalog` to create `catalog.json`.

## Current Validation Status

Latest known validation:

- GA4 staging models build successfully.
- Shopify staging models build successfully.
- Shopify staging tests pass.
- GA4 staging tests pass with known warnings for learning/data-quality investigation.
- Purchase reconciliation model builds successfully.
- Funnel, revenue, and attribution marts build successfully.
- Focused attribution tests pass.
- Looker Studio dashboard has been built on top of the marts.

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

The project can support customer-level analysis with `customer_id`, orders, and revenue history. Email and name are not required for the current revenue-attribution scope.

Request protected Shopify customer data only when there is a clear need for personally identifiable fields such as email, name, phone, or address.

## Dashboard Models

The Looker Studio dashboard uses these completed models:

- `fct__channel_revenue` for executive revenue and channel attribution pages.
- `fct__funnel` for session-based funnel performance.
- `int_ga4_shopify__purchase_reconciliation` for reconciliation and data-quality reporting.
- `fct__attributed_orders` as the order-level drilldown behind attributed revenue.

## Next Steps

This dbt scope is complete for the current learning project. Good follow-up work for a future project:

1. Add Dagster orchestration for Shopify ingestion, dbt runs, tests, and freshness checks.
2. Improve acquisition data quality with UTM standards and internal/test traffic exclusion.
3. Explore first-touch and last-touch attribution.
4. Add product-level ecommerce analysis.
5. Keep profitability, CAC, and LTV as future-project ideas rather than current project TODOs.
