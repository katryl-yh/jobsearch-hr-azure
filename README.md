# jobmarket-hr-analytics

**Modern Data Stack for Swedish Job Market Analytics**

This project implements an end-to-end data analytics platform that extracts, transforms, and visualizes Swedish job market data from Arbetsförmedlingen's JobTech API. Built for talent acquisition specialists and HR professionals to make data-driven hiring decisions.

**Created by:** Hugo Lundberg, Katrin Rylander

## 🏗️ Architecture Overview

```mermaid
graph TB
    classDef source fill:#FFF3CF,stroke:#333,stroke-width:2px
    classDef ingest fill:#FFD6A5,stroke:#333,stroke-width:2px
    classDef warehouse_bg fill:#f9f9f9,stroke:#ddd
    classDef analytics fill:#CDE8E5,stroke:#333,stroke-width:2px
    classDef infra fill:#E8F4FD,stroke:#333,stroke-width:2px
    classDef stg_layer fill:#f2efea,stroke:#555,stroke-dasharray: 2 2
    classDef core_layer fill:#e6f0fa,stroke:#555
    classDef mart_layer fill:#d1e0f1,stroke:#555

    subgraph Source
        API[("JobTech Dev API<br/>Swedish Job Market")]
        class API source
    end

    subgraph Azure Infrastructure
        ACR["Azure Container Registry"]
        ACI["Azure Container Instance<br/>(Dagster Pipeline)"]
        WEBAPP["Azure Web App<br/>(Streamlit Dashboard)"]
        STORAGE["Azure File Storage<br/>(DuckDB + Config)"]
        class ACR,ACI,WEBAPP,STORAGE infra
    end

    subgraph Pipeline ["🔄 Data Pipeline (Dagster + DLT + DBT)"]
        direction TB
        DLT["DLT Source<br/>jobsearch_source.py"]
        
        subgraph DW [Data Warehouse - DuckDB]
            style DW warehouse_bg
            
            subgraph Staging Layer
                STG_ADS["staging.job_ads_raw"]
                class STG_ADS stg_layer
            end
            
            subgraph dbt Core Models
                direction TB
                subgraph src [Staging Models]
                    SRC_MODELS["src_*.sql<br/>(Clean, Pivot)"]
                end
                subgraph star [Star Schema]
                    direction LR
                    DIM_MODELS["dim_*.sql<br/>(Dimensions)"]
                    FCT_MODEL["fct_job_ads.sql<br/>(Facts)"]
                end
                class SRC_MODELS,DIM_MODELS,FCT_MODEL core_layer
            end

            subgraph marts [dbt Marts]
                MART_MODELS["mart_*.sql<br/>(Aggregated Views)"]
                class MART_MODELS mart_layer
            end
        end
        
        class DLT ingest
    end

    subgraph Dashboard ["📊 Analytics Dashboard"]
        STREAMLIT[("Streamlit App<br/>Multi-page Analytics")]
        class STREAMLIT analytics
    end

    %% Data Flow
    API --> DLT
    DLT --> STG_ADS
    STG_ADS --> SRC_MODELS
    SRC_MODELS --> DIM_MODELS
    SRC_MODELS --> FCT_MODEL
    DIM_MODELS --> MART_MODELS
    FCT_MODEL --> MART_MODELS
    MART_MODELS --> STREAMLIT
    
    %% Infrastructure Dependencies
    ACR --> ACI
    ACR --> WEBAPP
    STORAGE --> ACI
    STORAGE --> WEBAPP
    ACI --> Pipeline
    WEBAPP --> Dashboard
```

## 📁 Project Structure

```
jobmarket-hr-analytics/
├── 🏗️  Infrastructure & Deployment
│   ├── terraform/
│   │   ├── 01-infrastructure/     # Core Azure resources
│   │   ├── 02-pipeline/          # Dagster pipeline deployment
│   │   └── 03-dashboard/         # Streamlit dashboard deployment
│   ├── Dockerfile.elt           # Multi-stage: Dagster + DBT pipeline
│   ├── Dockerfile.serve         # Streamlit dashboard container
│   ├── docker-compose.yaml      # Local development environment
│   ├── build_push_*.sh          # Container build & push scripts
│   └── deploy_*.sh              # Automated deployment scripts
│
├── 🔄  Data Pipeline
│   ├── dagster/                 # Orchestration & job scheduling
│   │   └── src/jobmarket_pipelines/
│   │       ├── definitions.py   # Assets, jobs, schedules
│   │       └── defs/dlt_sources/
│   │           └── jobsearch_source.py  # API extraction logic
│   └── dbt/                     # Data transformation
│       └── jobmarket_dbt/
│           ├── models/          # SQL transformation models
│           │   ├── staging/     # Raw data cleaning
│           │   ├── warehouse/   # Star schema (dims + facts)
│           │   └── marts/       # Aggregated business views
│           └── dbt_project.yml
│
├── 📊  Analytics Dashboard
│   └── streamlit/
│       └── src/jobmarket_streamlit/
│           ├── app.py           # Main application entry
│           ├── pages/           # Multi-page dashboard
│           │   ├── homepage.py
│           │   ├── page_demand.py
│           │   ├── page_employer.py
│           │   └── page_geography.py
│           └── connect_data_warehouse.py
│
├── 📦  Dependency Management
│   ├── pyproject.toml           # Root workspace configuration
│   ├── dagster/pyproject.toml   # Pipeline dependencies
│   ├── dbt/pyproject.toml       # DBT dependencies
│   └── streamlit/pyproject.toml # Dashboard dependencies
│
└── 🗂️  Data & Configuration
    ├── data/job_ads.duckdb      # Local DuckDB database
    ├── .dbt/profiles.yml        # DBT connection profiles
    └── .env.*                   # Environment configurations
```

## 🛠️ Multi-Stage Infrastructure & Deployment Strategy

### 🏗️ Foundation Infrastructure (`terraform/01-infrastructure`)
**Purpose:** Creates core Azure resources and shared configuration

**Resources Created:**
- **Resource Group:** Container for all project resources
- **Azure Container Registry (ACR):** Private Docker image registry
- **Storage Account + File Share:** Persistent storage for DuckDB and configuration
- **Directory Structure:** Pre-creates folders in file share (`/dagster_home`, `.dbt`, `data`)
- **Configuration Files:** Generates `profiles.yml` and `.env` files

**Key Outputs:**
```hcl
# Used by subsequent Terraform modules
resource_group_name
container_registry_name
storage_account_name
file_share_name
duckdb_path
```

### 🔄 Pipeline Deployment (`terraform/02-pipeline`)
**Purpose:** Deploys the Dagster orchestration platform as a containerized service

**Resources Created:**
- **Azure Container Instance (ACI):** Runs Dagster webserver + daemon
- **Persistent Storage Mount:** Connects to shared file share at `/mnt`
- **Health Probes:** Liveness and readiness checks for container stability
- **Public IP + DNS:** Accessible Dagster UI at `http://<fqdn>:3000`

**Container Configuration:**
```yaml
Environment Variables:
  DUCKDB_PATH: /mnt/data/job_ads.duckdb
  DAGSTER_HOME: /mnt/dagster_home
  DBT_PROFILES_DIR: /mnt/.dbt

Volume Mounts:
  /mnt: Azure File Share (persistent storage)

Health Checks:
  Liveness: HTTP GET / on port 3000 (120s initial delay)
  Readiness: HTTP GET / on port 3000 (10s initial delay)
```

### 📊 Dashboard Deployment (`terraform/03-dashboard`)
**Purpose:** Deploys Streamlit analytics dashboard as a scalable web application

**Resources Created:**
- **App Service Plan:** Linux-based hosting plan (B1 SKU)
- **Azure Web App:** Container-based web application
- **Storage Mount:** Same file share mounted for DuckDB access
- **Container Registry Integration:** Pulls dashboard image from ACR

**Web App Configuration:**
```yaml
Application Stack:
  Runtime: Docker Container
  Image: <acr-name>.azurecr.io/jobmarket-dashboard:latest
  Port: 8501 (Streamlit default)

Storage Mount:
  Mount Path: /mnt
  Source: Azure File Share (shared with pipeline)

App Settings:
  DUCKDB_PATH: /mnt/data/job_ads.duckdb
  WEBSITES_PORT: 8501
```

## 📦 Dependency Management with UV & `pyproject.toml`

This project uses **UV** (ultra-fast Python package manager) with **workspace configuration** for dependency management.

### 🏗️ Workspace Structure

The root `pyproject.toml` defines a **workspace** with multiple sub-projects:

```toml
[tool.uv.workspace]
members = ["dagster", "dbt", "streamlit"]
```

Each workspace member has its own `pyproject.toml`:
- `dagster/pyproject.toml` - Pipeline dependencies (Dagster, DLT, DuckDB)
- `dbt/pyproject.toml` - Transformation dependencies (dbt-core, dbt-duckdb)
- `streamlit/pyproject.toml` - Dashboard dependencies (Streamlit, Plotly, Pandas)

### 🚀 Installation & Usage

#### **Initial Setup (All Packages)**
```bash
# Install all workspace dependencies
uv sync --all-packages
```
> ⚠️ **Note:** `uv sync` without `--all-packages` only installs root dependencies

#### **Adding New Dependencies**
```bash
# Navigate to specific workspace
cd dagster/  # or dbt/ or streamlit/

# Add dependency to that workspace
uv add pandas

# Update lockfile
uv lock
```

#### **Python Version Management**
```bash
# Pin Python version for project
uv python pin 3.11

# Use specific Python version
uv sync --python 3.11
```

**Benefits of this approach:**
- ✅ **Isolation:** Each service has its own dependencies
- ✅ **Performance:** UV is 10-100x faster than pip
- ✅ **Reproducibility:** Unified lockfile ensures consistent environments
- ✅ **Docker-friendly:** Works seamlessly in containerized environments

## 🐳 Container Strategy

### 📋 Docker Compose (Local Development)

`docker-compose.yaml` provides a local development environment:

```yaml
services:
  dagster:
    build:
      dockerfile: Dockerfile.elt
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/data
    
  streamlit:
    build:
      dockerfile: Dockerfile.serve
    ports:
      - "8501:8501"
    volumes:
      - ./data:/app/data
```

### 🏗️ Multi-Stage Docker Images

#### **Pipeline Image (`Dockerfile.elt`)**
```dockerfile
# Stage 1: UV installer
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS uv

# Stage 2: Dependencies
FROM python:3.11-slim AS deps
COPY --from=uv /uv /uvx /usr/local/bin/
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project

# Stage 3: Application
FROM python:3.11-slim
COPY --from=deps /.venv /.venv
ENV PATH="/.venv/bin:$PATH"
COPY . /app
WORKDIR /app
EXPOSE 3000
CMD ["dagster", "dev", "-h", "0.0.0.0", "-p", "3000"]
```

#### **Dashboard Image (`Dockerfile.serve`)**
```dockerfile
# Similar multi-stage pattern
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS uv
FROM python:3.11-slim AS deps
# ... dependency installation
FROM python:3.11-slim
# ... application setup
EXPOSE 8501
CMD ["streamlit", "run", "src/jobmarket_streamlit/app.py"]
```

**Multi-stage benefits:**
- 🔥 **Smaller Images:** Excludes build tools from final image
- ⚡ **Faster Builds:** Cached dependency layers
- 🔒 **Security:** Minimal attack surface in production image

### 🚀 Container Build & Push Scripts

#### **Pipeline Image Building**

`build_push_pipeline_image.sh`:
```bash
#!/bin/bash
# Load environment variables
export $(cat .env.pipeline | xargs)

# Login to Azure Container Registry
az acr login --name $ACR_NAME

# Build and push for AMD64 (Azure compatibility)
docker buildx build \
  --platform linux/amd64 \
  --file Dockerfile.elt \
  --tag ${ACR_NAME}.azurecr.io/${CONTAINER_NAME}:${TAG} \
  --push \
  .
```

#### **Dashboard Image Building**

`build_push_dashboard_image.sh`:
```bash
#!/bin/bash
# Similar pattern for dashboard container
export $(cat .env.dashboard | xargs)
# ... build and push dashboard image
```

#### **Environment Configuration**

**`.env.pipeline`** (Generated by Terraform):
```env
ACR_NAME=acr123abc
CONTAINER_NAME=jobmarket-pipeline
TAG=latest
DUCKDB_PATH=/mnt/data/job_ads.duckdb
```

**`.env.dashboard`** (Generated by Terraform):
```env
ACR_NAME=acr123abc
CONTAINER_NAME=jobmarket-dashboard
TAG=latest
DUCKDB_PATH=/mnt/data/job_ads.duckdb
```

## 🔄 Data Pipeline Architecture

### 📊 Dagster Orchestration (`dagster/src/jobmarket_pipelines/definitions.py`)

**Assets:**
- **`dlt_load`**: Extracts job data from JobTech API using DLT source
- **`dbt_models`**: Transforms raw data using DBT models

**Jobs:**
- **`jobstream_stream_job`**: Runs data extraction
- **`job_dbt`**: Runs DBT transformations

**Automation:**
- **Schedule**: 3x daily extraction (7 AM, 12 PM, 5 PM, Mon-Fri)
- **Sensor**: Auto-triggers DBT when new data arrives

### 🔄 Data Transformation (DBT)

**Model Layers:**
1. **Staging** (`src_*.sql`): Raw data cleaning and normalization
2. **Warehouse** (`dim_*.sql`, `fct_*.sql`): Star schema with dimensions and facts
3. **Marts** (`mart_*.sql`): Business-ready aggregated views

**Key Marts:**
- `mart_occupation_demand`: Demand by occupation field/group
- `mart_employer_demand`: Top employers and hiring trends
- `mart_geography`: Regional job distribution
- `mart_trends`: Time-series vacancy trends

## 📊 Analytics Dashboard

### 🏠 Multi-Page Streamlit App

**Main Entry Point:** `streamlit/src/jobmarket_streamlit/app.py`

**Dashboard Pages:**
- **🏠 Homepage**: Project overview and navigation
- **📈 Demand Overview**: Occupation demand trends and analysis
- **🏢 Employer Analysis**: Top employers and hiring patterns
- **🌍 Geographic Analysis**: Regional job distribution with interactive maps

### 🔗 Data Connection

**Data Warehouse Connection**:
```python
@st.cache_resource
def get_cached_ddb_conn(read_only: bool = True):
    """Cached DuckDB connection for Streamlit"""
    return duckdb.connect(str(DUCKDB_PATH), read_only=read_only)

@st.cache_data  
def get_cached_ddb_df(table: str, schema: str = "marts"):
    """Cached DataFrame from DuckDB table"""
    # Fetches optimized mart tables for dashboard
```

## 🚀 Deployment Guide

### 🎯 One-Command Deployment

```bash
# Deploy entire infrastructure + applications
./deploy_all.sh
```

**What this does:**
1. **Infrastructure**: Deploys foundation Azure resources
2. **Images**: Builds and pushes Docker containers to ACR
3. **Pipeline**: Deploys Dagster orchestration platform
4. **Dashboard**: Deploys Streamlit analytics web app

### 📋 Step-by-Step Deployment

#### **1. Foundation Infrastructure**
```bash
cd terraform/01-infrastructure
terraform init
terraform plan
terraform apply
```

#### **2. Build & Push Container Images**
```bash
# Pipeline container
./build_push_pipeline_image.sh

# Dashboard container  
./build_push_dashboard_image.sh
```

#### **3. Deploy Pipeline**
```bash
cd terraform/02-pipeline
terraform init
terraform apply
```

#### **4. Deploy Dashboard**
```bash
cd terraform/03-dashboard
terraform init
terraform apply
```

### 🔗 Access Points

After deployment:
- **📊 Dashboard**: `https://<webapp-name>.azurewebsites.net`
- **🔄 Pipeline UI**: `http://<container-fqdn>:3000`
- **📁 Storage**: Mounted at `/mnt` in both containers

## ⚙️ Configuration

### 🔑 Environment Variables

**Required for deployment:**
- Azure CLI authenticated (`az login`)
- Docker installed and running
- Terraform installed

**Auto-generated by Terraform:**
- `.env.pipeline`: Pipeline container configuration
- `.env.dashboard`: Dashboard container configuration  
- `.dbt/profiles.yml`: DBT connection profiles

### 🗃️ Data Storage

**DuckDB Database:** `data/job_ads.duckdb`
- **Local Development**: `data/job_ads.duckdb`
- **Azure Production**: `/mnt/data/job_ads.duckdb` (mounted from Azure File Share)

**Schemas:**
- `staging`: Raw API data loaded by DLT
- `warehouse`: Star schema (dimensions + facts) created by DBT
- `marts`: Business-ready aggregated views for dashboard

## 📈 Dashboard Features

### 🎯 Key Metrics & Visualizations

**📊 Demand Overview:**
- Total active vacancies with field-specific filtering
- Top 10 occupation groups and occupations
- Drill-down into specific occupation groups
- Vacancy trends over time with daily granularity

**🏢 Employer Analysis:**
- Total active employers by field
- Top employers by vacancy count
- Employer trends and hiring patterns
- Group-level employer exploration

**🌍 Geographic Analysis:**
- Interactive maps of Sweden (regions + municipalities)  
- Vacancy distribution by application deadline urgency
- Regional hiring demand visualization

**Key Interactive Features:**
- **Global Filter**: Occupation field selection affects all pages
- **Drill-down Navigation**: From fields → groups → specific occupations
- **Time Series**: Daily vacancy trends with hover details
- **Interactive Maps**: Click regions for detailed statistics

## 🏗️ Why This Architecture?

### ✅ **Scalability**
- **Containerized Services**: Easy horizontal scaling
- **Azure Web Apps**: Auto-scaling based on demand
- **DuckDB**: Columnar database optimized for analytics

### ✅ **Maintainability**  
- **Infrastructure as Code**: Reproducible deployments
- **Workspace Dependencies**: Isolated, manageable dependencies
- **Multi-stage Docker**: Optimized, cacheable builds

### ✅ **Cost Efficiency**
- **Serverless Components**: Pay only for usage
- **Shared Storage**: Single file share for all services
- **Container Instances**: No VM overhead

### ✅ **Developer Experience**
- **Local Development**: docker-compose for rapid iteration
- **Automated Deployment**: One-command full deployment
- **Hot Reloading**: Streamlit auto-refreshes on code changes

---

**🎯 Ready to deploy?** Run `deploy_all.sh` and your Swedish job market analytics platform will be live in minutes!
