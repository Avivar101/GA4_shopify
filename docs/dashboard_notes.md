# Dashboard Notes

Dashboard: Shopify + GA4 Funnel Growth & Revenue Attribution

This dashboard was built in Looker Studio on top of the completed dbt marts. It is intended to show the full reporting path from GA4 behavior to Shopify-truth revenue attribution.

## Reporting Philosophy

Shopify is the source of truth for orders and revenue.

GA4 is used for:

- behavioral events
- sessions
- ecommerce funnel steps
- purchase-session source / medium / campaign attribution

Unattributed revenue is not removed. It is kept visible so total dashboard revenue can reconcile back to Shopify while also showing how much revenue lacks usable GA4 attribution.

## Page 1: Executive Overview

Main model:

- `fct__channel_revenue`

Purpose:

```text
Summarize revenue, orders, AOV, top attributed channels, and attribution coverage.
```

Core questions:

- How much Shopify revenue was generated?
- How many orders were recorded?
- What is the average order value?
- Which channels or campaigns are associated with revenue?
- How much revenue is attributed vs unattributed?

Recommended interpretation:

This page is the high-level business summary. Revenue values should be interpreted as Shopify-truth revenue. Attribution fields come from the matched GA4 purchase session when available.

## Page 2: Funnel Performance

Main model:

- `fct__funnel`

Purpose:

```text
Show session-based movement through product view, add to cart, checkout, and matched purchase behavior.
```

Core questions:

- How many sessions entered the funnel?
- How many sessions viewed products?
- How many sessions added to cart?
- How many sessions began checkout?
- How many sessions had matched Shopify purchases?
- Which source / medium / campaign groups have stronger funnel performance?

Important note:

The funnel is session-based, not customer-journey-based. A user can view a product in one session and purchase in another. Users can also enter mid-funnel. Because of this, step rates may exceed 100%, especially with small volumes or test/debug traffic.

## Page 3: Channel & Revenue Attribution

Main model:

- `fct__channel_revenue`

Purpose:

```text
Report Shopify-truth revenue by purchase-session attribution dimensions.
```

Core questions:

- Which source / medium combinations are associated with revenue?
- Which campaigns are associated with revenue?
- How much revenue is attributed?
- How much revenue remains unattributed?
- Which channels have stronger AOV?
- How complete is attribution coverage?

Recommended interpretation:

The page should not hide unattributed revenue. The unattributed bucket means Shopify revenue exists, but the project did not find a usable GA4 purchase-session match for channel attribution.

## Page 4: Reconciliation & Data Quality

Main model:

- `int_ga4_shopify__purchase_reconciliation`

Purpose:

```text
Audit how GA4 purchase events match Shopify orders.
```

Core questions:

- How many GA4 purchase events were captured?
- How many matched Shopify orders?
- How many were unmatched?
- Which transaction IDs were missing or invalid?
- Do GA4 and Shopify revenue values differ?
- Do GA4 and Shopify currencies match?

Confirmed match rule:

```text
GA4 transaction_id = cast(Shopify order_id as string)
```

This page supports trust in the attribution layer. If a purchase cannot be reconciled, it should not silently drive revenue attribution.

## Current Data Limitation

The current data is mostly setup, debug, and manual test activity. This means channel attribution does not yet look like a rich marketing dataset.

Observed examples include:

- `tagassistant`
- `admin.shopify`
- `referral`
- missing or unhelpful campaign values

This is expected for the current project. The dashboard should be interpreted as a validation of the pipeline and modeling structure, not as production marketing performance.

## Final Validation Checks

Before treating the dashboard as complete, check:

- `SUM(total_revenue)` in `fct__channel_revenue` ties to Shopify revenue in `fct__orders`.
- `SUM(attributed_revenue) + SUM(unattributed_revenue) = SUM(total_revenue)`.
- matched purchases plus unmatched purchases equals total GA4 purchase events.
- scorecard rates use ratios of sums, not averages of row-level rates.
- date controls use the intended date field for each page.
- dashboard notes clearly explain test/debug data limitations.

## Future Improvements

Good next-project improvements:

- UTM naming standards
- source / medium normalization
- internal/admin/test traffic exclusion
- test order tagging
- cleaner production acquisition data
- first-touch and last-touch attribution
- product-level attribution
- Dagster orchestration
