import insightface
import cv2
import numpy as np
import os
import base64

FACE_EMBEDDING_SIZE = 512

model = insightface.app.FaceAnalysis()

def get_embedding(image_base64: str):
    """
    Accepts either:
    - a filename (str) relative to FACE_IMAGE_DIR
    - a cv2/numpy image (np.ndarray)

    Returns a 512-dim embedding list
    """
    model.prepare(ctx_id=0)

    image = base64_to_cv2(image_base64)

    faces = model.get(image)
    if not faces:
        raise ValueError("No face detected in image")

    embedding = faces[0]['embedding'].tolist()

    if len(embedding) != FACE_EMBEDDING_SIZE:
        raise ValueError(f"Embedding size mismatch: expected {FACE_EMBEDDING_SIZE}, got {len(embedding)}")

    return embedding

def base64_to_cv2(base64_str: str):
    # Remove data:image/...;base64, header if present
    if "," in base64_str:
        base64_str = base64_str.split(",", 1)[1]

    # Decode base64 to bytes
    image_bytes = base64.b64decode(base64_str)

    # Convert bytes to numpy array
    np_arr = np.frombuffer(image_bytes, np.uint8)

    # Decode to OpenCV image
    image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("Could not decode image")

    return image