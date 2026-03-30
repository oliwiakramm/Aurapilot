from pydantic import BaseModel
from typing import List, Optional, Dict, Any

class AlertModel(BaseModel):
    severity:str
    name:str
    message:str

class AnalyzeRequest(BaseModel):
    snapshot:Optional[Dict[str,Any]] = None

class ResponseModel(BaseModel):
    timestamp:str
    hostname:str
    alerts:List[AlertModel]
    analysis:str
    model_used:str
