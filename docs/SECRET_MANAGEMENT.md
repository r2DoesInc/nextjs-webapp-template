# Secret Management

This guide covers how secrets are managed using Google Secret Manager and Kubernetes.

## Overview

Secrets are stored in Google Secret Manager and mounted into pods using:
1. **Secrets Store CSI Driver** - Mounts secrets as volumes
2. **SecretProviderClass** - Defines which secrets to mount
3. **Workload Identity** - Authenticates pods to access GSM

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GKE Pod                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Container                                              │ │
│  │  ┌──────────────────────────────────────────────────┐   │ │
│  │  │  /mnt/secrets-store/DATABASE_URL                 │   │ │
│  │  │  /mnt/secrets-store/API_KEY                      │   │ │
│  │  └──────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────┘ │
│                          ▲                                   │
│                          │ CSI Volume Mount                  │
│                          │                                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Secrets Store CSI Driver                               │ │
│  │  SecretProviderClass: gsm-secs-{{APP_NAME}}             │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ Workload Identity
                          │
┌─────────────────────────────────────────────────────────────┐
│              Google Secret Manager                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  {{APP_NAME}}_database_url                              │ │
│  │  {{APP_NAME}}_api_key                                   │ │
│  │  ...                                                    │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Creating Secrets

### Using gcloud CLI

```bash
# Create a secret
echo -n "your-secret-value" | \
  gcloud secrets create {{APP_NAME}}_my_secret --data-file=-

# Update a secret
echo -n "new-secret-value" | \
  gcloud secrets versions add {{APP_NAME}}_my_secret --data-file=-
```

### Using Terraform (Recommended)

```hcl
resource "google_secret_manager_secret" "database_url" {
  secret_id = "{{APP_NAME}}_database_url"
  
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = var.database_url
}
```

## Adding Secrets to Application

### 1. Add Secret to GSM

```bash
echo -n "secret-value" | \
  gcloud secrets create {{APP_NAME}}_new_secret --data-file=-
```

### 2. Grant Access

```bash
gcloud secrets add-iam-policy-binding {{APP_NAME}}_new_secret \
  --member="serviceAccount:{{APP_NAME}}-sa@{{GCP_PROJECT}}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 3. Update SecretProviderClass

Edit `chart/{{APP_NAME}}/templates/secret-provider.yaml`:

```yaml
spec:
  secretObjects:
  - secretName: {{ include "app.fullname" . }}-secrets
    type: Opaque
    data:
    # Add new secret
    - objectName: {{APP_NAME}}_new_secret
      key: NEW_SECRET_KEY
  parameters:
    secrets: |-
      # Add new secret mapping
      - resourceName: projects/{{GCP_PROJECT}}/secrets/{{APP_NAME}}_new_secret/versions/latest
        path: {{APP_NAME}}_new_secret
```

### 4. Use in Deployment

Secrets are automatically synced to a Kubernetes Secret and can be used as environment variables:

```yaml
env:
  - name: NEW_SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: {{ include "app.fullname" . }}-secrets
        key: NEW_SECRET_KEY
```

## Environment-Specific Secrets

Use different secret names per environment:

```yaml
# dev/values.yaml
secretNames:
  databaseUrl: "{{APP_NAME}}_dev_database_url"

# prod/values.yaml  
secretNames:
  databaseUrl: "{{APP_NAME}}_prod_database_url"
```

## Local Development

For local development, use `.env` file:

```bash
cp .env.example .env
# Edit .env with your local values
```

Never commit `.env` files to git!

## Rotating Secrets

1. Add new secret version in GSM
2. Restart pods to pick up new version:

```bash
kubectl rollout restart deployment/{{APP_NAME}}-prod -n {{K8S_NAMESPACE}}-prod
```

## Next Steps

1. [Database Setup](DATABASE_SETUP.md)
2. [Deployment](DEPLOYMENT.md)
