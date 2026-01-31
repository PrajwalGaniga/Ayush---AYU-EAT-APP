import os
import json
from google import genai
from google.genai import types

# 1. YOUR RECENT API KEYS
keys = [
    "AIzaSyBFMro2YIc2c8cOEMTmNTUglpGCYhU5CsE", # Key 1
    "AIzaSyBzcvdYla0wWvqt_854whYsM5pvBKWFL6o"  # Key 2
]

# 2. 2026 MODEL DIRECTORY
# We remove 1.5/1.0 (404) and move to 2.5/3.0
models_to_test = [
    "gemini-3-flash-preview", # New default
    "gemini-3-pro-preview",   # Most intelligent
    "gemini-2.5-flash",       # Stable workhorse
    "gemini-2.5-flash-lite",  # Ultra fast
    "gemini-2.0-flash"        # Deprecated (March 2026 shutdown)
]

api_versions = ["v1", "v1beta"]

def run_2026_diagnostic():
    print("🚀 AYUSH AI 2026 INFRASTRUCTURE CHECK")
    print("=" * 60)

    for i, key in enumerate(keys):
        print(f"\n🔑 TESTING KEY {i+1} ({key[:6]}...)")
        
        for version in api_versions:
            print(f"\n--- Checking Endpoint: {version} ---")
            client = genai.Client(api_key=key, http_options={'api_version': version})

            for model_id in models_to_test:
                print(f"   👉 {model_id:25}", end=" ", flush=True)
                try:
                    # Simple prompt to test connectivity
                    response = client.models.generate_content(
                        model=model_id,
                        contents="Say 'ONLINE'"
                    )
                    print(f"✅ SUCCESS! [{response.text.strip()}]")
                except Exception as e:
                    err = str(e)
                    if "404" in err:
                        print("❌ 404 (Retired/Invalid String)")
                    elif "429" in err:
                        print("⚠️ 429 (Quota Exhausted)")
                    elif "503" in err:
                        print("🛑 503 (Model Overloaded)")
                    else:
                        print(f"🔥 Error: {err[:40]}...")

    print("\n" + "=" * 60)
    print("💡 RECOMMENDATION:")
    print("Use 'gemini-2.5-flash' for production stability.")
    print("Use 'gemini-3-flash-preview' for the best multimodal understanding.")

if __name__ == "__main__":
    run_2026_diagnostic()