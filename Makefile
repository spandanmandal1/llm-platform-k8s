MODELS_DIR ?= $(HOME)/models
KUBECTX := kind-llm
H := helm --kube-context $(KUBECTX)

# up: GitOps path (Argo CD deploys everything from GitHub). manual: same stack with plain helm, no Argo CD.
.PHONY: up manual cluster gitops platform llm down status lint smoke load

up: cluster gitops

manual: cluster platform llm

gitops:
	$(H) upgrade --install argocd argo/argo-cd --version 10.11.3 -n argocd --create-namespace -f platform/argocd.yaml --wait
	kubectl --context $(KUBECTX) apply -f argocd/root.yaml

cluster:
	MODELS_DIR=$(MODELS_DIR) envsubst < kind/cluster.yaml | kind create cluster --config -

platform:
	$(H) upgrade --install prometheus prometheus-community/prometheus --version 29.38.1 -n monitoring --create-namespace -f platform/prometheus.yaml --wait
	$(H) upgrade --install keda kedacore/keda --version 2.20.1 -n keda --create-namespace -f platform/keda.yaml --wait
	$(H) upgrade --install grafana grafana/grafana --version 10.5.13 -n monitoring -f platform/grafana.yaml --wait

llm:
	$(H) upgrade --install llama-server charts/llama-server -n llm --create-namespace \
		--set service.type=NodePort --set service.nodePort=30080 --wait --timeout 5m

status:
	kubectl --context $(KUBECTX) top pods -A --sort-by=memory 2>/dev/null || kubectl --context $(KUBECTX) get pods -A

smoke:
	curl -fsS localhost:8080/v1/chat/completions -H 'Content-Type: application/json' \
		-d '{"messages":[{"role":"user","content":"Say OK in one word."}],"max_tokens":8}' | python3 -m json.tool

down:
	kind delete cluster --name llm

lint:
	helm lint charts/llama-server
	helm template t charts/llama-server -n llm | kubeconform -strict -summary -ignore-missing-schemas

load:
	docker run --rm -i --network host \
		-e K6_PROMETHEUS_RW_SERVER_URL=http://localhost:9090/api/v1/write \
		-e K6_PROMETHEUS_RW_TREND_STATS='p(50),p(95),max' \
		grafana/k6:1.3.0 run -o experimental-prometheus-rw --summary-trend-stats 'avg,p(50),p(95),max' - < loadtest/k6.js
