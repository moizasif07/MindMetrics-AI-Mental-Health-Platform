import os
from pathlib import Path
import pandas as pd
from dotenv import load_dotenv
from langchain_community.document_loaders import DataFrameLoader
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import FAISS

# Load your secure OpenAI API key
load_dotenv()

print("1. Loading CSV data...")
# Secure file path resolution
BASE_DIR = Path(__file__).resolve().parent
csv_path = BASE_DIR / "mental_health_conversations.csv"

if not csv_path.is_file():
    raise FileNotFoundError(f"Dataset missing: {csv_path}")

# Read the CSV file
df = pd.read_csv(csv_path)

# Validate required columns exist before processing
required = {"question", "answer"}
missing = required - set(df.columns)
if missing:
    raise ValueError(f"Missing columns: {sorted(missing)}")

# Clean the data by dropping empty rows
df = df.dropna(subset=["question", "answer"]).copy()

# Optional limit for testing (set EMBEDDING_ROW_LIMIT in .env), otherwise processes the full dataset
limit = int(os.getenv("EMBEDDING_ROW_LIMIT", "0"))
if limit > 0:
    print(f"Limiting to first {limit} rows for testing...")
    df = df.head(limit).copy()
else:
    print(f"Processing full dataset ({len(df)} rows)...")

print("2. Formatting text for RAG...")
# Combine the validated columns
df['combined_text'] = "User Issue: " + df['question'].astype(str) + "\nTherapist Advice: " + df['answer'].astype(str)

# Load the formatted text into LangChain Document objects
loader = DataFrameLoader(df, page_content_column="combined_text")
docs = loader.load()

print("3. Generating OpenAI Embeddings (This takes a few seconds)...")
# This converts the English text into math arrays
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
vector_db = FAISS.from_documents(docs, embeddings)

print("4. Saving Vector Database to disk...")
# Save the math arrays to a local folder 
vector_db.save_local("faiss_cbt_index")

print("Success! Vector DB built and saved to the 'faiss_cbt_index' folder.")