import requests
from PIL import Image
import io
import insightface
import cv2
from PIL import Image, ImageOps
import io, base64

def load_and_encode_image(image_path: str) -> str:
    with Image.open(image_path) as img:
        img = ImageOps.exif_transpose(img)  # apply EXIF rotation before it gets stripped
        img = img.convert("RGB")
        buffer = io.BytesIO()
        img.save(buffer, format="JPEG")
        buffer.seek(0)
        return base64.b64encode(buffer.read()).decode("utf-8")


def enroll_person(image_path: str, first_name: str, last_name: str, url: str = "http://localhost:8000"):
    b64 = load_and_encode_image(image_path)

    payload = {
        "first_name": first_name,
        "last_name": last_name,
        "img_base64": b64
    }

    response = requests.post(f"{url}/enroll", json=payload)
    response.raise_for_status()
    return response.json()

def match_person(image_path: str, url: str = "http://localhost:8000"):
    b64 = load_and_encode_image(image_path)

    payload = {
        "img_base64": b64
    }

    response = requests.post(f"{url}/match", json=payload)
    response.raise_for_status()
    return response.json()


if __name__ == "__main__":
    # result = enroll_person(
    #     image_path="photo.jpg",   # path to your image
    #     first_name="John",
    #     last_name="Doe"
    # )
    result = match_person(
        image_path="photo2.jpg"
    )
    print("Uploaded successfully!")
    print(f"Result:  {result}")