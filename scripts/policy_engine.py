import yaml
import json
import sys


def get_key_value(data,metric_path):
    """Retrieves a value from a nested dictionary using dot notation."""
    keys = metric_path.split(".")
    for key in keys:
        if isinstance(data,dict):
            data = data.get(key)
        else:
            return None
    return data

def evaluate_rule(actual_value,operator,threshold):
    """Compares the value with the threshold using the specified operator"""
    if operator == ">=":
        return actual_value >= threshold
    elif operator == ">":
        return actual_value > threshold
    elif operator == "<":
        return actual_value < threshold
    elif operator == "==":
        return actual_value == threshold
    return False


def run_policy_engine(snapshot_path):
    with open(snapshot_path,"r") as f:
        current_metrics = json.load(f)

    with open("config/rules.yaml","r") as file:
        rules_config = yaml.safe_load(file)

    alerts_triggered = []

    for rule in rules_config["alerts"]:
        actual_value = get_key_value(current_metrics,rule["metric"])

        if actual_value is None:
            print(f"[WARN] Metric not found in snapshot: {rule['metric']}")
            continue

        if evaluate_rule(actual_value,rule["operator"],rule["threshold"]):
            alerts_triggered.append(rule)
            print(f"[{rule['severity']}] {rule['name']}: "
                  f"{actual_value} {rule['operator']} {rule['threshold']}")
            print(f"  Message: {rule['message']}\n")
    
    if not alerts_triggered:
        print("All systems are good. No alerts triggered")
    else:
        print(f"--- {len(alerts_triggered)} alert(s) triggered ---")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/policy_engine.py metrics/snapshot_xyz.json")
        sys.exit(1)
    snapshot_path = sys.argv[1]
run_policy_engine(snapshot_path)
