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
kubectl get pod
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Helm
sudo snap install helm --classic


# Activate gateway api in trakkif (instead of ingresss)

Check before:
kubectl get gatewayclass (should be empty)
kubectl get svc -n kube-system
kubectl get pod -n kube-system

You can customize the Traefik deployment using Helm Controller, which is included with k3s.

Here's the minimal values you'd need to change to enable Traefik's Gateway API:

sudo -s
vim /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
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

Check after:
kubectl get gatewayclass (should have a value now)
kubectl get svc -n kube-system
kubectl get pod -n kube-system

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




# set traefik gateway API nodeports
kubectl apply -f traefik-customize.yaml

sudo systemctl restart k3s

check that port have changed:
kubectl get svc traefik -n kube-system


# ==========
# Postgres
# ==========

# create secret
kubectl create secret generic postgres-secret --from-env-file=.env.dev

# apply postgres configuration (will create storage and postgres)
kubectl apply -f postgres.yaml

# test if postgres is running (WSL)
sudo apt install postgresql-client-common postgresql-client

psql -U postgres -h 10.42.0.1 -p 30700
enter password (postgres)

# Test is postgres can be accessed (windows)
sudo apt install socat
sudo socat TCP4-LISTEN:5432,fork,bind=0.0.0.0 TCP4:10.42.0.1:30700 &

# Try connecting from DBeaver in Windows (port 5432)

# ===================
# Gateway / Web:
# ===================

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
kubectl apply -f access-secret.yaml
kubectl apply -f route.yaml

# get external ip address of traefik gateway
kubectl get pods,svc -n kube-system
NAME                                          READY   STATUS      RESTARTS   AGE
pod/coredns-6d668d687-l9ddp                   1/1     Running     0          8m55s
pod/helm-install-traefik-crd-9gmqz            0/1     Completed   0          8m55s
pod/helm-install-traefik-p8dv7                0/1     Completed   0          5m27s
pod/local-path-provisioner-869c44bfbd-hmqsh   1/1     Running     0          8m55s
pod/metrics-server-7bfffcd44-4ngpj            1/1     Running     0          8m55s
pod/svclb-traefik-baedc382-rkdlm              2/2     Running     0          8m41s
pod/traefik-6f4947d4bd-6jwlj                  1/1     Running     0          5m26s

NAME                     TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                      AGE
service/kube-dns         ClusterIP      10.43.0.10     <none>          53/UDP,53/TCP,9153/TCP       8m58s
service/metrics-server   ClusterIP      10.43.11.29    <none>          443/TCP                      8m58s
service/traefik          LoadBalancer   10.43.119.67   172.23.72.183   80:30355/TCP,443:32679/TCP   8m41s

kubectl get nodes -o wide (alternative method)

NAME        STATUS   ROLES                  AGE     VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION                       CONTAINER-RUNTIME
mflaptop1   Ready    control-plane,master   2d19h   v1.33.6+k3s1   172.23.72.183   <none>        Ubuntu 24.04.3 LTS   5.15.167.4-microsoft-standard-WSL2   containerd://2.1.5-k3s1.33

# test http redirect (WSL)
GW_IP=172.23.72.183
GW_HTTP_PORT=30080
GW_HTTPS_PORT=30443
curl --resolve app.mylocaldomaindev.com:$GW_HTTP_PORT:$GW_IP http://app.mylocaldomaindev.com:$GW_HTTP_PORT/coffee --include

# test https connection (WSL)
curl --resolve app.mylocaldomaindev.com:$GW_HTTPS_PORT:$GW_IP https://app.mylocaldomaindev.com:$GW_HTTPS_PORT/coffee --insecure


# from curl in windows (using node IP Address)
curl --resolve app.mylocaldomaindev.com:31698:172.23.72.183 https://app.mylocaldomaindev.com:31698/coffee --insecure

# forward port (80/443) to NodePort (powerhsell with eleveated priviledges)
netsh interface portproxy add v4tov4 listenport=80 listenaddress=127.0.0.1 connectport=30080 connectaddress=172.23.72.183
netsh interface portproxy add v4tov4 listenport=443 listenaddress=127.0.0.1 connectport=30443 connectaddress=172.23.72.183

delete routes:
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=127.0.0.1
netsh interface portproxy delete v4tov4 listenport=443 listenaddress=127.0.0.1

# from browswer (in windows)
https://app.mylocaldomaindev.com/coffee

# =====================
# Add FastApi Backend
# =====================

# build locally
docker build -f backend/DockerfileServerDev.dockerfile -t fdpr-backend-dev:latest ./backend

# save and import into k3s containerd
docker save fdpr-backend-dev:latest -o /tmp/fdpr-backend-dev.tar
sudo k3s ctr -n k8s.io images import /tmp/fdpr-backend-dev.tar
rm /tmp/fdpr-backend-dev.tar

# Add FastApi Backend
kubectl apply -f backend.yaml

# restart
kubectl rollout restart deployment/backend
kubectl get pods


# Alternative (use local docker registry)
# start a local registry
docker run -d --restart=always -p 5000:5000 --name registry registry:2

# build + push
docker build -f backend/DockerfileServerDev.dockerfile -t localhost:5000/fdpr-backend-dev:latest ./backend
docker push localhost:5000/fdpr-backend-dev:latest

# update k8s/backend.yaml to use localhost:5000/fdpr-backend-dev:latest and imagePullPolicy: IfNotPresent
kubectl apply -f k8s/backend.yaml
kubectl rollout restart deployment/backend

# from browswer (in windows)
https://app.mylocaldomaindev.com/api

# ===================
# Cleanup
# ===================
