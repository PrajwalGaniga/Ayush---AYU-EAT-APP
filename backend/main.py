from fastapi import FastAPI, Body, HTTPException
from database import user_collection, user_helper
import bcrypt
from pydantic import BaseModel
from fastapi import FastAPI, Body, HTTPException, File, UploadFile, BackgroundTasks
app = FastAPI()
from google import genai

@app.get("/")
async def root():
    return {"status": "Ayush Server is running on Port 8000"}

@app.post("/register")
async def register_user(user_data: dict = Body(...)):
    existing_user = await user_collection.find_one({"phone": user_data['phone']})
    if existing_user:
        raise HTTPException(status_code=400, detail="Phone already exists")
    
    hashed_pass = bcrypt.hashpw(user_data['password'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    new_user = {
        "fullname": user_data['fullname'],
        "phone": user_data['phone'],
        "password": hashed_pass,
        "gender": user_data.get('gender', 'male'),
        "onboarding_complete": False, 
        "ojas_score": 40, 
        "current_day": 1,
        "weekly_tasks": [],
        "assessment_history": [],
        "growth_history": [{"score": 40, "time": datetime.now()}],
        # NEW: Medical Profile Placeholders
        "health_profile": {
            "conditions": [],
            "allergies": [],
            "weight": None,
            "activity_level": "moderate"
        }
    }
    
    await user_collection.insert_one(new_user)
    return {"status": "User created successfully"}

from bson import ObjectId

# Logic to calculate Dosha % based on quiz answers
def calculate_prakriti(answers: list):
    # Mapping logic: Each answer is 0 (Vata), 1 (Pitta), or 2 (Kapha)
    v, p, k = 0, 0, 0
    for ans in answers:
        if ans == 0: v += 1
        elif ans == 1: p += 1
        elif ans == 2: k += 1
    
    total = len(answers)
    return {
        "vata": round((v / total) * 100, 2),
        "pitta": round((p / total) * 100, 2),
        "kapha": round((k / total) * 100, 2),
        "dominant": "Vata" if v >= p and v >= k else ("Pitta" if p >= k else "Kapha")
    }

@app.get("/ping")
async def ping():
    return {"message": "Server is reachable!"}

@app.post("/update_prakriti/{phone}")
async def update_prakriti(phone: str, quiz_data: dict = Body(...)):
    prakriti_results = calculate_prakriti(quiz_data['answers'])
    dominant = prakriti_results['dominant']
    
    # Fetch the correct 7-day rituals from your Master Dictionary
    # We use DINACHARYA_WEEKLY which has all 7 bilingual tasks
    initial_tasks = DINACHARYA_WEEKLY.get(dominant, DINACHARYA_WEEKLY["Vata"])
    
    result = await user_collection.update_one(
        {"phone": phone},
        {"$set": {
            "prakriti": prakriti_results,
            "onboarding_complete": True,
            "weekly_tasks": initial_tasks, # INJECT HERE: Now the user has all 7 tasks instantly
            "report_uploaded": quiz_data.get('report_uploaded', False)
        }}
    )
    
    if result.modified_count == 1:
        return {"status": "success", "data": prakriti_results}
    raise HTTPException(status_code=404, detail="User not found")

# Define a schema for the incoming JSON
from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel
import bcrypt

# 1. Define the Schema (Crucial for fixing the 404/422 errors)
class LoginSchema(BaseModel):
    phone: str
    password: str

@app.post("/login")
async def login(data: LoginSchema):
    # DEBUG: This will print in your terminal when Flutter hits the button
    print(f"🚀 LOGIN ATTEMPT: Phone={data.phone}")

    # 2. Find User
    user = await user_collection.find_one({"phone": data.phone})
    
    if not user:
        print(f"❌ ERROR: User {data.phone} not found in DB")
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # 3. Verify Password
    # Note: Using .encode() because bcrypt needs bytes
    if bcrypt.checkpw(data.password.encode('utf-8'), user["password"].encode('utf-8')):
        print(f"✅ SUCCESS: {data.phone} logged in")
        return {
            "status": "success",
            "fullname": user.get("fullname", "Seeker"),
            "phone": user["phone"],
            # Check your DB key name: might be 'onboarding_complete' or 'prakriti_done'
            "prakriti_done": user.get("onboarding_complete", False),
            "prakriti_data": user.get("prakriti", None)
        }
    
    print(f"❌ ERROR: Password mismatch for {data.phone}")
    raise HTTPException(status_code=401, detail="Invalid credentials")

# AUTHENTIC AYURVEDIC PROTOCOLS
DINACHARYA_MASTER = {
    "Vata": [
        {
            "id": 101, 
            "task_en": "Abhyanga (Oil Massage)", "task_kn": "ಅಭ್ಯಂಗ (ತೈಲ ಮಸಾಜ್)",
            "desc_en": "Use warm sesame oil to ground Vata.", "desc_kn": "ವಾತವನ್ನು ಸಮತೋಲನಗೊಳಿಸಲು ಬೆಚ್ಚಗಿನ ಎಳ್ಳೆಣ್ಣೆಯನ್ನು ಬಳಸಿ.",
            "know_more_en": "Warm oil massage calms the nervous system and reduces dryness.",
            "know_more_kn": "ಬೆಚ್ಚಗಿನ ತೈಲ ಮಸಾಜ್ ನರಮಂಡಲವನ್ನು ಶಾಂತಗೊಳಿಸುತ್ತದೆ ಮತ್ತು ಒಣಗಿದ ಚರ್ಮವನ್ನು ಗುಣಪಡಿಸುತ್ತದೆ.",
            "done": False
        },
        {
            "id": 102, 
            "task_en": "Ushnapana", "task_kn": "ಉಷ್ಣಪಾನ",
            "desc_en": "Drink lukewarm water to clear Ama.", "desc_kn": "ವಿಷಕಾರಿ ಅಂಶಗಳನ್ನು (ಆಮ) ಹೋಗಲಾಡಿಸಲು ಉಗುರುಬೆಚ್ಚಗಿನ ನೀರನ್ನು ಕುಡಿಯಿರಿ.",
            "know_more_en": "Warm water stimulates digestion and clears morning toxins.",
            "know_more_kn": "ಬೆಚ್ಚಗಿನ ನೀರು ಜೀರ್ಣಕ್ರಿಯೆಯನ್ನು ಉತ್ತೇಜಿಸುತ್ತದೆ ಮತ್ತು ಬೆಳಗಿನ ವಿಷವನ್ನು ಹೊರಹಾಕುತ್ತದೆ.",
            "done": False
        }
    ],
    "Pitta": [
        {
            "id": 201, 
            "task_en": "Sheetali Pranayama", "task_kn": "ಶೀತಲಿ ಪ್ರಾಣಾಯಾಮ",
            "desc_en": "Cooling breath to reduce Agni intensity.", "desc_kn": "ದೇಹದ ಉಷ್ಣತೆಯನ್ನು ಕಡಿಮೆ ಮಾಡಲು ಶೀತಲಿ ಉಸಿರಾಟ ಮಾಡಿ.",
            "know_more_en": "This technique cools the blood and reduces internal inflammation.",
            "know_more_kn": "ಈ ತಂತ್ರವು ರಕ್ತವನ್ನು ತಂಪಾಗಿಸುತ್ತದೆ ಮತ್ತು ಆಂತರಿಕ ಉರಿಯೂತವನ್ನು ಕಡಿಮೆ ಮಾಡುತ್ತದೆ.",
            "done": False
        }
    ],
    "Kapha": [
        {
            "id": 301, 
            "task_en": "Udvartana (Dry Scrub)", "task_kn": "ಉದ್ವರ್ತನ (ಒಣ ಸ್ಕ್ರಬ್)",
            "desc_en": "Stimulate flow with herbal powder.", "desc_kn": "ಗಿಡಮೂಲಿಕೆಗಳ ಪುಡಿಯಿಂದ ರಕ್ತ ಪರಿಚಲನೆ ಹೆಚ್ಚಿಸಿ.",
            "know_more_en": "Dry scrubbing breaks down fat tissues and reduces sluggishness.",
            "know_more_kn": "ಒಣ ಸ್ಕ್ರಬ್ಬಿಂಗ್ ಕೊಬ್ಬಿನಾಂಶವನ್ನು ಕರಗಿಸುತ್ತದೆ ಮತ್ತು ಆಲಸ್ಯವನ್ನು ಕಡಿಮೆ ಮಾಡುತ್ತದೆ.",
            "done": False
        }
    ]
}

@app.post("/update_onboarding/{phone}")
async def update_onboarding(phone: str, data: dict = Body(...)):
    """
    Handles both Prakriti Quiz and the new Health Profile.
    """
    # 1. Calculate Prakriti
    prakriti_results = calculate_prakriti(data.get('quiz_answers', []))
    dominant = prakriti_results['dominant']
    
    # 2. Extract Medical Profile
    health_profile = data.get('health_profile', {})
    
    initial_tasks = DINACHARYA_WEEKLY.get(dominant, DINACHARYA_WEEKLY["Vata"])
    
    result = await user_collection.update_one(
        {"phone": phone},
        {"$set": {
            "prakriti": prakriti_results,
            "health_profile": health_profile, # Save medical data
            "onboarding_complete": True,
            "weekly_tasks": initial_tasks
        }}
    )
    
    if result.modified_count == 1:
        return {"status": "success", "data": prakriti_results}
    raise HTTPException(status_code=404, detail="User not found")

@app.get("/user_profile/{phone}")
async def get_user_profile(phone: str):
    # 1. Fetch user from MongoDB
    user = await user_collection.find_one({"phone": phone})
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 2. Dynamic Injection Logic
    current_tasks = user.get("weekly_tasks", [])
    
    # TRIGGER: If tasks are empty or still use the old 2-task format
    if not current_tasks or len(current_tasks) < 7:
        dominant_dosha = user.get("prakriti", {}).get("dominant", "Vata")
        
        # FIXED: Pulling 7 tasks from DINACHARYA_WEEKLY instead of MASTER
        tasks_to_assign = DINACHARYA_WEEKLY.get(dominant_dosha, DINACHARYA_WEEKLY["Vata"])
        
        await user_collection.update_one(
            {"phone": phone},
            {"$set": {"weekly_tasks": tasks_to_assign}}
        )
        user["weekly_tasks"] = tasks_to_assign # Sync local variable for response

    # 3. Return Clean Production Data
    return {
        "status": "success",
        "data": {
            "fullname": user.get("fullname", "Seeker"),
            "phone": user.get("phone"),
            "gender": user.get("gender", "male"),
            "prakriti": user.get("prakriti", {"vata": 33.3, "pitta": 33.3, "kapha": 33.3, "dominant": "Balanced"}),
            "onboarding_complete": user.get("onboarding_complete", False),
            "ojas_score": user.get("ojas_score", 50),
            "weekly_tasks": user.get("weekly_tasks", []),
            "current_day": user.get("current_day", 1)
        }
    }

@app.get("/dietary_guidelines/{phone}")
async def get_diet_advice(phone: str):
    user = await user_collection.find_one({"phone": phone})
    dominant = user.get("prakriti", {}).get("dominant", "Vata")
    
    # Filter wisdom based on dominant dosha
    safe_foods = [v for k, v in ayu_db["food_wisdom"].items() if dominant.lower() in v["dosha"].lower() or "tridoshic" in v["dosha"].lower()]
    risky_foods = [v for k, v in ayu_db["food_wisdom"].items() if "aggravating" in v["dosha"].lower() and dominant.lower() in v["dosha"].lower()]
    
    return {
        "pathya": safe_foods[:5], # Top recommended
        "apathya": risky_foods[:5] # Foods to avoid
    }

import json
import shutil
from fastapi import File, UploadFile
from ultralytics import YOLO

# 1. Load the YOLO Model
model = YOLO("models/best.pt")

# 2. Load the Ayurvedic Knowledge Base
with open("data/ayu_knowledge.json", "r") as f:
    ayu_db = json.load(f)


from datetime import datetime

# FIXED: Vision Engine lookup using string IDs
# 1. Global variable initialized to None to save RAM on startup
model = None 

@app.post("/scan_meal")
async def scan_meal(file: UploadFile = File(...)):
    global model
    if model is None:
        model = YOLO("models/best.pt") 

    file_path = f"temp_{file.filename}"
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        results = model(file_path)
        detected_items = []
        
        for box in results[0].boxes:
            idx = str(int(box.cls)) 
            info = ayu_db["food_wisdom"].get(idx)
            if info:
                detected_items.append({
                    "id": idx,
                    "name": info["name"],
                    "dosha_impact": info["dosha"],
                    "virya": info["virya"]
                })
        
        # Step 1: Return identification to Flutter for confirmation
        return {"items": detected_items}
    finally:
        if os.path.exists(file_path):
            os.remove(file_path)

@app.post("/confirm_scan/{phone}")
async def confirm_scan(phone: str, data: dict = Body(...)):
    """
    Step 2 & 3: User confirms identification and provides context (Home/Hotel).
    """
    is_homemade = data.get("is_homemade", True)
    item_id = data.get("item_id")
    
    info = ayu_db["food_wisdom"].get(item_id)
    
    # Logic: Restaurant penalty
    ojas_impact = 10 if is_homemade else 4
    
    # Store temporary "active meal" to trigger 2-hour feedback later
    await user_collection.update_one(
        {"phone": phone},
        {"$set": {"last_meal": {"item": info['name'], "source": "home" if is_homemade else "hotel", "time": datetime.now()}}}
    )
    
    return {
        "status": "success",
        "impact": info["note"],
        "is_compatible": True, # Placeholder for Viruddha check logic
        "ojas_change": ojas_impact
    }

@app.get("/post_meal_status/{phone}")
async def get_post_meal_questions(phone: str):
    """
    The 2-hour feedback questionnaire.
    """
    user = await user_collection.find_one({"phone": phone})
    last_meal = user.get("last_meal", {})
    
    return {
        "message": f"You ate {last_meal.get('item')} from a {last_meal.get('source')} 2 hours ago.",
        "questions": [
            "Are you feeling heavy or bloated?",
            "Is there any acidity or burning sensation?",
            "Do you feel energetic or sleepy?"
        ]
    }

import os

# Get the absolute path to the folder containing main.py
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Load the Q&A Knowledge Base using an absolute path
# main.py - Improved Debug Loading
qna_path = os.path.join(BASE_DIR, "data", "ayushQnA.json")

ayush_qna = {}

try:
    with open(qna_path, "r", encoding="utf-8") as f:
        ayush_qna = json.load(f)
    
    # SENIOR DEBUG: Verify the structure immediately
    top_keys = list(ayush_qna.keys())
    print(f"✅ JSON Loaded. Top-level keys found: {top_keys}")
    
    if "categories" in ayush_qna:
        categories = list(ayush_qna["categories"].keys())
        print(f"📂 Categories found: {categories}")
    else:
        print("⚠️ CRITICAL: Key 'categories' NOT found in JSON. Check your JSON file structure!")

except Exception as e:
    print(f"❌ JSON LOAD ERROR: {e}")
@app.post("/chat_query")
async def chat_query(data: dict = Body(...)):
    # 1. Capture Input Data
    node_id = data.get("current_node", "AGNI_Q1")
    choice_value = data.get("user_choice")
    lang = data.get("lang", "en")
    phone = data.get("phone")

    print(f"\n--- 🤖 CHAT DEBUG START ---")
    print(f"📍 Current Node Requested: {node_id}")
    print(f"🔘 User Choice: {choice_value}")

    # 2. Safety Check: Is the JSON even loaded?
    if not ayush_qna:
        print("❌ CRITICAL: 'ayush_qna' dictionary is EMPTY. Check JSON loading at startup.")
        raise HTTPException(status_code=500, detail="Knowledge base not loaded on server.")

    # 3. Build Question Pool with detailed tracking
    categories = ayush_qna.get("categories", {})
    agni_qs = categories.get("agni_assessment", {}).get("questions", {})
    dosha_qs = categories.get("dosha_assessment", {}).get("questions", {})
    
    questions_pool = {**agni_qs, **dosha_qs}
    
    print(f"📊 Total Nodes in Pool: {len(questions_pool)}")
    print(f"🔑 Available Node IDs: {list(questions_pool.keys())[:10]}... (showing first 10)")

    # 4. Handle Result Logic (End of Tree)
    if "RESULT" in node_id or node_id == "REVIEW_REQUIRED":
        print(f"🏁 Result Node Reached: {node_id}")
        results_map = ayush_qna.get("results", {})
        res = results_map.get(node_id)
        
        if not res:
            print(f"❌ ERROR: Result node '{node_id}' missing from 'results' key in JSON.")
            raise HTTPException(status_code=404, detail=f"Result node {node_id} not found")

        assessment_entry = {
            "timestamp": datetime.now().isoformat(),
            "prakriti": res.get("prakriti", "Unknown"),
            "agni": res.get("agni", "Unknown"),
            "message": res.get(f"message_{lang}", res.get("message_en", "Assessment complete.")),
            "node_reached": node_id
        }
        
        if phone:
            print(f"💾 Saving assessment to DB for phone: {phone}")
            await user_collection.update_one(
                {"phone": phone},
                {"$push": {"assessment_history": assessment_entry}}
            )

        return {"type": "result", "data": assessment_entry}

    # 5. Extract Question Node
    current_node = questions_pool.get(node_id)
    
    if not current_node:
        print(f"🚨 FAIL: Node '{node_id}' not found in the constructed pool.")
        # Diagnostic: Check if keys are actually under 'categories -> questions' directly
        top_keys = list(ayush_qna.keys())
        print(f"💡 Hint: Check your JSON nesting. Top-level keys: {top_keys}")
        raise HTTPException(status_code=404, detail=f"Node {node_id} not found in database.")

    # 6. Determine Next Node
    next_node_id = node_id 
    if choice_value:
        found_choice = False
        for opt in current_node.get("options", []):
            if opt["value"] == choice_value:
                next_node_id = opt["next"]
                found_choice = True
                print(f"➡️ Choice Match! Next node will be: {next_node_id}")
                break
        if not found_choice:
            print(f"⚠️ WARNING: User choice '{choice_value}' did not match any options in {node_id}")

    next_node = questions_pool.get(next_node_id)

    # 7. Recursive Transition (If the next step is a result)
    if not next_node: 
        print(f"🔄 Node '{next_node_id}' is not a question. Triggering result logic...")
        return await chat_query({"current_node": next_node_id, "lang": lang, "phone": phone})

    print(f"✅ Returning Question: {next_node_id}")
    print(f"--- 🤖 CHAT DEBUG END ---\n")

    return {
        "type": "question",
        "node_id": next_node_id,
        "question": next_node.get(f"question_{lang}", next_node.get("question_en")),
        "options": [
            {"value": o["value"], "label": o.get(f"label_{lang}", o.get("label_en"))} 
            for o in next_node.get("options", [])
        ]
    }

from datetime import datetime
# UPDATED: Task completion now triggers an Ojas update

# AUTHENTIC 7-DAY DINACHARYA MASTER DATA
# Categorized by Prakriti with unique IDs for atomic DB updates

DINACHARYA_WEEKLY = {
    "Vata": [
        {"id": "v1", "task_en": "Oil Pulling (Gandusha)", "task_kn": "ಗಂಡೂಷ", "desc_en": "Swish warm sesame oil for 5 mins.", "desc_kn": "5 ನಿಮಿಷ ಬೆಚ್ಚಗಿನ ಎಣ್ಣೆಯನ್ನು ಮುಕ್ಕಳಿಸಿ.", "done": False},
        {"id": "v2", "task_en": "Warm Abhyanga", "task_kn": "ಅಭ್ಯಂಗ", "desc_en": "Self-massage with warm oil before bath.", "desc_kn": "ಸ್ನಾನಕ್ಕೂ ಮುನ್ನ ಬೆಚ್ಚಗಿನ ಎಣ್ಣೆ ಮಸಾಜ್.", "done": False},
        {"id": "v3", "task_en": "Ushnapana", "task_kn": "ಉಷ್ಣಪಾನ", "desc_en": "Drink a glass of lukewarm water.", "desc_kn": "ಒಂದು ಲೋಟ ಉಗುರುಬೆಚ್ಚಗಿನ ನೀರನ್ನು ಕುಡಿಯಿರಿ.", "done": False},
        {"id": "v4", "task_en": "Nadi Shodhana", "task_kn": "ನಾಡಿ ಶೋಧನ", "desc_en": "5 mins of alternate nostril breathing.", "desc_kn": "5 ನಿಮಿಷಗಳ ಕಾಲ ಅನುಲೋಮ-ವಿಲೋಮ ಪ್ರಾಣಾಯಾಮ.", "done": False},
        {"id": "v5", "task_en": "Grounding Walk", "task_kn": "ನೆಲದ ಸಂಪರ್ಕ", "desc_en": "Walk barefoot on grass or earth.", "desc_kn": "ಹುಲ್ಲಿನ ಮೇಲೆ ಬರಿಗಾಲಿನಲ್ಲಿ ನಡೆಯಿರಿ.", "done": False},
        {"id": "v6", "task_en": "Pada-Abhyanga", "task_kn": "ಪಾದಾಭ್ಯಂಗ", "desc_en": "Massage feet with ghee before bed.", "desc_kn": "ಮಲಗುವ ಮುನ್ನ ಪಾದಗಳಿಗೆ ತುಪ್ಪದ ಮಸಾಜ್.", "done": False},
        {"id": "v7", "task_en": "Early Rest", "task_kn": "ಬೇಗ ವಿಶ್ರಾಂತಿ", "desc_en": "In bed by 10 PM to stabilize Vata.", "desc_kn": "ವಾತ ಸಮತೋಲನಕ್ಕೆ ರಾತ್ರಿ 10 ಗಂಟೆಗೆ ಮಲಗಿ.", "done": False}
    ],
    "Pitta": [
        {"id": "p1", "task_en": "Sheetali Pranayama", "task_kn": "ಶೀತಲಿ ಪ್ರಾಣಾಯಾಮ", "desc_en": "10 rounds of cooling breath.", "desc_kn": "10 ಬಾರಿ ಶೀತಲಿ ಉಸಿರಾಟದ ಅಭ್ಯಾಸ ಮಾಡಿ.", "done": False},
        {"id": "p2", "task_en": "Coconut Oil Abhyanga", "task_kn": "ತೈಲ ಮಸಾಜ್", "desc_en": "Massage with cooling coconut oil.", "desc_kn": "ತಂಪಾದ ತೆಂಗಿನ ಎಣ್ಣೆಯಿಂದ ಮಸಾಜ್ ಮಾಡಿ.", "done": False},
        {"id": "p3", "task_en": "Rose Water Eye Wash", "task_kn": "ಕಣ್ಣಿನ ಸ್ವಚ್ಛತೆ", "desc_en": "Soothe eyes with cool rose water.", "desc_kn": "ಗುಲಾಬಿ ನೀರಿನಿಂದ ಕಣ್ಣುಗಳನ್ನು ತೊಳೆಯಿರಿ.", "done": False},
        {"id": "p4", "task_en": "Moonlight Walk", "task_kn": "ಚಂದ್ರನ ನಡಿಗೆ", "desc_en": "Walk under the moon for 10 mins.", "desc_kn": "10 ನಿಮಿಷಗಳ ಕಾಲ ಚಂದ್ರನ ಬೆಳಕಿನಲ್ಲಿ ನಡೆಯಿರಿ.", "done": False},
        {"id": "p5", "task_en": "Midday Meditation", "task_kn": "ಧ್ಯಾನ", "desc_en": "Calm the mind during Pitta peak (12 PM).", "desc_kn": "ಮಧ್ಯಾಹ್ನ 12 ಗಂಟೆಗೆ ಸ್ವಲ್ಪ ಸಮಯ ಧ್ಯಾನ ಮಾಡಿ.", "done": False},
        {"id": "p6", "task_en": "Shatavari Tea", "task_kn": "ಶತಾವರಿ ಚಹಾ", "desc_en": "Drink a cooling herbal infusion.", "desc_kn": "ತಂಪಾದ ಗಿಡಮೂಲಿಕೆ ಚಹಾವನ್ನು ಕುಡಿಯಿರಿ.", "done": False},
        {"id": "p7", "task_en": "Practice Gratitude", "task_kn": "ಕೃತಜ್ಞತೆ", "desc_en": "Write 3 things you are thankful for.", "desc_kn": "ನೀವು ಕೃತಜ್ಞರಾಗಿರುವ 3 ವಿಷಯಗಳನ್ನು ಬರೆಯಿರಿ.", "done": False}
    ],
    "Kapha": [
        {"id": "k1", "task_en": "Surya Muhurta Wakeup", "task_kn": "ಬೇಗ ಏಳುವುದು", "desc_en": "Wake up before 6 AM.", "desc_kn": "ಬೆಳಿಗ್ಗೆ 6 ಗಂಟೆಯ ಮೊದಲು ಏಳಿ.", "done": False},
        {"id": "k2", "task_en": "Udvartana (Dry Scrub)", "task_kn": "ಉದ್ವರ್ತನ", "desc_en": "Dry herbal powder skin massage.", "desc_kn": "ಗಿಡಮೂಲಿಕೆ ಪುಡಿಯಿಂದ ಒಣ ಮಸಾಜ್ ಮಾಡಿ.", "done": False},
        {"id": "k3", "task_en": "Vigorous Yoga", "task_kn": "ವೇಗವಾದ ಯೋಗ", "desc_en": "12 rounds of fast Surya Namaskar.", "desc_kn": "12 ಬಾರಿ ವೇಗವಾದ ಸೂರ್ಯ ನಮಸ್ಕಾರ ಮಾಡಿ.", "done": False},
        {"id": "k4", "task_en": "Nasya (Nasal Drops)", "task_kn": "ನಸ್ಯ", "desc_en": "Apply 2 drops of Anu Thailam in nose.", "desc_kn": "ಮೂಗಿಗೆ 2 ಹನಿ ಅಣು ತೈಲವನ್ನು ಹಾಕಿ.", "done": False},
        {"id": "k5", "task_en": "Warm Ginger Water", "task_kn": "ಶುಂಠಿ ನೀರು", "desc_en": "Sip hot ginger water throughout day.", "desc_kn": "ದಿನವಿಡೀ ಬಿಸಿ ಶುಂಠಿ ನೀರನ್ನು ಕುಡಿಯಿರಿ.", "done": False},
        {"id": "k6", "task_en": "Stimulating Walk", "task_kn": "ಚುರುಕಾದ ನಡಿಗೆ", "desc_en": "20 mins of brisk afternoon walking.", "desc_kn": "ಮಧ್ಯಾಹ್ನ 20 ನಿಮಿಷ ಚುರುಕಾಗಿ ನಡೆಯಿರಿ.", "done": False},
        {"id": "k7", "task_en": "Social Connection", "task_kn": "ಸಾಮಾಜಿಕ ಸಂವಹನ", "desc_en": "Call a friend or family member.", "desc_kn": "ಸ್ನೇಹಿತರು ಅಥವಾ ಕುಟುಂಬದವರಿಗೆ ಕರೆ ಮಾಡಿ.", "done": False}
    ]
}
# SMART MOVE: Scoring Engine
@app.post("/update_task/{phone}")
async def update_task(phone: str, payload: dict = Body(...)):
    task_id = payload.get("taskId")
    is_done = payload.get("isDone")
    
    # Generate human-readable timestamp
    now = datetime.now().strftime("%d %b, %I:%M %p")
    
    # Update state and timestamp in one atomic operation
    await user_collection.update_one(
        {"phone": phone, "weekly_tasks.id": task_id},
        {"$set": {
            "weekly_tasks.$.done": is_done,
            "weekly_tasks.$.completed_at": now if is_done else None
        }}
    )
    
    # Recalculate Ojas: Base 40 + (10 points per task)
    user = await user_collection.find_one({"phone": phone})
    done_count = sum(1 for t in user.get("weekly_tasks", []) if t.get("done"))
    new_ojas = min(100, 40 + (done_count * 8))
    
    await user_collection.update_one(
        {"phone": phone},
        {"$set": {"ojas_score": new_ojas}}
    )
    return {"status": "success", "completed_at": now, "new_ojas": new_ojas}



# 4. RESET WEEK ROUTE
@app.post("/reset_week/{phone}")
async def reset_week(phone: str):
    user = await user_collection.find_one({"phone": phone})
    dominant = user.get("prakriti", {}).get("dominant", "Vata")
    
    # Refresh tasks based on high Dosha percentage
    new_tasks = DINACHARYA_WEEKLY.get(dominant, DINACHARYA_WEEKLY["Vata"])
    
    await user_collection.update_one(
        {"phone": phone},
        {"$set": {"weekly_tasks": new_tasks, "ojas_score": 40}}
    )
    return {"status": "success", "message": "Dinacharya Reset"}


from datetime import datetime, timedelta

@app.get("/weekly_summary/{phone}")
async def get_weekly_summary(phone: str):
    user = await user_collection.find_one({"phone": phone})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 1. Calculate Task Completion Rate
    tasks = user.get("weekly_tasks", [])
    completed = sum(1 for t in tasks if t.get("done"))
    task_score = (completed / len(tasks) * 100) if tasks else 0

    # 2. Extract Recent Ojas Trend (Last 7 Days)
    history = user.get("growth_history", [])
    recent_scores = [h['score'] for h in history[-7:]]
    avg_ojas = sum(recent_scores) / len(recent_scores) if recent_scores else user.get("ojas_score", 50)

    # 3. Clinical Conclusion
    status = "Prakriti Balanced" if avg_ojas > 70 else "Vitiation Risk"
    
    return {
        "avg_ojas": round(avg_ojas, 1),
        "task_completion": round(task_score, 1),
        "clinical_status": status,
        "recommendation": "Maintain Dinacharya rituals to stabilize Agni."
    }


from fastapi import FastAPI, HTTPException, Body
from google import genai
from google.genai import types
import os
import json


from database import database as db, user_collection, user_helper
history_collection = db.get_collection("recipe_history")
# 2. CLIENT CONFIGURATION (Direct Key for Local Stability)
# Forced v1beta for JSON Schema support with developer keys
GEMINI_API_KEY = "AIzaSyApBq1X_ae20e02BgOsLCtcOyzNd2cyq0c"
client = genai.Client(
    api_key=GEMINI_API_KEY,
    http_options={'api_version': 'v1beta'}
)

# 3. BACKGROUND TASK: Save to History
async def save_to_history(phone: str, ingredients: list, recipe: dict):
    """Saves a permanent log of the medicinal recipe."""
    try:
        history_entry = {
            "phone": phone,
            "timestamp": datetime.now(),
            "ingredients": ingredients,
            "recipe_name": recipe.get("recipe_name"),
            "full_recipe": recipe 
        }
        await history_collection.insert_one(history_entry)
        print(f"✅ History saved for {phone}: {recipe.get('recipe_name')}")
    except Exception as e:
        print(f"❌ History Save Error: {e}")

# 4. ENHANCED RECIPE GENERATOR
@app.post("/generate_recipe/{phone}")
async def generate_recipe(phone: str, bg_tasks: BackgroundTasks, ingredients: list = Body(...)):
    print(f"\n--- 🍳 AI KITCHEN DEBUG START ---")
    print(f"📍 Requesting Phone: {phone}")
    print(f"🛒 Ingredients Selected: {ingredients}")

    # A. Fetch Clinical Data from User Document
    user = await user_collection.find_one({"phone": phone})
    if not user:
        print(f"❌ FAIL: User {phone} not found in DB.")
        raise HTTPException(status_code=404, detail="User not found")
    
    # B. Extract Context
    prakriti = user.get("prakriti", {}).get("dominant", "Balanced")
    health = user.get("health_profile", {})
    conditions = health.get("conditions", [])
    allergies = health.get("allergies", [])
    
    # C. Get current Agni from last assessment
    assessments = user.get("assessment_history", [])
    agni = assessments[-1].get("agni", "Sama Agni") if assessments else "Sama Agni"

    print(f"🧬 Bio-Profile: {prakriti} | {agni}")
    print(f"🏥 Medical: {conditions} | 🚫 Allergies: {allergies}")

    # D. THE PRODUCTION-READY "MASTER VAIDYA" PROMPT
    prompt = f"""
Act as a Master Vaidya (Ayurvedic Doctor) and a Culinary Nutritionist. 
Create a strictly medicinal, healing recipe for a person with the following clinical profile:

1. Dominant Dosha (Prakriti): {prakriti}
2. Digestive Power (Agni): {agni}
3. Medical Conditions: {', '.join(conditions) if conditions else 'General Wellness'}
4. Strict Allergies: {', '.join(allergies) if allergies else 'None'}
5. Available Ingredients: {', '.join(ingredients)}

STRICT REQUIREMENTS:
- RECIPE NAME: Provide a creative name in both English and Kannada (e.g., Healing Ginger Tea - ಶುಂಠಿ ಚಹಾ).
- CLINICAL REASONING: Explain WHY this recipe is prescribed. Reference how it balances {prakriti}, supports {agni}, and manages {', '.join(conditions)}. (Bilingual: 3 sentences total).
- SAFETY CHECK: You MUST NOT use any ingredients that match the user's allergies ({', '.join(allergies)}).
- INSTRUCTIONS: 5-7 bilingual cooking steps.
- OJAS: Assign a vitality score from 5-15 based on the prana of ingredients.

Return ONLY a JSON object.
"""

    try:
        # E. AI Execution with Schema Enforcement
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema={
                    "type": "OBJECT",
                    "properties": {
                        "recipe_name": {"type": "STRING"},
                        "ayurvedic_benefit": {"type": "STRING"},
                        "instructions": {"type": "ARRAY", "items": {"type": "STRING"}},
                        "youtube_query": {"type": "STRING"},
                        "ojas_impact": {"type": "INTEGER"}
                    },
                    "required": ["recipe_name", "ayurvedic_benefit", "instructions"]
                }
            )
        )
        
        recipe_data = json.loads(response.text)
        print(f"✨ AI SUCCESS: Generated '{recipe_data.get('recipe_name')}'")
        print(f"--- 🍳 AI KITCHEN DEBUG END ---\n")

        # F. Background History Save
        bg_tasks.add_task(save_to_history, phone, ingredients, recipe_data)

        return {"status": "success", "data": recipe_data}

    except Exception as e:
        print(f"🚨 AI KITCHEN CRASH: {e}")
        raise HTTPException(status_code=500, detail="Vaidya AI is currently unavailable.")

# 5. RECIPE HISTORY LOG
@app.get("/recipe_history/{phone}")
async def get_recipe_history(phone: str):
    """Fetches the last 20 healing recipes for the user's log."""
    cursor = history_collection.find({"phone": phone}).sort("timestamp", -1)
    history = await cursor.to_list(length=20)
    
    # Clean MongoDB _id for Flutter compatibility
    for item in history:
        item["_id"] = str(item["_id"])
        if "timestamp" in item:
            item["timestamp"] = item["timestamp"].isoformat()
            
    return {"status": "success", "data": history}

@app.get("/list_my_models")
async def list_my_models():
    try:
        available_models = []
        # We'll print the first model's dir() to the terminal so you can see the real attributes
        models = list(client.models.list())
        
        for m in models:
            # Most models support generate_content; we'll just list them all to be safe
            available_models.append(m.name)
            
        return {"supported_models": available_models}
    except Exception as e:
        print(f"DEBUG - List Models Error: {e}")
        return {"error": str(e)}

# main.py
@app.get("/health")
async def health_check():
    return {"status": "ready", "timestamp": datetime.now().isoformat()}