from pydantic import BaseModel
from typing import List, Optional, Dict, Any

class AlertModel(BaseModel):
    severity:str
    name:str
    message:str


class ResponseModel(BaseModel):
    timestamp:str
    alerts:List[AlertModel]
    analysis:str
    model_used:str
