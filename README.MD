# ===================
# Setup (Windows Host)
# ===================

# Update Hosts file:
C:\Windows\System32\drivers\etc\hosts (edit in admin mode)
127.0.0.1 app.mylocaldomaindev.com

# Create cerficates for dev
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
State or Province: Vaud
Locality: Romanel-sur-Lausanne
Organization Name: Finioma Ltd
Organization Unit Name: blank
Common Name: app.mylocaldomaindev.com
Email address: info@finioma.com


# 2. Generate certificates

# Set domain nam
NAME=app.mylocaldomaindev.com

# Generate a private key
openssl genrsa -out $NAME.key 2048
# Create a certificate-signing request
openssl req -new -key $NAME.key -out $NAME.csr
Country Name: CH
State: Vaud
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


# ===================
# Setup (WSL2)
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
cat ~/certs/dev/localhost.key | base64
cat ~/certs/dev/localhost.crt | base64

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