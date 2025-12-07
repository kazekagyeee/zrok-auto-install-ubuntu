#!/usr/bin/env bash
set -e

echo "=== Installing Docker and Docker Compose ==="
sudo apt update
sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common ufw

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
     | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo docker run hello-world >/dev/null 2>&1 && echo "Docker installed successfully"

# Add user to docker group (optional)
sudo usermod -aG docker $USER || true

echo
echo "=== Configuring UFW Firewall ==="

# Allow SSH to avoid locking yourself out
sudo ufw allow 22

# HTTP & HTTPS for Caddy / Let's Encrypt
sudo ufw allow 80
sudo ufw allow 443

echo "Enabling UFW..."
sudo ufw --force enable

echo "UFW is active. Current rules:"
sudo ufw status numbered

echo
echo "=== zrok + Caddy Setup ==="

read -p "Enter domain (e.g. share.example.com): " ZROK_DNS_ZONE
read -p "Enter admin email for zrok: " ZROK_USER_EMAIL
read -p "Enter admin password for zrok: " ZROK_USER_PWD
read -p "Enter password for Ziti (ZITI_PWD): " ZITI_PWD
read -p "Enter zrok admin token (ZROK_ADMIN_TOKEN): " ZROK_ADMIN_TOKEN
read -p "Enter Cloudflare API token for Caddy DNS plugin: " CADDY_DNS_PLUGIN_TOKEN

cat > .env <<EOF
ZROK_DNS_ZONE=${ZROK_DNS_ZONE}
ZROK_USER_EMAIL=${ZROK_USER_EMAIL}
ZROK_USER_PWD=${ZROK_USER_PWD}
ZITI_PWD=${ZITI_PWD}
ZROK_ADMIN_TOKEN=${ZROK_ADMIN_TOKEN}

COMPOSE_FILE=compose.yml:compose.caddy.yml

CADDY_DNS_PLUGIN=cloudflare
CADDY_DNS_PLUGIN_TOKEN=${CADDY_DNS_PLUGIN_TOKEN}
CADDY_ACME_API=https://acme-v02.api.letsencrypt.org/directory
CADDY_HTTPS_PORT=443
CADDY_INTERFACE=0.0.0.0
EOF

echo "Downloading zrok docker-compose files..."
curl https://get.openziti.io/zrok-instance/fetch.bash | bash

echo "Starting zrok + Caddy..."
docker compose up --build --detach

echo "Waiting for services to start..."
sleep 10

echo "Creating zrok admin account..."
docker compose exec zrok-controller bash -xc "zrok admin create account ${ZROK_USER_EMAIL} ${ZROK_USER_PWD}"

echo
echo "=============================================================="
echo "  ZROK INSTALLATION COMPLETE"
echo "=============================================================="
echo "Make sure your DNS wildcard *.${ZROK_DNS_ZONE} points to this server."
echo "If DNS is correct, the zrok frontend should be available at:"
echo "https://${ZROK_DNS_ZONE}"
echo
echo "Firewall enabled. Open ports: 22, 80, 443"
echo "=============================================================="
