# Spec: llm-platform-k8s

## Objective
Self-hosted LLM inference on Kubernetes that scales on request queue depth, is deployed by GitOps,
and is measured under load. It is the "LLM" that alert-triage-bot already calls: the Service is
`llama-server` in namespace `llm` on port 8080, which matches that chart's default `llmBaseUrl`, so the
two connect with no configuration.

## Hardware budget (the main constraint)
Laptop: 8 cores (Ryzen 5 3550H), no GPU, 5.8 GB RAM, 49 GB free disk. Peak target **≤ 3 GB** for the
whole cluster. Close Firefox (~4.4 GB) during cluster runs.

| Component | Est. RAM | Choice / cut |
|---|---|---|
| kind (single node) | ~800 MB | same tool as the CI smoke test |
| llama.cpp server × 1–2 | ~650 MB each | Qwen2.5-0.5B-Instruct Q4_K_M, `--threads 3`, CPU limit 3 |
| Prometheus | ~250 MB | plain `prometheus` chart; no kube-prometheus-stack |
| Grafana | ~150 MB | one provisioned dashboard |
| KEDA | ~200 MB | scales on llama.cpp's queue metric (names verified from `/metrics` first) |
| Argo CD **core** | ~350 MB | not the full install |
| ~~Loki~~ | – | cut; already shown in alert-triage-bot |

Model is downloaded once on the host and mounted into the kind node (no per-pod downloads, no model in the image).

## What gets built
- `charts/llama-server`: Deployment, Service, ScaledObject (min 1, max 2), probes, resource limits
- `argocd/`: Applications for llama-server, Prometheus, Grafana, KEDA (app-of-apps)
- `dashboards/`: tokens/s, requests in queue, replicas, p95 latency, memory per pod
- `loadtest/k6.js`: run with the `grafana/k6` docker image; ramps until the queue builds
- `terraform/`: EKS + VPC for the cloud version; **fmt/validate/tflint only** unless you choose to apply
- `.github/workflows/`: lint (helm, kubeconform, terraform), and a `kind` smoke test that serves one
  completion, if GitHub runners have the RAM

## Success criteria
- `make up` brings it all up on kind within the 3 GB budget (checked with `kubectl top`)
- Under k6 load the queue grows, KEDA scales 1 → 2, and throughput rises because each replica owns 3 cores
- alert-triage-bot, pointed at this cluster, gets a real answer from `llama-server`
- README with diagram, dashboard screenshot, and **measured** req/s and p95 numbers (hardware stated)
- Resume bullet filled only from those measurements; nothing about EKS claimed unless applied

## Your part
1. `sudo systemctl start docker` when we run things
2. Close Firefox during cluster runs
3. Host: **GitHub** (per the playbook, GitHub Actions CI). OK?

## Open questions
- EKS apply (~$5 for a few hours, needs your AWS credentials): yes or skip for now?
