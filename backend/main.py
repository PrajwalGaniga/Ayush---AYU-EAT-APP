from fastapi import FastAPI, Body, HTTPException
from database import user_collection, user_helper
import bcrypt
from pydantic import BaseModel

app = FastAPI()
from google import genai

@app.get("/")
async def root():
    return {"status": "Ayush Server is running on Port 8000"}

@app.post("/register")
async def register_user(user_data: dict = Body(...)):
    # 1. Check if phone exists
    existing_user = await user_collection.find_one({"phone": user_data['phone']})
    if existing_user:
        raise HTTPException(status_code=400, detail="Phone already exists")
    
    # 2. Secure Password Hashing
    hashed_pass = bcrypt.hashpw(user_data['password'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    # 3. Create Clean User Document
    new_user = {
        "fullname": user_data['fullname'],
        "phone": user_data['phone'],
        "password": hashed_pass,
        "gender": user_data.get('gender', 'male'),
        "onboarding_complete": False, 
        "ojas_score": 40, 
        "current_day": 1,
        "weekly_tasks": [], # FIXED: Empty list triggers full injection later
        "assessment_history": [],
        "growth_history": [{"score": 40, "time": datetime.now()}]
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
    
    # 2. Lazy Load: Only load the heavy YOLO engine when actually needed
    if model is None:
        print("🚀 Loading YOLO model into memory...")
        # Ensure the path matches your project structure
        model = YOLO("models/best.pt") 

    # 3. Save the uploaded file temporarily
    file_path = f"temp_{file.filename}"
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 4. Run detection
        results = model(file_path)
        detected_items = []
        
        for box in results[0].boxes:
            # Map numeric index to JSON string key for knowledge base lookup
            idx = str(int(box.cls)) 
            info = ayu_db["food_wisdom"].get(idx)
            if info:
                detected_items.append({
                    "name": info["name"],
                    "dosha": info["dosha"],
                    "virya": info["virya"],
                    "impact": info["note"]
                })
        
        return {"items": detected_items}

    finally:
        # 5. Cleanup: Always delete the temp file to prevent disk bloat
        if os.path.exists(file_path):
            os.remove(file_path)

import os

# Get the absolute path to the folder containing main.py
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Load the Q&A Knowledge Base using an absolute path
qna_path = os.path.join(BASE_DIR, "data", "ayushQnA.json")

try:
    with open(qna_path, "r", encoding="utf-8") as f:
        ayush_qna = json.load(f)
    print("✅ Chatbot Knowledge Base loaded successfully.")
except Exception as e:
    print(f"❌ CRITICAL ERROR: Could not load chatbot data: {e}")
    ayush_qna = {"categories": {}, "results": {}} # Fallback to prevent crash

@app.post("/chat_query")
async def chat_query(data: dict = Body(...)):
    node_id = data.get("current_node", "AGNI_Q1")
    choice_value = data.get("user_choice")
    lang = data.get("lang", "en")
    phone = data.get("phone")

    # 1. Handle Result Saving Logic (When user reaches the end)
    if "RESULT" in node_id or node_id == "REVIEW_REQUIRED":
        res = ayush_qna.get("results", {}).get(node_id)
        if not res:
            raise HTTPException(status_code=404, detail="Result node not found")

        assessment_entry = {
            "timestamp": datetime.now().isoformat(),
            "prakriti": res.get("prakriti", "Unknown"),
            "agni": res.get("agni", "Unknown"),
            "message": res.get(f"message_{lang}", res.get("message_en", "Assessment complete.")),
            "node_reached": node_id
        }
        
        # Save to DB if phone is provided
        if phone:
            await user_collection.update_one(
                {"phone": phone},
                {"$push": {"assessment_history": assessment_entry}}
            )

        return {"type": "result", "data": assessment_entry}

    # 2. Extract Question Node
    # We look in both Agni and Dosha categories
    questions_pool = {
        **ayush_qna.get("categories", {}).get("agni_assessment", {}).get("questions", {}),
        **ayush_qna.get("categories", {}).get("dosha_assessment", {}).get("questions", {})
    }
    
    current_node = questions_pool.get(node_id)
    
    if not current_node:
        print(f"🚨 Bot Error: Node {node_id} not found in JSON pool.")
        raise HTTPException(status_code=404, detail=f"Node {node_id} not found")

    # 3. Determine Next Node
    next_node_id = node_id # Default to stay on same if no choice
    if choice_value:
        for opt in current_node.get("options", []):
            if opt["value"] == choice_value:
                next_node_id = opt["next"]
                break

    next_node = questions_pool.get(next_node_id)

    # 4. Recursive Transition (If the next node is actually a Result)
    if not next_node: 
        return await chat_query({"current_node": next_node_id, "lang": lang, "phone": phone})

    # 5. Return structured question
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



# 1. MODERN SETUP (2026 Standards)
# Keep your API key in an environment variable for security

#client = genai.Client(api_key=GEMINI_KEY)


# --- 1. CONFIGURATION ---
# Use the stable v1 API version to avoid common beta-related 404 errors.
GEMINI_KEY = os.getenv("GEMINI_API_KEY")
# Force 'v1beta' because it is the only version that fully supports 
# these JSON schema fields for developer API keys.
# Create two separate clients to hit different API endpoints
# Force 'v1beta' for the new models
# Force v1beta: It is the only endpoint that supports JSON Schema for free keys.
client = genai.Client(
    api_key="AIzaSyBFMro2YIc2c8cOEMTmNTUglpGCYhU5CsE",
    http_options={'api_version': 'v1beta'} # Required for JSON Schema
)
import json
import logging
from fastapi import Body, HTTPException
from google.genai import types
# Set up logging for professional debugging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
from fastapi import BackgroundTasks
# New collection for history
# 1. Update your imports at the top of main.py
from database import database, user_collection # Import the correct database object

# 2. Use 'database' instead of 'db' to define your new collection
history_collection = database.get_collection("recipe_history") # Corrected from 'db'

def save_to_history(phone: str, ingredients: list, recipe: dict):
    """Saves recipe to user's personal timeline."""
    history_entry = {
        "phone": phone,
        "timestamp": datetime.utcnow(),
        "ingredients": ingredients,
        "recipe_name": recipe.get("recipe_name"),
        "full_recipe": recipe # Store full JSON for 'Know More' view
    }
    history_collection.insert_one(history_entry)

@app.post("/generate_recipe/{phone}")
async def generate_recipe(phone: str, bg_tasks: BackgroundTasks, ingredients: list = Body(...)):
    # 1. Fetch Clinical Context (Existing Logic)
    user = await user_collection.find_one({"phone": phone})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    prakriti = user.get("prakriti", {}).get("dominant", "Balanced")
    history = user.get("assessment_history", [])
    agni = history[-1].get("agni", "Sama Agni") if history else "Sama Agni"

    # 2. Advanced Prompt (As provided previously)
    prompt = f"""
Act as a Master Vaidya and a Michelin-star Chef specialized in Ayurvedic Nutrition. 
Your goal is to create a medicinal, healing recipe specifically for a person with:
- Dominant Dosha (Prakriti): {prakriti}
- Digestive Fire (Agni): {agni}
- Available Ingredients: {', '.join(ingredients)}

STRICT REQUIREMENTS:
1. RECIPE NAME: Provide a creative name in both English and Kannada (e.g., Healing Khichdi - ಚಿಕಿತ್ಸಕ ಖಿಚಡಿ).
2. LOGIC: Explain exactly how these ingredients balance the {prakriti} dosha and improve {agni} in 2-3 sentences (Bilingual).
3. INSTRUCTIONS: Provide 5-7 detailed cooking steps. Each step MUST contain the English instruction followed by the Kannada translation.
4. YOUTUBE: Generate a highly specific search query for this dish to find the best video tutorial.
5. OJAS: Assign an Ojas Impact score between 5-15 based on the prana of the ingredients.

OUTPUT FORMAT:
Return ONLY a JSON object. Do not include any conversational text.
"""

    # 3. Failover Matrix
    for model_id in ["gemini-3-flash-preview", "gemini-2.5-flash"]:
        try:
            response = client.models.generate_content(
                model=model_id,
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
                        "required": ["recipe_name", "instructions"]
                    }
                )
            )
            
            recipe_data = json.loads(response.text)

            # --- NEW: Save to history in background ---
            # This allows the AI response to be sent immediately while DB writes happen
            bg_tasks.add_task(save_to_history, phone, ingredients, recipe_data)

            return {"status": "success", "data": recipe_data}
            
        except Exception as e:
            logging.error(f"Fallback: {model_id} failed. Trying next...")
            continue

    raise HTTPException(status_code=503, detail="AI Kitchen Overloaded")

@app.get("/recipe_history/{phone}")
async def get_recipe_history(phone: str):
    """Fetches the user's history, sorted by newest first."""
    # Retrieve only the last 20 recipes to maintain high performance
    cursor = history_collection.find({"phone": phone}).sort("timestamp", -1)
    history = await cursor.to_list(length=20)
    
    # Clean MongoDB _id for JSON compatibility
    for item in history:
        item["_id"] = str(item["_id"])
        
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