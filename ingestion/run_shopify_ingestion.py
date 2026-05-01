from ingest_data import ingest_shopify_data

def main():
    import sys
    print(sys.executable)
    ingest_shopify_data("order", "raw_shopify_orders")
    ingest_shopify_data("product", "raw_shopify_products")
    ingest_shopify_data("customer", "raw_shopify_customers")

if __name__ == "__main__":
    main()