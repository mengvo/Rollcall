from pydantic import BaseModel

class EnrollIn(BaseModel):
    first_name: str
    last_name: str
    img_base64: str