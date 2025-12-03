# ===================
# Setup
# ===================
https://gist.github.com/beengud/ad5e0fe96e5750ca518ca0df7022125c

# Minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

# Kubectl
sudo snap install kubectl --classic

# Helm
sudo snap install helm --classic


# Starting up Minikube
minikube start driver=docker
minikube dashboard
Open link in browser
ctrl+z (pause)
bg (run in backgrond)

# Install nginx Fabric Gateway
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.2.1" | kubectl apply -f -

# Install as load balancer (need to specify NodePort otherwise)
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway

# Check installation
kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available

# ===================
# Commands to run:
# ===================
https://docs.nginx.com/nginx-gateway-fabric/traffic-management/https-termination/#overview


# create demo app
kubectl apply -f coffee.yaml
kubectl get pods,svc

# base64 encode certificates (in certificate.yaml)
cat ~/projects/fdpr/nginx/ssl/dev/localhost.key | base64
cat ~/projects/fdpr/nginx/ssl/dev/localhost.crt | base

# create certificate
kubectl apply -f certificate.yaml
kubectl apply -f access_secret.yaml

# create gateway and route
kubectl apply -f gateway.yaml
kubectl apply -f route.yaml

# get NodePort for cafe-nginx service
kubectl get svc

NAME         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
cafe-nginx   LoadBalancer   10.100.102.77   <pending>     80:30635/TCP,443:30598/TCP   20m
coffee       ClusterIP      10.99.86.242    <none>        80/TCP                       38m
kubernetes   ClusterIP      10.96.0.1       <none>        443/TCP                      46m

# forward port (80/443) to NodePort
sudo socat TCP-LISTEN:443,fork TCP:$(minikube ip):30598

# from browswer (in windows)
https://app.mylocaldomaindev.com/coffee

# ===================
# Cleanup
# ===================
minikube stop
minikube delete