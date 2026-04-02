from dotenv import load_dotenv
import os
from google import genai
from google.genai import types
from typing import Dict,Any,List
from app.models import AlertModel


load_dotenv()

gemini_api_key = os.getenv("GEMINI_API_KEY")

if not gemini_api_key:
    raise ValueError(
        "GEMINI_API_KEY not found."
        "Add it to .env file or set it as environment variable."
    )

client = genai.Client(api_key=gemini_api_key)

def build_prompt(snapshot:Dict[str,Any],alerts:List[AlertModel]) -> str:
    """
    Generates a structured prompt for AI system analysis.

    Converts raw system metrics and active alerts into a formatted 
    instruction string for a Linux Administrator AI model.

    Args:
        snapshot (Dict[str, Any]): Dictionary containing CPU, RAM, Disk, and process metrics.
        alerts (List[AlertModel]): List of triggered system alert objects.

    Returns:
        str: A multi-line prompt ready for the LLM, including metrics and diagnostics instructions.
    """
    cpu = snapshot.get("cpu",{})
    ram = snapshot.get("ram",{})
    disk = snapshot.get("disk",{})
    top = snapshot.get("top_processes",{})

    if alerts:
        alerts_str = "\n".join([f"[{a.severity}] {a.name}: {a.message}" for a in alerts])
    else:
        alerts_str = "No alerts triggered."

    top_cpu = top.get("by_cpu", [])
    top_str = "\n".join([
        f"  - {p.get('name', 'N/A')} (cpu: {p.get('cpu', 0)}%, mem: {p.get('mem', 0)}%)"
        for p in top_cpu[:3]
    ])

    prompt = f"""You are a Linux system administrator analyzing infrastructure metrics
    SYSTEM METRICS:
    - CPU usage: {cpu.get('usage_percent')}% (cores: {cpu.get('cores')})
    - Load average: {cpu.get('load_avg', {}).get('1min')} (1min)
    - RAM used: {ram.get('used_percent')}% ({ram.get('used_gb')}GB / {ram.get('total_gb')}GB)
    - Disk used: {disk.get('used_percent')}% 
    - Uptime: {snapshot.get('uptime_seconds')} seconds

    TOP PROCESSES BY CPU:
    {top_str}

    ACTIVE ALERTS:
    {alerts_str}

    INSTRUCTION:
    Summarize the diagnosis in maximum 5 points.
    Each point must cover: problem, possible cause, recommendation.
    Reply in English, be concise.
    """
    return prompt

def analyze(snapshot:Dict[str,Any],alerts: List[AlertModel]) -> str:
    """
    Generates a technical AI diagnosis based on system metrics and active alerts.

    Integrates snapshot data with pre-evaluated alerts to build a specialized 
    prompt, then queries the Gemini model for a concise summary and recommendations.

    Args:
        snapshot (Dict[str, Any]): Dictionary containing system telemetry (CPU, RAM, Disk).
        alerts (List[AlertModel]): List of previously identified system issues.

    Returns:
        str: The AI-generated diagnostic text or a formatted error message.
    """
    full_prompt = build_prompt(snapshot,alerts)

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            config=types.GenerateContentConfig(
                temperature=0.2, 
            ),
            contents=full_prompt
        )

        return response.text
    except Exception as e:
        return f"Error: Something went wrong while communicating with AI: {e}"