# ===================
# Setup (Windows Host)
# ===================

# Update Hosts file:
C:\Windows\System32\drivers\etc\hosts (edit in admin mode)
127.0.0.1 app.mylocaldomaindev.com

# Create cerficates for dev (WSL)
https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate

# go to path (can be any path)
cd ~/certs

# 1. Become a Certificate Authority

# Generate private key (for CA certificate)
openssl genrsa -des3 -out ca.key 2048
Passphrase: ThisIsMyCA

# Generate root certificate
openssl req -x509 -new -nodes -key ca.key -sha256 -days 825 -out ca.pem
enter passphrase from above
County Name: CH
State or Province: Geneva
Locality: Geneva
Organization Name: My Company
Organization Unit Name: blank
Common Name: app.mylocaldomaindev.com
Email address: info@email.com

# 2. Generate certificates

# Set domain nam
NAME=app.mylocaldomaindev.com

# Generate a private key
openssl genrsa -out $NAME.key 2048
# Create a certificate-signing request
openssl req -new -key $NAME.key -out $NAME.csr
Country Name: CH
State: Geneva
City: Geneva
Organization Name: My Company
Org Unit Name: [blank]
FQDN: app.mylocaldomaindev.com
email: info@email.com
Challenge password: DevPwd1234
Optional company name: [blank]

# Create a config file for the extensions
>$NAME.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = mylocaldomaindev.com
DNS.2 = $NAME # Optionally, add additional domains (I've added a subdomain here)
EOF

# Create the signed certificate
openssl x509 -req -in $NAME.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
-out $NAME.crt -days 825 -sha256 -extfile $NAME.ext
Passphrase (not provided): ThisIsMyCA

# 3. Install CA Authority (Chrome 135)
On your computer, open Chrome .
- At the top right, click More  and then Settings.
- Click Privacy and Security and then Security.
- Under “Advanced,” click "Manage Certificates".
- Under "Local Certificates", click "Manage imported certificats from Windows"
- Go to "Trusted Root Certification Authorities"
- import "ca.pem" file from ~/certs (not visible in list, change filter to "All")

# Update dev certificates
mkdir dev
cp app.mylocaldomaindev.com.crt ./dev/localhost.crt
cp app.mylocaldomaindev.com.key ./dev/localhost.key


# ========================
# WSL2 fresh installation
# ========================

# Install WSL2
- Start App "Ubuntu 24.04.1 LTS"
- Define usename and passoword for WSL2

# Upgrade to latest version
sudo apt-get update
sudo apt-get upgrade

# ===================
# Install docker
# ===================

# Add docker key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add docker stable repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# sudo apt-get update

# Install docker and docker-compose
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl is-active docker

# Add non-root user to docker group
sudo usermod -aG docker ${USER}

# ===================
# Configure git
# ===================
git config --global user.name "Xour name"
git config --global user.email "your email address"

Link wsl git to windows git credentials store (if local GIT version >= 2.39.0):
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"

# ===================
# Install kubernetes
# ===================
# K3S
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Kubectl
sudo snap install kubectl --classic

# Configure kubectl
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Helm
sudo snap install helm --classic


# Activate gateway api in trakkif (instead of ingresss)

Check before:
kubectl get svc -n kube-system
kubectl get pod -n kube-system

You can customize the Traefik deployment using Helm Controller, which is included with k3s.

Here's the minimal values you'd need to change to enable Traefik's Gateway API:

# /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesGateway:
        enabled: true
Write that yaml to a file under /var/lib/rancher/k3s/server/manifests/ and it will be automatically picked up and applied by Helm Controller. There is no need to restart k3s.

If you run into issues, you can troubleshoot using the logs of the helm-install-traefik job in the kube-system namespace.

Edited to remove the redundant and deprecated experimental version of the flag



# Install nginx Fabric Gateway
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.2.1" | kubectl apply -f -

# Install as load balancer (need to specify NodePort otherwise)
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway

helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway --set nginx.service.type=NodePort --set service.nodePorts.http=30080 --set service.nodePorts.https=30443

# Check installation
kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available

# create a folder for persistent volumne
sudo mkdir /data
cd /data
sudo mkdir pv
cd pv
sudo mkdir postgres
sudo chmod 777 postgres

# Replicate project
cd ~
mkdir projects
cd projects
git clone ...

cd k8s-...

# ==========
# Postgres
# ==========

# create secret
kubectl create secret generic postgres-secret --from-env-file=.env.dev

# apply postgres configuration (will create storage and postgres)
kubectl apply -f postgres.yaml

# test if postgres is running (WSL)
sudo apt install postgresql-client-common
sudo apt-get install postgresql-client

psql -U postgres -h 10.42.0.1 -p 30700
enter password (postgres)

# Test is postgres can be accessed (windows)
sudo apt install socat
sudo socat TCP4-LISTEN:5432,fork,bind=0.0.0.0 TCP4:10.42.0.1:30700 &

# Try connecting from DBeaver in Windows (port 5432)

# ===================
# Gateway / Web:
# ===================
https://docs.nginx.com/nginx-gateway-fabric/traffic-management/https-termination/#overview


# create demo app
kubectl apply -f coffee.yaml
kubectl apply -f test.yaml
kubectl get pods,svc

# Create tls secret
Copy certificate to project path (or other path), ensure they are excluded from GIT
kubectl create namespace certificate
kubectl create secret tls cafe-secret -n=certificate --cert=localhost.crt --key=localhost.key

# create gateway and route
kubectl apply -f gateway.yaml
kubectl apply -f route.yaml

# get ip address of node
kubectl get nodes -o wide

NAME        STATUS   ROLES                  AGE     VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION                       CONTAINER-RUNTIME
mflaptop1   Ready    control-plane,master   2d19h   v1.33.6+k3s1   172.23.72.183   <none>        Ubuntu 24.04.3 LTS   5.15.167.4-microsoft-standard-WSL2   containerd://2.1.5-k3s1.33

# get NodePort for cafe-nginx service
kubectl get svc

NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
cafe-nginx   LoadBalancer   10.43.66.236   <pending>     80:32659/TCP,443:31698/TCP   43h
coffee       ClusterIP      10.43.45.91    <none>        80/TCP                       43h
kubernetes   ClusterIP      10.43.0.1      <none>        443/TCP                      43h


# test http redirect (WSL)
GW_IP=10.42.0.1
GW_HTTP_PORT=32659
GW_HTTPS_PORT=31698
curl --resolve app.mylocaldomaindev.com:$GW_HTTP_PORT:$GW_IP http://app.mylocaldomaindev.com:$GW_HTTP_PORT/coffee --include

# test https connection (WSL)
curl --resolve app.mylocaldomaindev.com:$GW_HTTPS_PORT:$GW_IP https://app.mylocaldomaindev.com:$GW_HTTPS_PORT/coffee --insecure


# from curl in windows (using node IP Address)
curl --resolve app.mylocaldomaindev.com:31698:172.23.72.183 https://app.mylocaldomaindev.com:31698/coffee --insecure

# forward port (80/443) to NodePort (powerhsell with eleveated priviledges)
kubec
netsh interface portproxy add v4tov4 listenport=80 listenaddress=127.0.0.1 connectport=32659 connectaddress=172.23.72.183

delete routes:
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=127.0.0.1
netsh interface portproxy delete v4tov4 listenport=443 listenaddress=127.0.0.1

# from browswer (in windows)
https://app.mylocaldomaindev.com/coffee


# ===================
# Cleanup
# ===================
