import pandas as pd
from dotenv import load_dotenv
from langchain_community.document_loaders import DataFrameLoader
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import FAISS

# Load your secure OpenAI API key
load_dotenv()

print("1. Loading CSV data...")
# Read the CSV file
df = pd.read_csv("mental_health_conversations.csv")

# CRITICAL: Grab only the first 100 rows and copy them to avoid pandas warnings
df_sample = df.head(100).copy()

print("2. Formatting text for RAG...")
# We updated the column names here to 'question' and 'answer'!
df_sample['combined_text'] = "User Issue: " + df_sample['question'].astype(str) + "\nTherapist Advice: " + df_sample['answer'].astype(str)

# Load the formatted text into LangChain Document objects
loader = DataFrameLoader(df_sample, page_content_column="combined_text")
docs = loader.load()

print("3. Generating OpenAI Embeddings (This takes a few seconds)...")
# This converts the English text into math arrays
embeddings = OpenAIEmbeddings(model="text-embedding-3-small") # specifying a fast, cheap embedding model
vector_db = FAISS.from_documents(docs, embeddings)

print("4. Saving Vector Database to disk...")
# Save the math arrays to a local folder 
vector_db.save_local("faiss_cbt_index")

print("Success! Vector DB built and saved to the 'faiss_cbt_index' folder.")