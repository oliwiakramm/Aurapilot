from fastapi import FastAPI
from app.routers import analyze

app = FastAPI(
    title="Aurapilot API",
    version="0.1.0"
)

@app.get("/health",tags=["System"])
async def health_check():
    """
     A simple endpoint that checks whether the application is running.
    Used by the healthcheck.sh script.
    """
    return {"status":"ok","version":"0.1.0"}

app.include_router(analyze.router,prefix="/analyze")