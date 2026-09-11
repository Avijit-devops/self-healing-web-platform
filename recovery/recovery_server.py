from flask import Flask, request, jsonify
from pathlib import Path
import subprocess

app = Flask(__name__)

#RECOVERY_SCRIPT = "/home/user/devops-projects/self-healing-platform/scripts/recover-app.sh"
BASE_DIR = Path(__file__).resolve().parent.parent
RECOVERY_SCRIPT = BASE_DIR / "scripts" / "recover-app.sh"

@app.route("/recover", methods=["POST"])
def recover():
    data = request.get_json(silent=True) or {}

    print("Received Alertmanager webhook")
    print(data)

    alerts = data.get("alerts", [])

    for alert in alerts:
        status = alert.get("status")
        alertname = alert.get("labels", {}).get("alertname")

        print(f"Alert: {alertname}, Status: {status}")

        # Recover only when our ApplicationDown alert is firing.
        if alertname == "ApplicationDown" and status == "firing":
            result = subprocess.run(
                [RECOVERY_SCRIPT],
                capture_output=True,
                text=True
            )

            print(result.stdout)

            if result.returncode != 0:
                print(result.stderr)
                return jsonify({
                    "status": "failed",
                    "message": "Recovery script failed"
                }), 500

            return jsonify({
                "status": "success",
                "message": "Application recovery executed"
            }), 200

    return jsonify({
        "status": "ignored",
        "message": "No actionable ApplicationDown firing alert found"
    }), 200


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
