from typing import Dict,Any
from scripts.policy_engine import get_alerts


def evaluate(snapshot:Dict[str,Any]):
    """
    Evokes get_alerts which processes the raw system snapshot to detect anomalies and 
    returns a list of triggered alert objects.

    Args:
        snapshot (Dict[str, Any]): Raw system metrics (CPU, RAM, Disk).

    Returns:
        List[AlertModel]: List of detected alerts or an empty list if none found.
    """
    return get_alerts(snapshot)