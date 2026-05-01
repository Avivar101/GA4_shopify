import json
import os
from datetime import datetime, timezone
from typing import Optional

from dotenv import load_dotenv
from google.api_core.exceptions import NotFound
from google.cloud import bigquery

from shopify_client import get_paginated, get_token

load_dotenv()

SHOP_DOMAIN = os.getenv("SHOPIFY_STORE_URL")
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET = os.getenv("BQ_DATASET", "shopify_raw")

batch_no = int(datetime.now(timezone.utc).timestamp())

"""Initialize and return a BigQuery client using the configured project ID.

Raises:
    ValueError: If GCP_PROJECT_ID is not set.
"""
def get_bq_client() -> bigquery.Client:
    if not GCP_PROJECT_ID:
        raise ValueError("GCP_PROJECT_ID environment variable is not set")
    return bigquery.Client(project=GCP_PROJECT_ID)

"""Ensure the target BigQuery dataset exists; create it if missing.

Creates the dataset in the configured location if it does not already exist.
"""
def ensure_dataset(client: bigquery.Client) -> None:
    dataset_id = f"{client.project}.{BQ_DATASET}"
    try:
        client.get_dataset(dataset_id)
    except NotFound:
        dataset = bigquery.Dataset(dataset_id)
        dataset.location = "US"
        client.create_dataset(dataset)

"""Ensure the pipeline_state table exists in BigQuery.

This table stores incremental ingestion checkpoints (last_updated_at per source).
"""
def ensure_pipeline_state_table(client: bigquery.Client) -> None:
    table_id = f"{client.project}.{BQ_DATASET}.pipeline_state"
    schema = [
        bigquery.SchemaField("source", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("last_updated_at", "TIMESTAMP", mode="NULLABLE"),
    ]

    try:
        client.get_table(table_id)
    except NotFound:
        table = bigquery.Table(table_id, schema=schema)
        client.create_table(table)

"""Ensure the raw ingestion table for a given source exists.

Creates an append-only table with JSON payload storage and ingestion metadata.
"""
def ensure_raw_table(client: bigquery.Client, source: str, table_name: str) -> None:
    table_id = f"{client.project}.{BQ_DATASET}.{table_name}"
    schema = [
        bigquery.SchemaField("shop_domain", "STRING", mode="NULLABLE"),
        bigquery.SchemaField(f"{source}_id", "INT64", mode="NULLABLE"),
        bigquery.SchemaField("updated_at", "TIMESTAMP", mode="NULLABLE"),
        bigquery.SchemaField("ingested_at", "TIMESTAMP", mode="NULLABLE"),
        bigquery.SchemaField("payload_json", "STRING", mode="NULLABLE"),
        bigquery.SchemaField("batch_no", "INT64", mode="NULLABLE"),
    ]

    try:
        client.get_table(table_id)
    except NotFound:
        table = bigquery.Table(table_id, schema=schema)
        client.create_table(table)

"""Fetch the last processed updated_at timestamp for a source.

Returns:
    datetime | None: Last checkpoint timestamp used for incremental ingestion.
"""
def get_last_updated_at(
        client: bigquery.Client,
        source: str,
) -> Optional[datetime]:
    query = f"""
        SELECT last_updated_at
        FROM `{client.project}.{BQ_DATASET}.pipeline_state`
        WHERE source = @source
        LIMIT 1
    """

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("source", "STRING", source),
        ],
    )
    rows = list(client.query(query, job_config=job_config).result())
    if not rows:
        print(f"No pipeline checkpoint found for source={source}")
        return None

    last_updated_at = rows[0]["last_updated_at"]
    print(f"Found pipeline checkpoint for source={source}: {last_updated_at}")
    return last_updated_at

"""Upsert the latest processed timestamp for a source into pipeline_state.

Uses a MERGE statement to insert or update the checkpoint atomically.
"""
def update_pipeline_state(
        client: bigquery.Client,
        source: str,
        last_updated_at,
) -> None:
    query = f"""
        MERGE `{client.project}.{BQ_DATASET}.pipeline_state` AS target
        USING (
            SELECT
                @source AS source,
                @last_updated_at AS last_updated_at
        ) AS src
        ON target.source = src.source
        WHEN MATCHED THEN
          UPDATE SET last_updated_at = src.last_updated_at
        WHEN NOT MATCHED THEN
          INSERT (source, last_updated_at)
          VALUES (src.source, src.last_updated_at)
    """

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("source", "STRING", source),
            bigquery.ScalarQueryParameter("last_updated_at", "TIMESTAMP", last_updated_at),
        ],
    )
    client.query(query, job_config=job_config).result()
    print(f"Updated pipeline checkpoint for source={source}: {last_updated_at}")


def format_shopify_timestamp(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_shopify_timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)

"""Ingest Shopify resource data into BigQuery using incremental loading.

Fetches paginated API data, appends records to a raw table, and updates the
pipeline_state checkpoint using the max updated_at observed in the batch.
"""
def ingest_shopify_data(source: str, table_name: str) -> None:
    print(f"Pulling {source}s...")

    client = get_bq_client()

    ensure_dataset(client)
    ensure_pipeline_state_table(client)
    ensure_raw_table(client, source, table_name)

    last_updated_at = get_last_updated_at(client, source)

    params = {
        "limit": 250,
    }
    if last_updated_at:
        params["updated_at_min"] = format_shopify_timestamp(last_updated_at)
        print(f"Fetching {source}s updated since {params['updated_at_min']}")

    token = get_token()

    data = get_paginated(f"{source}s.json", params=params, access_token=token)

    print(f"Fetched {len(data)} {source}s")

    max_updated_at_in_batch = None
    now = datetime.now(timezone.utc)
    last_updated_at_utc = (
        last_updated_at.astimezone(timezone.utc)
        if last_updated_at
        else None
    )

    rows_to_insert = []

    for item in data:
        item_updated_at = item.get("updated_at")
        item_updated_at_dt = (
            parse_shopify_timestamp(item_updated_at)
            if item_updated_at
            else None
        )

        if (
            last_updated_at_utc
            and item_updated_at_dt
            and item_updated_at_dt <= last_updated_at_utc
        ):
            continue

        rows_to_insert.append({
            "shop_domain": SHOP_DOMAIN,
            f"{source}_id": item.get("id"),
            "updated_at": item_updated_at,
            "ingested_at": now.isoformat(),
            "payload_json": json.dumps(item),
            "batch_no": batch_no
        })
    
        if item_updated_at_dt:
            if (
                max_updated_at_in_batch is None
                or item_updated_at_dt > max_updated_at_in_batch
            ):
                max_updated_at_in_batch = item_updated_at_dt
    
    if rows_to_insert:
        table_id = f"{client.project}.{BQ_DATASET}.{table_name}"
        job_config = bigquery.LoadJobConfig(
            write_disposition="WRITE_APPEND",
        )
        load_job = client.load_table_from_json(rows_to_insert, table_id, job_config=job_config)
        load_job.result()

    if max_updated_at_in_batch is not None:
        update_pipeline_state(client, source, max_updated_at_in_batch)
    elif rows_to_insert:
        print(f"No updated_at values found for {source}s; pipeline checkpoint was not changed")

    print(f"Ingested {len(rows_to_insert)} rows into {table_name} table")
