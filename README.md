# SaaS DevOps Project

DevOps showcase project for a Go web app.

## DevOps Skills Demonstrated

- **CI/CD Automation**: GitHub Actions pipeline for build, test, lint, Docker push, and Helm tag update.
- **Containerization**: Multi-stage Docker build for a lightweight runtime image.
- **Kubernetes Deployment**: App deployed with Deployment, Service, and Ingress manifests.
- **Helm Packaging**: Reusable Helm chart with configurable image and ingress values.
- **Release Traceability**: Image tags tied to GitHub run IDs in the pipeline.
- **Infrastructure as Code mindset**: Deployment config versioned in repo (`k8s/` + `helm/`).

## Tech Stack

- Go 1.22
- Docker
- Kubernetes + Ingress
- Helm 3
- GitHub Actions

## Quick Start

Run locally:

```bash
go mod tidy
go run main.go
```

Run with Docker:

```bash
docker build -t saas-go-web-app:v1 .
docker run --rm -p 8080:8080 saas-go-web-app:v1
```

Deploy with Kubernetes manifests:

```bash
kubectl apply -f k8s/manifests/
```

Deploy with Helm:

```bash
helm upgrade --install go-web-app ./helm/go-web-app
```

## CI/CD Secrets Needed

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `TOKEN` (repo write access for Helm values update commit)

## Key Files

- `.github/workflows/ci-cd.yaml`
- `Dockerfile`
- `k8s/manifests/`
- `helm/go-web-app/`