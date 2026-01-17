# Kubernetes Setup

This guide covers Kubernetes cluster configuration and Helm deployment.

## Prerequisites

- `kubectl` installed and configured
- `helm` v3+ installed
- Access to a Kubernetes cluster (GKE recommended)
- `flux` CLI installed (for GitOps)

## Cluster Access

```bash
# GKE
gcloud container clusters get-credentials {{APP_NAME}}-cluster \
  --region={{GCP_REGION}} \
  --project={{GCP_PROJECT}}

# Verify access
kubectl cluster-info
```

## Install Required Components

### 1. Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

### 2. cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### 3. Secrets Store CSI Driver (for GSM)

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts

helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set syncSecret.enabled=true
```

### 4. GCP Secrets Provider

```bash
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/main/deploy/provider-gcp-plugin.yaml
```

## cert-manager Issuer

Create a ClusterIssuer for Let's Encrypt:

```yaml
# letsencrypt-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-http01
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@{{DOMAIN}}
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: "*"
            namespace: "*"
```

```bash
kubectl apply -f letsencrypt-issuer.yaml
```

## Manual Helm Deployment

### Development

```bash
helm upgrade --install {{APP_NAME}}-dev ./chart/{{APP_NAME}} \
  -f ./chart/{{APP_NAME}}/base/values.yaml \
  -f ./chart/{{APP_NAME}}/dev/values.yaml \
  --namespace={{K8S_NAMESPACE}}-dev \
  --create-namespace
```

### Production

```bash
helm upgrade --install {{APP_NAME}}-prod ./chart/{{APP_NAME}} \
  -f ./chart/{{APP_NAME}}/base/values.yaml \
  -f ./chart/{{APP_NAME}}/prod/values.yaml \
  --namespace={{K8S_NAMESPACE}}-prod \
  --create-namespace
```

## Flux GitOps Setup

### 1. Install Flux

```bash
flux install
```

### 2. Create GCP Credentials Secret

```bash
kubectl create secret generic gcp-credentials \
  --namespace=flux-system \
  --from-file=credentials.json=cicd-key.json
```

### 3. Apply Flux Configurations

```bash
kubectl apply -f flux/
kubectl apply -f flux/dev/
kubectl apply -f flux/staging/
kubectl apply -f flux/prod/
```

### 4. Verify Deployment

```bash
flux get all
kubectl get helmrelease -n flux-system
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n {{K8S_NAMESPACE}}-prod
kubectl describe pod <pod-name> -n {{K8S_NAMESPACE}}-prod
```

### Check Logs

```bash
kubectl logs -l app.kubernetes.io/name={{APP_NAME}} -n {{K8S_NAMESPACE}}-prod
```

### Check Gateway/HTTPRoute

```bash
kubectl get gateway,httproute -n {{K8S_NAMESPACE}}-prod
```

### Check Certificate Status

```bash
kubectl get certificate -n {{K8S_NAMESPACE}}-prod
kubectl describe certificate {{APP_NAME}}-prod-tls -n {{K8S_NAMESPACE}}-prod
```

## Next Steps

1. [Secret Management](SECRET_MANAGEMENT.md)
2. [Database Setup](DATABASE_SETUP.md)
3. [Deployment](DEPLOYMENT.md)
