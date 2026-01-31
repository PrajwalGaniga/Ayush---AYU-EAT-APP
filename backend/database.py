import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

# Pull the Atlas URL from the environment
MONGO_URL = os.getenv("MONGO_URL")

if not MONGO_URL:
    raise ValueError("❌ MONGO_URL not found in .env file")

client = AsyncIOMotorClient(MONGO_URL)
database = client.ayush_db
user_collection = database.get_collection("users")

# Helper for MongoDB document conversion
def user_helper(user) -> dict:
    return {
        "id": str(user["_id"]),
        "fullname": user["fullname"],
        "phone": user["phone"],
        "prakriti": user.get("prakriti"),
        "ojas_score": user.get("ojas_score"),
        # Add other fields as needed
    }