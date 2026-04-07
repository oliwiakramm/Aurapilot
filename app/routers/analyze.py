from fastapi import APIRouter,HTTPException, Body
from app.services import policy
from app.services import gemini 
from app.models import ResponseModel
from typing import Dict,Any,Optional
import glob
import os
import json

router = APIRouter(tags=["Analyze"])

def get_latest_snapshot_data() -> Dict[str,Any]:
    """
    Retrieves the most recent system metrics snapshot from the local storage.
    
    Searches the 'metrics/' directory for JSON files matching the snapshot pattern
    and returns the contents of the file with the latest modification time.
    
    Returns:
        Dict[str, Any]: The parsed JSON data from the latest snapshot file.

    Raises:
        HTTPException: 404 error if no metrics files exist.
        
    """

    list_of_files = glob.glob("metrics/snapshot_*.json")


    if not list_of_files:
        raise HTTPException(
            status_code=404, 
            detail="No snapshot found, run collector first"
        )

    lastest_file = max(list_of_files,key=os.path.getmtime)

    with open(lastest_file,"r") as f:
        return json.load(f)
    

def run_analysis(snapshot):
    alerts = policy.evaluate(snapshot)

    ai_analysis_text = gemini.analyze(snapshot,alerts)

    return ResponseModel(
        timestamp=snapshot.get("timestamp","unknown_time"),
        alerts=alerts,
        analysis=ai_analysis_text,
        model_used="gemini-2.5-flash"
    )


@router.post("",response_model=ResponseModel)
async def analyze_snapshot(snapshot:Optional[Dict[str,Any]] = Body(None)):
    """
    Analyzes a provided system snapshot or the latest available one.
    
    If no snapshot is provided in the request body, the endpoint automatically
    fetches the most recent snapshot from the disk. It then evaluates the data 
    against defined policies and generates an AI-driven analysis using Gemini.
    
    Args:
        snapshot (Optional[Dict[str, Any]]): The system metrics to analyze.
        
    Returns:
        ResponseModel: A structured object containing the timestamp, detected alerts, 
                      AI analysis text, and the model metadata.
    """

    if not snapshot:
        snapshot = get_latest_snapshot_data()

    return run_analysis(snapshot)




@router.get("/latest",response_model=ResponseModel)
async def analyze_latest():
    """
    Performs an analysis on the most recently collected system snapshot.
    
    This endpoint is a convenience wrapper that forces the use of the latest 
    stored metrics. It evaluates the system health and provides AI insights.
    
     Returns:
        ResponseModel: A structured object containing the timestamp, detected alerts, 
                      AI analysis text, and the model metadata.
        
    """
    snapshot = get_latest_snapshot_data()

    return run_analysis(snapshot)