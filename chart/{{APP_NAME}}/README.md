# {{APP_TITLE}} Helm Chart

This Helm chart deploys {{APP_TITLE}} to Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Gateway API CRDs installed
- cert-manager installed
- Secrets Store CSI Driver (for GSM integration)

## Installation

### Development

```bash
helm upgrade --install {{APP_NAME}}-dev . \
  -f base/values.yaml \
  -f dev/values.yaml \
  --namespace={{K8S_NAMESPACE}}-dev \
  --create-namespace
```

### Staging

```bash
helm upgrade --install {{APP_NAME}}-staging . \
  -f base/values.yaml \
  -f staging/values.yaml \
  --namespace={{K8S_NAMESPACE}}-staging \
  --create-namespace
```

### Production

```bash
helm upgrade --install {{APP_NAME}}-prod . \
  -f base/values.yaml \
  -f prod/values.yaml \
  --namespace={{K8S_NAMESPACE}}-prod \
  --create-namespace
```

## Configuration

### Base Values

| Parameter | Description | Default |
|-----------|-------------|--------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `{{DOCKER_REGISTRY}}/{{APP_NAME}}` |
| `image.tag` | Image tag | `1.0.0` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `gateway.enabled` | Enable Gateway API | `true` |
| `gateway.hostnames` | Hostnames for gateway | `[]` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `3` |
| `secretProvider.enabled` | Enable GSM integration | `false` |
| `workloadIdentity.enabled` | Enable Workload Identity | `true` |

### Environment-Specific

See `dev/values.yaml`, `staging/values.yaml`, and `prod/values.yaml` for environment-specific configurations.

## Templates

- `deployment.yaml` - Main application deployment
- `service.yaml` - ClusterIP service
- `serviceaccount.yaml` - Service account with Workload Identity
- `gateway.yaml` - Gateway API Gateway and HTTPRoute
- `certificate.yaml` - cert-manager Certificate
- `hpa.yaml` - Horizontal Pod Autoscaler
- `poddisruptionbudget.yaml` - Pod Disruption Budget
- `secret-provider.yaml` - GSM SecretProviderClass

## Uninstallation

```bash
helm uninstall {{APP_NAME}}-prod -n {{K8S_NAMESPACE}}-prod
```
