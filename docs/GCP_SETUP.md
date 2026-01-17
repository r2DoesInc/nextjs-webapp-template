# Google Cloud Platform Setup

This guide covers the GCP configuration required for deploying this application.

## Prerequisites

- Google Cloud SDK installed (`gcloud`)
- A GCP project with billing enabled
- Owner or Editor role on the project

## Initial Setup

### 1. Authenticate with GCP

```bash
gcloud auth login
gcloud config set project {{GCP_PROJECT}}
```

### 2. Enable Required APIs

```bash
gcloud services enable \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  compute.googleapis.com \
  dns.googleapis.com
```

### 3. Create Artifact Registry Repository

```bash
gcloud artifacts repositories create {{APP_NAME}} \
  --repository-format=docker \
  --location={{GCP_REGION}} \
  --description="{{APP_TITLE}} Docker images and Helm charts"
```

### 4. Configure Docker Authentication

```bash
gcloud auth configure-docker {{GCP_REGION}}-docker.pkg.dev
```

## Service Account Setup

### 1. Create Service Account for Workload Identity

```bash
# Create service account
gcloud iam service-accounts create {{APP_NAME}}-sa \
  --display-name="{{APP_TITLE}} Service Account"

# Grant Secret Manager access
gcloud projects add-iam-policy-binding {{GCP_PROJECT}} \
  --member="serviceAccount:{{APP_NAME}}-sa@{{GCP_PROJECT}}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 2. Configure Workload Identity

```bash
# Allow Kubernetes SA to impersonate GCP SA
gcloud iam service-accounts add-iam-policy-binding \
  {{APP_NAME}}-sa@{{GCP_PROJECT}}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:{{GCP_PROJECT}}.svc.id.goog[{{K8S_NAMESPACE}}-prod/{{APP_NAME}}-k8s-sa]"
```

## Secret Manager Setup

### 1. Create Secrets

```bash
# Database URL
echo -n "postgresql://user:pass@host:5432/db" | \
  gcloud secrets create {{APP_NAME}}_database_url --data-file=-

# Add more secrets as needed
echo -n "your-api-key" | \
  gcloud secrets create {{APP_NAME}}_api_key --data-file=-
```

### 2. Grant Access to Secrets

```bash
gcloud secrets add-iam-policy-binding {{APP_NAME}}_database_url \
  --member="serviceAccount:{{APP_NAME}}-sa@{{GCP_PROJECT}}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## GKE Cluster Setup

If you don't have a GKE cluster:

```bash
# Create Autopilot cluster (recommended)
gcloud container clusters create-auto {{APP_NAME}}-cluster \
  --region={{GCP_REGION}} \
  --project={{GCP_PROJECT}}

# Get cluster credentials
gcloud container clusters get-credentials {{APP_NAME}}-cluster \
  --region={{GCP_REGION}} \
  --project={{GCP_PROJECT}}
```

## CI/CD Service Account

For GitHub Actions:

```bash
# Create CI/CD service account
gcloud iam service-accounts create {{APP_NAME}}-cicd \
  --display-name="{{APP_TITLE}} CI/CD"

# Grant required roles
gcloud projects add-iam-policy-binding {{GCP_PROJECT}} \
  --member="serviceAccount:{{APP_NAME}}-cicd@{{GCP_PROJECT}}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding {{GCP_PROJECT}} \
  --member="serviceAccount:{{APP_NAME}}-cicd@{{GCP_PROJECT}}.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# Create and download key
gcloud iam service-accounts keys create cicd-key.json \
  --iam-account={{APP_NAME}}-cicd@{{GCP_PROJECT}}.iam.gserviceaccount.com
```

Add the contents of `cicd-key.json` as `GCP_SA_KEY` secret in GitHub.

## Next Steps

1. [Kubernetes Setup](KUBERNETES_SETUP.md)
2. [Secret Management](SECRET_MANAGEMENT.md)
3. [Database Setup](DATABASE_SETUP.md)
