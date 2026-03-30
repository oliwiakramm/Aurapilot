import yaml
import json
import sys

SEVERITY_ICONS = {
    "CRITICAL": "🔴",
    "WARNING":  "🟡",
    "INFO":     "🔵"
}

SEVERITY_ORDER = {"CRITICAL": 0, "WARNING": 1, "INFO": 2}


def get_nested_value(data, metric_path):
    """
    Retrieves a value from a nested dictionary using dot notation.
    Special cases:
    - disk.used_percent → iterates over the list of partitions and returns the maximum value
    - system_errors.count → counts the elements in the error array
    """
    keys = metric_path.split(".")

    if keys[0] == "system_errors" and keys[-1] == "count":
        errors = data.get("system_errors", [])
        return len(errors)

    value = data
    for key in keys:
        if isinstance(value, list):
            values = [item.get(key) for item in value if isinstance(item, dict)]
            values = [v for v in values if v is not None]
            return max(values) if values else None
        elif isinstance(value, dict):
            value = value.get(key)
        else:
            return None
    return value


def evaluate_rule(actual_value, operator, threshold):
    """Compares the value with the threshold using the specified operator."""
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

    with open(snapshot_path, "r") as f:
        metrics = json.load(f)

    with open("config/rules.yaml", "r") as f:
        config = yaml.safe_load(f)

    triggered = []
    not_found = []

    for rule in config["alerts"]:
        actual_value = get_nested_value(metrics, rule["metric"])

        if actual_value is None:
            not_found.append(rule["metric"])
            continue

        if evaluate_rule(actual_value, rule["operator"], rule["threshold"]):
            triggered.append({
                "rule": rule,
                "actual_value": actual_value
            })

    triggered.sort(key=lambda x: SEVERITY_ORDER.get(x["rule"]["severity"], 99))

    print("\n========== AURAPILOT POLICY ENGINE ==========")
    print(f"Snapshot: {snapshot_path}")
    print(f"Rules evaluated: {len(config['alerts'])}")
    print("=" * 46)

    if not triggered:
        print("\n✅ All systems nominal. No alerts triggered.\n")
    else:
        print(f"\n{len(triggered)} alert(s) triggered:\n")
        for item in triggered:
            rule = item["rule"]
            value = item["actual_value"]
            icon = SEVERITY_ICONS.get(rule["severity"], "⚪")

            print(f"{icon} {rule['severity']} — {rule['name']}")
            print(f"   Metric:    {rule['metric']}")
            print(f"   Value:     {value} {rule['operator']} {rule['threshold']}")
            print(f"   Message:   {rule['message']}")
            print()

    if not_found:
        print("⚠️  Metrics not found in snapshot:")
        for m in not_found:
            print(f"   - {m}")
        print()

    print(f"{'=' * 46}\n")
    return len(triggered)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/policy_engine.py metrics/snapshot_xyz.json")
        sys.exit(1)

    alerts_count = run_policy_engine(sys.argv[1])

    sys.exit(2 if alerts_count > 0 else 0)