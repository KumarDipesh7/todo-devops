NAMESPACE   = todo-app
BACKEND_IMG = todo-backend
FRONTEND_IMG= todo-frontend
JENKINS_WAR = $(HOME)/jenkins.war
JENKINS_PORT= 9090

.PHONY: all setup run stop clean restart status logs help

# Default target
all: help

setup:
	@echo ""
	@echo "==> Starting Minikube..."
	minikube start --driver=docker --memory=3000 --cpus=2
	@echo ""
	@echo "==> Building Maven project..."
	mvn clean package -DskipTests -q
	@echo "==> Building Docker images inside Minikube..."
	eval $$(minikube docker-env) && \
		docker build -t $(BACKEND_IMG):latest . && \
		docker build -t $(FRONTEND_IMG):latest ./frontend
	@echo ""
	@echo "==> Deploying with Helm..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(NAMESPACE) ./helm/todo-app -n $(NAMESPACE)
	kubectl rollout status deployment/todo-backend -n $(NAMESPACE) --timeout=90s
	kubectl rollout status deployment/todo-frontend -n $(NAMESPACE) --timeout=90s
	@echo ""
	@echo "==> Done! Run 'make open' to open the app."

run:
	@echo ""
	@echo "==> Starting Minikube..."
	minikube start --driver=docker --memory=3000 --cpus=2
	@echo ""
	@echo "==> Starting Jenkins..."
	@if ss -ltn | grep -q :$(JENKINS_PORT); then \
		echo "    Jenkins already running."; \
	else \
		java -jar $(JENKINS_WAR) --httpPort=$(JENKINS_PORT) > /tmp/jenkins.log 2>&1 & \
		echo "    Jenkins starting at http://localhost:$(JENKINS_PORT) ..."; \
		sleep 8; \
	fi
	@echo ""
	@echo "==> Checking pods..."
	kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "    No pods yet — run 'make setup' first"
	@echo ""
	@echo "==> All systems up!"
	@echo "    App:     run 'make open'"
	@echo "    Jenkins: http://localhost:$(JENKINS_PORT)"
open:
	@echo "==> Opening Jenkins..."
	-xdg-open http://localhost:$(JENKINS_PORT) >/dev/null 2>&1 &
	@echo "==> Opening Frontend..."
	minikube service todo-frontend-service -n $(NAMESPACE)

deploy:
	@echo ""
	@echo "==> Rebuilding images..."
	mvn clean package -DskipTests -q
	eval $$(minikube docker-env) && \
		docker build -t $(BACKEND_IMG):latest . && \
		docker build -t $(FRONTEND_IMG):latest ./frontend
	@echo ""
	@echo "==> Deploying changes with Helm..."
	helm upgrade --install $(NAMESPACE) ./helm/todo-app -n $(NAMESPACE)
	@echo "==> Restarting pods..."
	kubectl rollout restart deployment/todo-backend  -n $(NAMESPACE)
	kubectl rollout restart deployment/todo-frontend -n $(NAMESPACE)
	kubectl rollout status  deployment/todo-backend  -n $(NAMESPACE) --timeout=90s
	kubectl rollout status  deployment/todo-frontend -n $(NAMESPACE) --timeout=90s
	@echo ""
	@echo "==> Deployed! Run 'make open' to view."

status:
	@echo ""
	@echo "==> Minikube:"
	minikube status
	@echo ""
	@echo "==> Pods:"
	kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "==> Services:"
	kubectl get services -n $(NAMESPACE)
	@echo ""
	@echo "==> Deployments:"
	kubectl get deployments -n $(NAMESPACE)

logs:
	@echo "==> Backend logs:"
	kubectl logs -n $(NAMESPACE) deployment/todo-backend --tail=30
	@echo ""
	@echo "==> Frontend logs:"
	kubectl logs -n $(NAMESPACE) deployment/todo-frontend --tail=20

stop:
	@echo "==> Stopping Jenkins..."
	@kill $$(lsof -t -i:$(JENKINS_PORT)) 2>/dev/null && echo "    Jenkins stopped." || echo "    Jenkins was not running."
	@echo "==> Stopping Minikube..."
	minikube stop
	@echo "==> All stopped."

clean:
	@echo "==> Deleting Minikube cluster..."
	minikube delete
	@echo "==> Clean done. Run 'make setup' to start fresh."

restart:
	kubectl rollout restart deployment/todo-backend  -n $(NAMESPACE)
	kubectl rollout restart deployment/todo-frontend -n $(NAMESPACE)
	kubectl rollout status  deployment/todo-backend  -n $(NAMESPACE) --timeout=90s
	kubectl rollout status  deployment/todo-frontend -n $(NAMESPACE) --timeout=90s
	@echo "==> Pods restarted and ready!"

help:
	@echo ""
	@echo "  Todo DevOps Project — available commands:"
	@echo ""
	@echo "  make setup    — first time setup (Minikube + Docker)"
	@echo "  make run      — start everything (Minikube + Jenkins + pods)"
	@echo "  make open     — open the app in browser"
	@echo "  make deploy   — rebuild images and redeploy to K8s"
	@echo "  make status   — show pods, services, deployments"
	@echo "  make logs     — tail logs from backend and frontend"
	@echo "  make restart  — restart pods without rebuilding"
	@echo "  make stop     — stop Minikube and Jenkins"
	@echo "  make clean    — destroy everything and start fresh"
	@echo ""