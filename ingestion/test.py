import os
import time

from dotenv import load_dotenv
import requests

load_dotenv()

SHOP = os.getenv("SHOPIFY_STORE_URL")
CLIENT_ID = os.getenv("SHOPIFY_CLIENT_ID")
CLIENT_SECRET = os.getenv("SHOPIFY_CLIENT_SECRET")

print(f"Loaded Shopify config: SHOP={SHOP}, CLIENT_ID={CLIENT_ID}, CLIENT_SECRET={'***' if CLIENT_SECRET else None}")

if not SHOP or not CLIENT_ID or not CLIENT_SECRET:
    raise RuntimeError("Set SHOPIFY_STORE_URL, SHOPIFY_CLIENT_ID, and SHOPIFY_CLIENT_SECRET.")

token = None
token_expires_at = 0.0


def get_token():
    print(f"Getting access token for shop: {SHOP}")
    global token, token_expires_at
    if token and time.time() < token_expires_at - 60:
        return token

    response = requests.post(
        f"https://{SHOP}/admin/oauth/access_token",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "client_credentials",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
        },
        timeout=30,
    )
    response.raise_for_status()
    print(f"Access token response: {response.status_code} - {response.text}")
    data = response.json()
    token = data["access_token"]
    print(f"Received access token: {token}")
    token_expires_at = time.time() + data["expires_in"]
    return token


def graphql(query):
    response = requests.post(
        f"https://{SHOP}/admin/api/2025-01/graphql.json",
        headers={
            "Content-Type": "application/json",
            "X-Shopify-Access-Token": get_token(),
        },
        json={"query": query},
        timeout=30,
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("errors"):
        raise RuntimeError(payload["errors"])
    return payload["data"]


def main() -> None:
    query = "{ products(first: 3) { edges { node { id title handle } } } }"
    data = graphql(query)
    print(data)


if __name__ == "__main__":
    main()