from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime
from sqlalchemy.orm import sessionmaker, declarative_base
from datetime import datetime

# Define the SQLite database file
SQLALCHEMY_DATABASE_URL = "sqlite:///./mindmetrics.db"

# Create the SQLAlchemy engine
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- DATABASE MODELS ---

class MoodLog(Base):
    __tablename__ = "mood_logs"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=False) 
    mood_label = Column(String, index=True)
    journal_entry = Column(String)
    ai_score = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

class UserSettings(Base):
    __tablename__ = "user_settings"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, unique=True, index=True, nullable=False)
    share_with_therapist = Column(Boolean, default=False)
    push_notifications = Column(Boolean, default=True)

# NEW: Cache table to stop the AI from generating repetitive exercises
class UserCBT(Base):
    __tablename__ = "user_cbts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, unique=True, index=True, nullable=False)
    last_log_id = Column(Integer, nullable=True) # Tracks if they wrote a new journal
    exercises_json = Column(String) # Saves the exact AI output

# NEW: Therapist Profile Management
class TherapistProfile(Base):
    __tablename__ = "therapist_profiles"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, unique=True, index=True, nullable=False) # The Therapist's Firebase UID
    full_name = Column(String, default="New Therapist")
    specialization = Column(String, default="General Therapy")
    bio = Column(String, default="")
    contact_email = Column(String, default="")
    is_accepting_patients = Column(Boolean, default=True)

# NEW: Tracks which patients belong to which therapist
class PatientAssignment(Base):
    __tablename__ = "patient_assignments"
    id = Column(Integer, primary_key=True, index=True)
    therapist_id = Column(String, index=True, nullable=False) # Therapist's Firebase UID
    patient_id = Column(String, unique=True, index=True, nullable=False) # Patient's Firebase UID
    assigned_at = Column(DateTime, default=datetime.utcnow)

# --- INITIALIZATION ---
Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()