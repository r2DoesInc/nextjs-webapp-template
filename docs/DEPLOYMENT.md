# Deployment Guide

This guide covers deployment workflows using Flux GitOps.

## Deployment Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Push to main   │────▶│ Semantic Release │────▶│  Docker Build   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                          │
                                                          ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Kubernetes    │◀────│   Flux GitOps    │◀────│  Helm Chart     │
│   Deployment    │     │   Reconcile      │     │  Push to OCI    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Automatic Deployment (Recommended)

### How It Works

1. **Push to main** - Triggers GitHub Actions
2. **Semantic Release** - Determines version from commits
3. **Build & Push** - Docker image and Helm chart to Artifact Registry
4. **Flux Detects** - OCIRepository polls for new versions
5. **Helm Upgrade** - Flux applies HelmRelease

### Triggering a Release

Use conventional commits:

```bash
# Patch release (1.0.0 -> 1.0.1)
git commit -m "fix: resolve login issue"

# Minor release (1.0.0 -> 1.1.0)
git commit -m "feat: add user dashboard"

# Major release (1.0.0 -> 2.0.0)
git commit -m "feat!: redesign API"
# or
git commit -m "feat: new feature

BREAKING CHANGE: API endpoints changed"
```

### Monitoring Deployment

```bash
# Check Flux status
flux get all

# Watch HelmRelease
kubectl get helmrelease -n flux-system -w

# Check pods
kubectl get pods -n {{K8S_NAMESPACE}}-prod -w
```

## Manual Deployment

### Using Taskfile

```bash
# Deploy to development
task deploy:dev

# Deploy to staging
task deploy:staging

# Deploy to production
task deploy:prod
```

### Using Helm Directly

```bash
# Build and push Docker image
task docker:build:prod

# Upgrade Helm release
helm upgrade --install {{APP_NAME}}-prod ./chart/{{APP_NAME}} \
  -f ./chart/{{APP_NAME}}/base/values.yaml \
  -f ./chart/{{APP_NAME}}/prod/values.yaml \
  --namespace={{K8S_NAMESPACE}}-prod
```

## Environment Promotion

### Dev → Staging → Prod

```bash
# Test in dev
git checkout develop
git commit -m "feat: new feature"
git push

# Promote to staging (merge to staging branch)
git checkout staging
git merge develop
git push

# Promote to production (merge to main)
git checkout main
git merge staging
git push
```

## Rollback

### Using Flux

```bash
# Suspend automatic reconciliation
flux suspend helmrelease {{APP_NAME}}-prod -n flux-system

# Rollback Helm release
helm rollback {{APP_NAME}}-prod -n {{K8S_NAMESPACE}}-prod

# Resume when fixed
flux resume helmrelease {{APP_NAME}}-prod -n flux-system
```

### Reverting to Previous Version

1. Find previous version tag:
```bash
git tag -l
```

2. Update HelmRelease to pin version:
```yaml
# flux/prod/helmrelease.yaml
spec:
  chartRef:
    kind: OCIRepository
    name: {{APP_NAME}}-prod
  values:
    image:
      tag: "1.0.5"  # Previous working version
```

3. Commit and push:
```bash
git commit -m "fix: rollback to v1.0.5"
git push
```

## Troubleshooting

### Deployment Not Updating

```bash
# Force Flux reconciliation
flux reconcile helmrelease {{APP_NAME}}-prod -n flux-system

# Check for errors
flux logs --kind=HelmRelease --name={{APP_NAME}}-prod
```

### Pod Crashes

```bash
# Check pod events
kubectl describe pod -l app.kubernetes.io/name={{APP_NAME}} -n {{K8S_NAMESPACE}}-prod

# Check logs
kubectl logs -l app.kubernetes.io/name={{APP_NAME}} -n {{K8S_NAMESPACE}}-prod --previous
```

### Image Pull Errors

```bash
# Check image exists
gcloud artifacts docker images list {{DOCKER_REGISTRY}}/{{APP_NAME}}

# Verify pull secret
kubectl get secret -n {{K8S_NAMESPACE}}-prod
```

## Health Checks

### Readiness Probe

The application exposes `/` for health checks. Customize in `deployment.yaml`:

```yaml
readinessProbe:
  httpGet:
    path: /api/health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Liveness Probe

```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
```

## Scaling

### Horizontal Pod Autoscaler

Enabled in production by default:

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
```

### Manual Scaling

```bash
kubectl scale deployment {{APP_NAME}}-prod \
  --replicas=5 \
  -n {{K8S_NAMESPACE}}-prod
```
