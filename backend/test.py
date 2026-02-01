import requests
import json

# Your live URL
BASE_URL = "https://ayush-ayu-eat-app.onrender.com"

def run_test():
    print(f"🔍 Starting tests for: {BASE_URL}")
    
    # 1. Test Root
    try:
        r = requests.get(f"{BASE_URL}/", timeout=10)
        print(f"✅ Root Endpoint: {r.status_code} - {r.json()}")
    except Exception as e:
        print(f"❌ Root Failed: {e}")

    # 2. Test Login Connection (Expected to fail with 401/422, but should CONNECT)
    try:
        payload = {"phone": "9110687983", "password": "wrong_password"}
        r = requests.post(f"{BASE_URL}/login", json=payload, timeout=10)
        print(f"✅ Login Connection: {r.status_code} - {r.text[:100]}")
    except Exception as e:
        print(f"❌ Login Connection Failed: {e}")

    # 3. Test Health/Ping
    try:
        r = requests.get(f"{BASE_URL}/ping", timeout=10)
        print(f"✅ Ping: {r.status_code} - {r.json()}")
    except Exception as e:
        print(f"❌ Ping Failed: {e}")

if __name__ == "__main__":
    run_test()