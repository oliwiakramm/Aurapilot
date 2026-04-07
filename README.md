
# Aurapilot 🖥️

![Google Gemini](https://img.shields.io/badge/Google%20Gemini-4285F4?style=for-the-badge&logo=googlegemini&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![Bash](https://img.shields.io/badge/CLI-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Jenkins](https://img.shields.io/badge/jenkins-%232C5263.svg?style=for-the-badge&logo=jenkins&logoColor=white)
![Robot Framework](https://img.shields.io/badge/Robot%20Framework-000000?style=for-the-badge&logo=robotframework&logoColor=white)


**AI-Powered Infrastructure Health Monitor** — a REST API that collects Linux system metrics, evaluates them against a policy-as-code ruleset, and uses the Gemini AI model to generate human-readable infrastructure diagnostics.

---


### Data flow

```
collector.sh → snapshot JSON → policy_engine.py → alerts
                                                       │
                                                       ▼
                                              Gemini API prompt
                                                       │
                                                       ▼
                                         /analyze response (JSON)
```

---

## Features

- **Linux metric collection** via `/proc` filesystem — CPU, RAM, swap, disk, network, top processes
- **Policy-as-code** — alert thresholds defined in `config/rules.yaml`, evaluated before every AI call
- **AI diagnostics** — Gemini analyzes the snapshot and triggered alerts, returns concise recommendations
- **REST API** — two endpoints: `POST /analyze` (accepts snapshot in body or reads latest from disk), `GET /health`
- **CLI** — `aurapilot.sh` wraps all operations into simple commands
- **CI/CD pipeline** — Jenkins pipeline with build, validate, test, deploy, and BDD stages
- **BDD tests** — Robot Framework scenarios for API behaviour

---

## Project structure

```
aurapilot/
├── app/
│   ├── main.py              # FastAPI entrypoint
│   ├── models.py            # Pydantic request/response models
│   ├── routers/
│   │   └── analyze.py       # /analyze endpoints
│   └── services/
│       ├── gemini.py        # Gemini API client
│       └── policy.py        # Policy engine wrapper
├── scripts/
│   ├── collector.sh         # Linux metric collector
│   ├── healthcheck.sh       # Environment validation
│   └── policy_engine.py     # Rules evaluation (standalone + imported)
├── config/
│   └── rules.yaml           # Policy-as-code alert thresholds
├── tests/
│   ├── conftest.py          # Pytest fixtures
│   ├── unit/
│   │   ├── test_policy_engine.py
│   ├── integration/
│   │   └── test_api.py
│   └── bdd/
│       ├── keywords.robot
│       ├── test_analyze.robot
│       └── test_health.robot
├── metrics/                 # Runtime snapshots (gitignored)
├── logs/                    # Robot Framework reports (gitignored)
├── Dockerfile
├── docker-compose.yml
├── Jenkinsfile
├── requirements.txt
└── aurapilot.sh             # Main CLI
```

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) for macOS
- A Gemini API key from [Google AI Studio](https://aistudio.google.com)
- Git

---

## Getting started

### 1. Clone the repository

```bash
git clone https://github.com/your-username/aurapilot.git
cd aurapilot
```

### 2. Configure environment

Create a `.env` file in the project root:

```bash
echo "GEMINI_API_KEY=your_key_here" > .env
```


### 3. Create the Docker network

The network is declared as `external` in `docker-compose.yml` and must be created once before the first run:

```bash
docker network create aurapilot-net
```

### 4. Build and start the container

```bash
docker compose up -d --build
```

This builds the Ubuntu 22.04 image with all Linux tools and Python dependencies, then starts the container with the FastAPI server on port `8000`.

### 5. Verify everything is running

```bash
./aurapilot.sh health
```

Expected output: all checks green, including Docker, the running container, and installed Python dependencies.

---

## Usage

All commands are run from your macOS terminal.

```bash
# Show live system metrics in the terminal
./aurapilot.sh status

# Collect a snapshot and save it to metrics/
./aurapilot.sh collect

# Run AI analysis on the latest snapshot
./aurapilot.sh analyze

# Delete snapshots older than 7 days
./aurapilot.sh clean

# Validate that the environment is correctly set up
./aurapilot.sh health
```

### Direct API access

The API is available at `http://localhost:8000`. Interactive documentation (Swagger UI) is at `http://localhost:8000/docs`.

```bash
# Health check
curl http://localhost:8000/health

# Analyze the latest snapshot
curl -X GET http://localhost:8000/analyze/latest | python3 -m json.tool

# Analyze a custom snapshot provided in the request body
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "20260101_120000",
    "cpu": {"usage_percent": 97.0, "load_avg": {"1min": 3.5}},
    "ram": {"used_percent": 91.0, "used_gb": 7.3, "total_gb": 8.0},
    "disk": {"used_percent": 45.0},
    "system_errors": []
  }'
```

### Example response from `/analyze`

```json
{
  "timestamp": "20260101_120000",
  "alerts": [
    {
      "severity": "CRITICAL",
      "name": "Critical CPU usage",
      "message": "CPU above 95% - system may become unresponsive."
    },
    {
      "severity": "CRITICAL",
      "name": "Critical RAM usage",
      "message": "RAM usage above 93% - risk of OOM error."
    }
  ],
  "analysis": "1. HIGH CPU (97%) — system is under heavy load...",
  "model_used": "gemini-2.5-flash"
}
```

---

## Policy-as-code

Alert thresholds are defined in `config/rules.yaml`. No code changes are needed to adjust them.

```yaml
alerts:
  - id: cpu_usage_critical
    name: "Critical CPU usage"
    metric: "cpu.usage_percent"
    operator: ">="
    threshold: 95.0
    severity: CRITICAL
    message: "CPU above 95% - system may become unresponsive."
```

Supported severities: `INFO`, `WARNING`, `CRITICAL`. The policy engine runs before every Gemini call so the AI receives context about which rules were already triggered.

To evaluate a snapshot manually without the API:

```bash
docker compose exec aurapilot \
  python3 scripts/policy_engine.py metrics/snapshot_20260101_120000.json
```

---

## Running tests

```bash
# Unit tests
docker compose exec aurapilot \
  python3 -m pytest tests/ -v --tb=short

# BDD scenarios (Robot Framework)
docker compose exec aurapilot \
  python3 -m robot --outputdir logs/robot tests/bdd/
```

Robot Framework generates `logs/robot/report.html` — open it in a browser for a visual test report.

---

## CI/CD pipeline (Jenkins)

The `Jenkinsfile` defines a six-stage pipeline:

| Stage | What it does |
|---|---|
| **Checkout** | Logs the current branch and commit SHA |
| **Build Image** | Builds the Docker image tagged `aurapilot:ci-test` |
| **Validate** | Validates all JSON files and `config/rules.yaml` |
| **Tests** | Runs Pytest unit tests inside the built image |
| **Tag & Deploy** | Tags the image with the build number, restarts the container |
| **Health check** | Polls `/health` with retries to confirm the deployment succeeded |
| **BDD Tests** | Runs Robot Framework scenarios against the live container |

### Running Jenkins locally

Jenkins uses a Docker-in-Docker (DinD) setup. The `jenkins-docker` sidecar handles all Docker operations, while Jenkins communicates with it over TCP via the `DOCKER_HOST` environment variable. Both containers share the `jenkins_home` volume so Jenkins can access project files during builds.

#### Prerequisites: build the Jenkins image

Before starting Jenkins for the first time, build the custom Jenkins image with Docker client installed. Run this outside the project folder — the setup files can be deleted afterwards:

```bash
mkdir ~/jenkins-setup && cd ~/jenkins-setup

cat > Dockerfile <<EOF
FROM jenkins/jenkins:lts
USER root
RUN apt-get update && apt-get install -y docker.io
USER jenkins
EOF

docker build -t moj-jenkins-z-dockerem .
cd ~ && rm -rf ~/jenkins-setup
```

This image only needs to be built once. It is stored locally in Docker and reused on every subsequent `docker run`.

#### Run with Docker (DinD setup)

```bash
# 1. Create network
docker network create jenkins-net

# 2. Start Docker-in-Docker sidecar
docker run -d \
  --name jenkins-docker \
  --network jenkins-net \
  --network-alias docker \
  --privileged \
  -e DOCKER_TLS_CERTDIR="" \
  -v jenkins_home:/var/jenkins_home \
  docker:dind

# 3. Start Jenkins
docker run -d \
  --name jenkins \
  --network jenkins-net \
  -p 8080:8080 \
  -p 50000:50000 \
  -e DOCKER_HOST=tcp://docker:2375 \
  -v jenkins_home:/var/jenkins_home \
  moj-jenkins-z-dockerem
```

Jenkins will be available at `http://localhost:8080`. Retrieve the initial admin password with:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

#### Configure the pipeline job

1. Open `http://localhost:8080` and log in
2. Create a new **Pipeline** job
3. Under *Pipeline*, select **Pipeline script from SCM**
4. Set SCM to **Git** and enter your repository URL
5. Set branch to `*/main`, script path to `Jenkinsfile`
6. Under *Build Triggers*, enable **Poll SCM** with schedule `H/5 * * * *`
7. Add a **Secret text** credential with ID `GEMINI_API_KEY` under *Manage Jenkins → Credentials*

---

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | Yes | Google AI Studio API key |

---

## Tech stack

| Layer | Technology |
|---|---|
| Runtime environment | Ubuntu 22.04 (Docker) |
| Metric collection | Bash, `/proc` filesystem |
| Policy engine | Python 3, PyYAML |
| REST API | Python 3, FastAPI, Uvicorn |
| AI model | Google Gemini 2.5 Flash |
| Containerisation | Docker, Docker Compose |
| CI/CD | Jenkins (DinD setup) |
| Testing | Pytest, Robot Framework |

---

