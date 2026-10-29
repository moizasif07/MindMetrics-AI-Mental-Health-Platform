# MindMetrics AI Mental Health Platform

MindMetrics is an AI-powered mental health monitoring and therapist advisory platform that enables users to track moods, maintain journals, receive personalized wellness insights, and access CBT-based guidance. Built with FastAPI, PostgreSQL/SQLite, Firebase, and OpenAI, it supports role-based access for users, therapists, and administrators.

## 🚀 Tech Stack

* **Frontend:** Flutter (iOS & Android)
* **Backend:** Python, FastAPI, SQLAlchemy
* **AI & NLP:** OpenAI API, FAISS (Vector Database), LangChain
* **Authentication & Cloud DB:** Firebase Auth & Firestore

---

## 🛠 Prerequisites

Before running the project, ensure you have the following installed and configured:

* **Flutter SDK** (Latest stable version)
* **Python 3.9+**
* **Firebase Account** (for Authentication and Firestore)
* **OpenAI API Key** (for CBT AI features)

---

## 📦 Setup Instructions

### 1. Firebase Configuration

This project requires a completely fresh Firebase environment to ensure data privacy and correct ownership.

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
2. Register an Android app and an iOS app using the project's bundle ID (e.g., `com.example.mindmetrics`).
3. Download the generated configuration files:
* Place `google-services.json` inside `mindmetrics_app/android/app/`
* Place `GoogleService-Info.plist` inside `mindmetrics_app/ios/Runner/`


4. In the Firebase Console, enable **Authentication** (Email/Password provider).
5. Enable **Firestore Database** and set up your initial security rules to require authentication.

### 2. Backend Setup (FastAPI)

The backend manages the AI interactions, vector embeddings, and relational data.

1. Navigate to the backend directory:
```bash
cd backend

```


2. Create and activate a Python virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows use: venv\Scripts\activate

```


3. Install the required Python dependencies:
```bash
pip install -r requirements.txt

```


4. Set up the environment variables:
* Duplicate the `backend/.env.example` file and rename it to `.env`.
* Open `.env` and insert your production OpenAI API Key and Database URL.


5. **Generate AI Vector Embeddings:** Run the vector database builder script to process the raw CSV data into a FAISS index. This must be run once before starting the server.
```bash
python build_vector_db.py

```


6. Start the backend server:
```bash
uvicorn main:app --reload

```



### 3. Frontend Setup (Flutter)

The frontend connects to your newly configured Firebase project and the FastAPI backend.

1. Navigate to the frontend directory:
```bash
cd mindmetrics_app

```


2. Set up the environment variables:
* Duplicate the `mindmetrics_app/.env.example` file and rename it to `.env`.
* Open `.env` and set `API_BASE_URL` to your backend's URL (e.g., `[http://10.0.2.2:8000](http://10.0.2.2:8000)` for Android emulator, or your live production URL).


3. Fetch the Flutter dependencies:
```bash
flutter pub get

```


4. Run the application:
```bash
flutter run

```



---

## 👑 Initial Admin Account Setup

Because the database is provisioned from scratch, the first administrator account must be elevated manually.

1. Launch the Flutter app and register a new account normally through the sign-up screen.
2. Log in to your Firebase Console or Backend Database viewer (depending on where your app manages user roles).
3. Locate your newly registered user document/record.
4. Manually add or update the role field to grant admin privileges (e.g., set `is_admin: true` or `role: "admin"`).
5. Restart the app. Your account will now have full access to the administrative dashboards.