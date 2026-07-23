"""
FastAPI application serving predictions from the trained model.
it loads the saved model + scaler, exposes a /predict to make predictions
"""
from pathlib import Path
import pickle

import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ConfigDict
from enum import Enum
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error

# resolving all paths to make it accessible 
BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_PATH = BASE_DIR / "summative" / "model" / "reg_model.pkl"
SCALER_PATH = BASE_DIR / "summative" / "model" / "scaler.pkl"

# loading both the model and the scaler
with open(MODEL_PATH, "rb") as f:
    model = pickle.load(f)

with open(SCALER_PATH, "rb") as f:
    scaler = pickle.load(f)

# just a warning this order should match with the order of the model just for it to provide regit rsults
FEATURE_COLUMNS = [
    "Gender", "High_School_GPA", "SAT_Score", "University_GPA",
    "Internships_Completed", "Projects_Completed", "Certifications",
    "Soft_Skills_Score",
    "Field_of_Study_Business", "Field_of_Study_Computer Science",
    "Field_of_Study_Education", "Field_of_Study_Engineering",
    "Field_of_Study_Finance", "Field_of_Study_Law",
    "Field_of_Study_Marketing", "Field_of_Study_Medicine",
    "Field_of_Study_Nursing", "Field_of_Study_Psychology",
]

FIELD_OF_STUDY_CATEGORIES = [
    "Arts", "Business", "Computer Science", "Education", "Engineering",
    "Finance", "Law", "Marketing", "Medicine", "Nursing", "Psychology",
]


class GenderEnum(str, Enum):
    male = "Male"
    female = "Female"


class FieldOfStudyEnum(str, Enum):
    arts = "Arts"
    business = "Business"
    computer_science = "Computer Science"
    education = "Education"
    engineering = "Engineering"
    finance = "Finance"
    law = "Law"
    marketing = "Marketing"
    medicine = "Medicine"
    nursing = "Nursing"
    psychology = "Psychology"

# USING pydantic to define data fields, set automatic validation rules and create documentation for fields
class StudentData(BaseModel):
    gender: GenderEnum
    high_school_gpa: float = Field(..., ge=0, le=4.0, description="High school GPA (0-4.0)")
    sat_score: int = Field(..., ge=400, le=1600, description="SAT score (900-1600)")
    university_gpa: float = Field(..., ge=0, le=4.0, description="University GPA (2.0-4.0)")
    internships_completed: int = Field(..., ge=0, le=4, description="Number of internships (0-4)")
    projects_completed: int = Field(..., ge=0, le=9, description="Number of projects (0-9)")
    certifications: int = Field(..., ge=0, le=5, description="Number of certifications (0-5)")
    soft_skills_score: float = Field(..., ge=1, le=10, description="Soft skills score (1-10)")
    field_of_study: FieldOfStudyEnum

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "gender": "Male",
                "high_school_gpa": 3.6,
                "sat_score": 1400,
                "university_gpa": 3.4,
                "internships_completed": 2,
                "projects_completed": 5,
                "certifications": 2,
                "soft_skills_score": 7.5,
                "field_of_study": "Computer Science",
            }
        }
    )

class PredictionResponse(BaseModel):
    predicted_job_offers: float
    rounded_job_offers: int


app = FastAPI(
    title="Student Job Offer Predictor API",
    description="Predicts the expected number of job offers a student will "
                 "receive based on academic performance and extracurricular activity.",
    version="1.0.0",
)

# CORS reasoning:
# - allow_origins: restricted use other than "*", allow_methods: only GET and POST, allow_headers: "*" so the client can send Content-Type: application/json
#   and any auth headers added later without needing to enumerate each one, allow_credentials: False, since this API does not use cookies or
#   session-based auth 
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


def build_feature_vector(data: StudentData) -> pd.DataFrame:
    """
    Converts a validated StudentData request into the exact same numeric
    feature format the model was trained on: binary gender encoding +
    one-hot encoded field of study, in the exact FEATURE_COLUMNS order.
    """
    row = {col: 0 for col in FEATURE_COLUMNS}

    row["Gender"] = 1 if data.gender == GenderEnum.female else 0
    row["High_School_GPA"] = data.high_school_gpa
    row["SAT_Score"] = data.sat_score
    row["University_GPA"] = data.university_gpa
    row["Internships_Completed"] = data.internships_completed
    row["Projects_Completed"] = data.projects_completed
    row["Certifications"] = data.certifications
    row["Soft_Skills_Score"] = data.soft_skills_score

    # Only set a dummy column to 1 if the field isn't the dropped baseline ("Arts")
    dummy_col = f"Field_of_Study_{data.field_of_study.value}"
    if dummy_col in row:
        row[dummy_col] = 1

    return pd.DataFrame([row], columns=FEATURE_COLUMNS)


@app.get("/")
def root():
    return {"message": "Student Job Offer Predictor API. Visit /docs for Swagger UI."}


@app.post("/predict", response_model=PredictionResponse)
def predict(data: StudentData):
    """
    Predicts the number of job offers for a single student profile.
    Pydantic has already validated datatypes and ranges before this runs -
    anything reaching here is guaranteed well-formed.
    """
    try:
        features_df = build_feature_vector(data)
        features_scaled = scaler.transform(features_df)
        prediction = model.predict(features_scaled)[0] 
        clipped = float(np.clip(prediction, 0, 5))

        return PredictionResponse(
            predicted_job_offers=round(clipped, 2),
            rounded_job_offers=round(clipped),
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("prediction:app", host="0.0.0.0", port=8000, reload=True)