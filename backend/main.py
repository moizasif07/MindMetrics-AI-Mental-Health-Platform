import os
import json
from datetime import datetime, time
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
from sqlalchemy.orm import Session

# Cleaned up imports: Everything is imported exactly once
from database import SessionLocal, engine, MoodLog, UserSettings, UserCBT, TherapistProfile, PatientAssignment, get_db

# Modern LangChain imports
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_community.vectorstores import FAISS

# Load secure .env file
load_dotenv()

app = FastAPI(title="MindMetrics API with RAG & Scoring")

# Initialize OpenAI components matching your embedding script
llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.5)
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")

vector_db = None

@app.on_event("startup")
def initialize_vector_db():
    global vector_db
    print("Loading pre-built FAISS Vector Database from disk...")
    # Load the local FAISS folder you built earlier
    vector_db = FAISS.load_local(
        "faiss_cbt_index", 
        embeddings, 
        allow_dangerous_deserialization=True 
    )
    print("Database loaded and ready for semantic search!")


# --- DATA MODELS ---

class MoodLogRequest(BaseModel):
    user_id: str  # Added to track which patient is sending the journal
    mood: str
    notes: str

class CBTExerciseResponse(BaseModel):
    title: str
    focus: str
    duration: str
    completed: bool
    description: str

class SettingsUpdate(BaseModel):
    share_with_therapist: bool
    push_notifications: bool

class TherapistProfileUpdate(BaseModel):
    full_name: str
    specialization: str
    bio: str
    contact_email: str
    is_accepting_patients: bool    

class AssignPatientRequest(BaseModel):
    therapist_id: str
    patient_id: str


# --- ENDPOINTS ---

@app.post("/analyze-mood")
def analyze_mood(log: MoodLogRequest, db: Session = Depends(get_db)):
    global vector_db
    
    # 1. Direct RAG Retrieval (NO HISTORY - Current Prompt Only)
    query = f"The user is feeling {log.mood}. Notes: {log.notes}"
    relevant_docs = vector_db.similarity_search(query, k=1)
    cbt_context = relevant_docs[0].page_content if relevant_docs else "No specific guideline found."
    
    # 2. AI Prompt (Focused strictly on the current entry)
    rag_prompt = f"""
    You are an AI therapist advisor for MindMetrics. 
    
    CURRENT ENTRY ONLY:
    The user is experiencing: {log.mood}. 
    User notes: '{log.notes}'.
    
    Strictly use the following pre-approved therapeutic guideline to inform your advice:
    "{cbt_context}"
    
    Instructions:
    1. Calculate a 'Mental Wellness Score' from 0 to 100 based on the severity of their current mood.
    2. Provide a short, highly empathetic response to THIS specific entry.
    3. If the score is BELOW 50, explicitly provide a cognitive behavioral therapy exercise targeting THIS specific entry. If 50 or above, just provide supportive advice.
    4. If the score is BELOW 30, you MUST also explicitly suggest that they consult a professional therapist on the platform.
    5. Include a brief disclaimer at the end stating this is supportive guidance, not a medical diagnosis.
    
    Return your final response strictly as a JSON object with the exact keys: 
    "wellness_score" (integer), 
    "empathetic_response" (string), 
    "cbt_exercise" (string or null), 
    "professional_referral" (boolean true/false), 
    "disclaimer" (string).
    """
    
    # 3. Generate response
    response = llm.invoke(rag_prompt)
    
    # 4. Clean up JSON and Save to Database
    try:
        clean_json = response.content.replace("```json", "").replace("```", "").strip()
        ai_data = json.loads(clean_json)
        
        # Save to DB so the CBT endpoint can read it later
        new_log = MoodLog(
            user_id=log.user_id,
            mood_label=log.mood,
            journal_entry=log.notes,
            ai_score=ai_data.get("wellness_score", 0) 
        )
        
        db.add(new_log)
        db.commit()
        db.refresh(new_log)
        
    except Exception as e:
        ai_data = {"error": "Failed to parse AI JSON or save to Database", "raw_text": str(e)}
    
    return {
        "status": "success",
        "user_mood": log.mood,
        "retrieved_knowledge": cbt_context,
        "ai_analysis": ai_data
    }


@app.get("/mood-logs")
def get_mood_logs(user_id: str, db: Session = Depends(get_db)):
    # Fetch the 7 most recent logs for THIS specific user
    logs = db.query(MoodLog).filter(MoodLog.user_id == user_id)\
        .order_by(MoodLog.created_at.desc()).limit(7).all()
    
    print(f"\n📊 Analytics fetch for user {user_id}: Found {len(logs)} logs.")
    
    # Reverse them so they graph left-to-right (oldest to newest)
    logs.reverse() 
    
    history = []
    for log in logs:
        # Fallback if created_at is somehow null to prevent crashing
        date_str = log.created_at.strftime("%a") if log.created_at else "Today"
        history.append({
            "id": log.id,
            "mood": log.mood_label,
            "score": log.ai_score,
            "date": date_str
        })
        
    return {"status": "success", "history": history}


@app.get("/cbt-exercises", response_model=list[CBTExerciseResponse])
def get_personalized_cbt(user_id: str, db: Session = Depends(get_db)):
    # 1. Fetch the 3 most recent journal entries for historical context
    recent_logs = db.query(MoodLog).filter(
        MoodLog.user_id == user_id,
        MoodLog.journal_entry.isnot(None),
        MoodLog.journal_entry != ""
    ).order_by(MoodLog.created_at.desc()).limit(3).all()

    # Determine the ID of the absolute latest thing they wrote
    latest_log_id = recent_logs[0].id if recent_logs else 0

    # 2. STRICT CACHE CHECK
    cached_cbt = db.query(UserCBT).filter(UserCBT.user_id == user_id).first()
    
    cached_id = cached_cbt.last_log_id if cached_cbt else None
    print(f"\n🔍 CBT Check - User: {user_id} | Latest Log ID in DB: {latest_log_id} | Cached Log ID: {cached_id}")
    
    if cached_cbt and cached_cbt.last_log_id == latest_log_id:
        print(f"✅ CACHE HIT for User {user_id}: No new journals. Returning saved exercises.")
        return json.loads(cached_cbt.exercises_json)

    print(f"⚠️ CACHE MISS for User {user_id}: New journal detected (Log ID: {latest_log_id}). Asking AI to generate new exercises...")
    
    # 3. Compile the context for the LLM
    if not recent_logs:
        journal_context = "The user has no recent journal entries. Provide general, foundational CBT exercises for daily mental wellness."
    else:
        journal_context = " ".join([f"- {log.journal_entry}" for log in recent_logs])

    # 4. The Prompt
    cbt_prompt = f"""
    You are an expert cognitive behavioral therapist for the MindMetrics app. 
    Analyze the following recent journal entries from a patient and generate 3 personalized CBT exercises to help them.
    
    Patient Journal Context:
    {journal_context}
    
    You must respond ONLY with a valid JSON array of objects. Do not include any markdown formatting, greetings, or additional text.
    The JSON must strictly follow this exact structure:
    [
        {{
            "title": "Exercise Name",
            "focus": "What issue this targets (e.g., Anxiety, Low Energy)",
            "duration": "10 mins",
            "completed": false,
            "description": "A 2-sentence explanation of how the patient should perform this exercise."
        }}
    ]
    """
    
    try:
        # 5. Invoke LangChain
        raw_response = llm.invoke(cbt_prompt)
        response_text = raw_response.content if hasattr(raw_response, 'content') else str(raw_response)
        
        # 6. Clean the output
        clean_json = response_text.replace("```json", "").replace("```", "").strip()
        exercises = json.loads(clean_json) 
        
        # 7. SAVE TO CACHE
        if not cached_cbt:
            cached_cbt = UserCBT(user_id=user_id, last_log_id=latest_log_id, exercises_json=clean_json)
            db.add(cached_cbt)
        else:
            cached_cbt.last_log_id = latest_log_id
            cached_cbt.exercises_json = clean_json
            
        db.commit()
        print(f"✅ Successfully cached new exercises for Log ID: {latest_log_id}")
        
        return exercises
        
    except json.JSONDecodeError as e:
        print(f"\n--- JSON PARSING ERROR ---")
        print(f"Failed to parse this string: {clean_json}")
        raise HTTPException(status_code=500, detail="The AI failed to format the exercises correctly.")

    
@app.get("/settings")
def get_settings(user_id: str, db: Session = Depends(get_db)):
    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()
    if not settings:
        # Create default settings if they don't exist yet
        settings = UserSettings(user_id=user_id, share_with_therapist=False, push_notifications=True)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    
    return {
        "share_with_therapist": settings.share_with_therapist,
        "push_notifications": settings.push_notifications
    }


@app.post("/settings")
def update_settings(user_id: str, req: SettingsUpdate, db: Session = Depends(get_db)):
    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()
    if not settings:
        settings = UserSettings(user_id=user_id)
        db.add(settings)
    
    settings.share_with_therapist = req.share_with_therapist
    settings.push_notifications = req.push_notifications
    
    db.commit()
    return {"status": "success", "message": "Settings updated securely."}


@app.get("/therapist/profile")
def get_therapist_profile(user_id: str, db: Session = Depends(get_db)):
    profile = db.query(TherapistProfile).filter(TherapistProfile.user_id == user_id).first()
    
    # Auto-create a blank profile if they log in for the first time
    if not profile:
        profile = TherapistProfile(user_id=user_id)
        db.add(profile)
        db.commit()
        db.refresh(profile)
        
    return profile

@app.put("/therapist/profile")
def update_therapist_profile(user_id: str, req: TherapistProfileUpdate, db: Session = Depends(get_db)):
    profile = db.query(TherapistProfile).filter(TherapistProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")
        
    profile.full_name = req.full_name
    profile.specialization = req.specialization
    profile.bio = req.bio
    profile.contact_email = req.contact_email
    profile.is_accepting_patients = req.is_accepting_patients
    
    db.commit()
    return {"status": "success", "message": "Profile updated successfully."}

@app.get("/therapist/patients")
def get_assigned_patients_dashboard(therapist_id: str, db: Session = Depends(get_db)):
    """Fetches all assigned patients and calculates high-risk alerts."""
    assignments = db.query(PatientAssignment).filter(PatientAssignment.therapist_id == therapist_id).all()
    
    dashboard_data = []
    
    for a in assignments:
        patient_id = a.patient_id
        
        settings = db.query(UserSettings).filter(UserSettings.user_id == patient_id).first()
        consent_given = settings.share_with_therapist if settings else False
        
        if not consent_given:
            dashboard_data.append({
                "patient_id": patient_id,
                "status": "Private (User Disabled Sharing)",
                "high_risk_alerts": 0,
                "latest_mood": "Hidden"
            })
            continue # Skip reading their logs!
            
        logs = db.query(MoodLog).filter(MoodLog.user_id == patient_id).order_by(MoodLog.created_at.desc()).limit(7).all()
        
        # Calculate how many logs dropped below the critical score of 30
        high_risk_alerts = sum(1 for log in logs if log.ai_score < 30)
        latest_mood = logs[0].mood_label if logs else "No recent logs"
        
        dashboard_data.append({
            "patient_id": patient_id,
            "status": "Active",
            "high_risk_alerts": high_risk_alerts,
            "latest_mood": latest_mood
        })
        
    return {"assigned_patients": dashboard_data}


@app.post("/therapist/assign")
def assign_patient(req: AssignPatientRequest, db: Session = Depends(get_db)):
    # Check if assignment already exists to prevent duplicates
    existing = db.query(PatientAssignment).filter(
        PatientAssignment.therapist_id == req.therapist_id,
        PatientAssignment.patient_id == req.patient_id
    ).first()
    
    if existing:
        return {"status": "success", "message": "Patient already assigned."}
        
    new_assignment = PatientAssignment(
        therapist_id=req.therapist_id, 
        patient_id=req.patient_id
    )
    db.add(new_assignment)
    db.commit()
    
    return {"status": "success", "message": f"Patient {req.patient_id} assigned to Therapist {req.therapist_id}"}

@app.get("/therapist/patients/{patient_id}/reports")
def get_patient_detailed_reports(patient_id: str, therapist_id: str, db: Session = Depends(get_db)):
    """Allows a therapist to view full journal entries ONLY if authorized."""
    
    assignment = db.query(PatientAssignment).filter(
        PatientAssignment.therapist_id == therapist_id,
        PatientAssignment.patient_id == patient_id
    ).first()
    
    if not assignment:
        raise HTTPException(status_code=403, detail="Security Error: Patient is not assigned to you.")
        
    # 2. Verify Patient Consent
    settings = db.query(UserSettings).filter(UserSettings.user_id == patient_id).first()
    if not settings or not settings.share_with_therapist:
        raise HTTPException(status_code=403, detail="Privacy Lock: Patient has turned off data sharing.")
        
    # 3. Return full history
    logs = db.query(MoodLog).filter(MoodLog.user_id == patient_id).order_by(MoodLog.created_at.desc()).all()
    
    return {
        "patient_id": patient_id,
        "total_entries": len(logs),
        "history": [
            {
                "date": log.created_at.strftime("%b %d, %Y - %H:%M"),
                "mood": log.mood_label,
                "journal": log.journal_entry,
                "ai_score": log.ai_score
            } for log in logs
        ]
    }