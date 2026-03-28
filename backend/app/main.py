from fastapi import FastAPI, HTTPException
from schemas import EnrollIn, MatchIn
from db import get_connection
import psycopg2
from dotenv import load_dotenv
import os
from supabase import create_client
import base64
import uuid
from face import get_embedding

load_dotenv()
app = FastAPI()
supabase = create_client(os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_KEY"))



@app.get("/")
def home():
    return {"Hello": "World"}

@app.post("/enroll")
def enroll_person(person: EnrollIn):
    try:
        # Strip data URI prefix if present e.g. "data:image/jpeg;base64,/9j/..."
        b64_data = person.img_base64
        if "," in b64_data:
            b64_data = b64_data.split(",")[1]

        image_bytes = base64.b64decode(b64_data)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 string")

    # Upload to Supabase
    try:
        file_name = f"{person.first_name}-{person.last_name}-{uuid.uuid4()}.jpg"

        supabase.storage.from_("face").upload(
            path=file_name,
            file=image_bytes,
            file_options={"content-type": "image/jpeg", "upsert": "true"}
        )

        
        public_url = supabase.storage.from_("face").get_public_url(file_name)

        face_embedding = get_embedding(person.img_base64)

        first_name = person.first_name
        last_name = person.last_name
        print(face_embedding)

        supabase.table("person").insert({
            "first_name": first_name,
            "last_name": last_name,
            "embedding": face_embedding,
            "image_url": file_name
        }).execute()

    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/match")
def match_person(person: MatchIn):
    try:
        embedding = get_embedding(person.img_base64)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        result = supabase.rpc("match_person", {
            "query_embedding": embedding,
            "match_threshold": 0.5,
            "match_count": 1
        }).execute()

        if not result.data:
            raise HTTPException(status_code=404, detail="No matching person found")

        return result.data[0]

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))