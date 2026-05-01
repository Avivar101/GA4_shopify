import os
from time import time
import requests
from dotenv import load_dotenv

load_dotenv()

STORE = os.getenv("SHOPIFY_STORE_URL")
API_VERSION = os.getenv("SHOPIFY_API_VERSION")
CLIENT_ID = os.getenv("SHOPIFY_CLIENT_ID")
CLIENT_SECRET = os.getenv("SHOPIFY_CLIENT_SECRET")

BASE_URL = f"http://{STORE}/admin/api/{API_VERSION}"

token = None
token_expires_at = 0.0

def get_token():
    global token, token_expires_at
    if token and time() < token_expires_at - 60:
        return token

    response = requests.post(
        f"https://{STORE}/admin/oauth/access_token",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "client_credentials",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
        },
        timeout=30,
    )
    response.raise_for_status()
    data = response.json()
    token = data["access_token"]
    token_expires_at = time() + data["expires_in"]
    return token

def get_paginated(endpoint, params=None, access_token=None):
    url = f"{BASE_URL}/{endpoint}"
    results = []

    HEADERS =  {
        "X-Shopify-Access-Token": access_token,
        "Content-Type": "application/json"
    }

    while url:
        response = requests.get(url, headers=HEADERS, params=params)
        response.raise_for_status()

        data = response.json()
        key = list(data.keys())[0]
        results.extend(data[key])

        # Pagination handling
        link_header = response.headers.get("Link")
        if link_header and 'rel="next"' in link_header:
            url = link_header.split(";")[0].strip("<>")
            params = None
        else:
            url = None
    return results