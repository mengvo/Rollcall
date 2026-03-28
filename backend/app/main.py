from fastapi import FastAPI
from schemas import EnrollIn
from db import get_connection
import psycopg2
from dotenv import load_dotenv
import os

app = FastAPI()

load_dotenv()

@app.get("/")
def home():
    connection = get_connection()
    return {"Hello": "World"}


def store_image(person: EnrollIn):
    pass