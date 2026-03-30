from fastapi import APIRouter,HTTPException, Body
from app.services import policy
from app.services import gemini 
from app.models import ResponseModel
from typing import Dict,Any,Optional
import glob
import os
import json

router = APIRouter(tags=["Analyze"])

def get_lastest_snapshot_data() -> Dict[str,Any]:
    list_of_files = glob.glob("metrics/snapshot_*.json")

    if not list_of_files:
        raise HTTPException(
            status_code=404,
            detail="No snapshot found, run collector first"
        )

    lastest_file = max(list_of_files,key=os.path.getmtime)

    with open(lastest_file,"r") as f:
        return json.load(f)


@router.post("",response_model=ResponseModel)
async def analyze_snapshot(snapshot:Optional[Dict[str,Any]] = Body(None)):

    if not snapshot:
        snapshot = get_lastest_snapshot_data()

    alerts = policy.evaluate(snapshot)

    ai_analysis_text = gemini.analyze(snapshot,alerts)

    return ResponseModel(
        timestamp=snapshot.get("timestamp","unknown_time"),
        alerts=alerts,
        analysis=ai_analysis_text,
        model_used="gemini-2.5-flash"
    )


@router.get("/latest",response_model=ResponseModel)
async def analyze_latest():
    snapshot = get_lastest_snapshot_data()
    alerts= policy.evaluate(snapshot)
    ai_analysis_text = gemini.analyze(snapshot,alerts)

    return ResponseModel(
        timestamp=snapshot.get("timestamp","unknown_time"),
        alerts=alerts,
        analysis=ai_analysis_text,
        model_used="gemini-2.5-flash"
    )