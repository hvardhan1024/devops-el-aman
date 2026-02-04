# Part 1: EC2 & Jenkins Setup Guide

## Prerequisites

- AWS Account with EC2 access
- GitHub repo: https://github.com/hvardhan1024/devops-el
- Docker Hub: harshavardhan873

---

## SECTION A: AWS EC2 Setup (Web Console)

### Step 1: Launch EC2 Instance

1. Go to AWS Console → EC2 → Launch Instance
2. Configure:
   - **Name**: `jenkins-server`
   - **AMI**: Ubuntu Server 22.04 LTS (Free tier eligible)
   - **Instance type**: t2.micro
   - **Key pair**: Create or select existing `.pem` file
   - **Storage**: 22 GB gp2

### Step 2: Configure Security Group

Add these inbound rules:
| Type | Port | Source | Description |
|------|------|--------|-------------|
| SSH | 22 | My IP | SSH access |
| Custom TCP | 8080 | 0.0.0.0/0 | Jenkins Web UI |
| Custom TCP | 50000 | 0.0.0.0/0 | Jenkins Agent |

### Step 3: Connect to EC2

```bash
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

---

## SECTION B: Enable Swap (Required for t2.micro 2GB RAM)

```bash
# Check current swap (should be 0)
free -h

# Create 2GB swap file
sudo fallocate -l 2G /swapfile

# Set permissions
sudo chmod 600 /swapfile

# Setup swap
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent (survives reboot)
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify swap is active
free -h
```

---

## SECTION C: Install Docker on EC2

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y docker.io

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Apply group changes (logout/login or run)
newgrp docker

# Verify Docker
docker --version
docker ps
```

---

## SECTION D: Run Jenkins as Docker Container

```bash
# Create Jenkins data directory
mkdir -p ~/jenkins_home

# Run Jenkins container
docker run -d \
  --name jenkins \
  --restart=unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v ~/jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Wait for Jenkins to start (30 seconds)
sleep 30

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

## SECTION E: Configure Docker Inside Jenkins Container

```bash
# Exec into Jenkins container as ROOT
docker exec -it -u root jenkins bash

# Inside container - Install Docker CLI
apt update
apt install -y docker.io

# Configure Docker socket permissions
groupadd docker 2>/dev/null || true
usermod -aG docker jenkins
chown root:docker /var/run/docker.sock
chmod 660 /var/run/docker.sock

# Exit container
exit

# Restart Jenkins container to apply changes
docker restart jenkins
```

---

## SECTION F: Access Jenkins Web UI

1. Open browser: `http://<EC2-PUBLIC-IP>:8080`
2. Paste the initial admin password from earlier
3. Click "Install suggested plugins"
4. Create admin user:
   - Username: `admin`
   - Password: (your choice)
   - Full name: `Admin`
   - Email: (your email)
5. Keep default Jenkins URL

---

## SECTION G: Configure Docker Hub Credentials in Jenkins

### Method 1: Pipeline Syntax Generator

1. Go to: Jenkins Dashboard → New Item → Pipeline (name: `test-pipeline`)
2. Scroll to Pipeline section → Click "Pipeline Syntax"
3. Select: `withCredentials: Bind credentials to variables`
4. Click "Add" → "Username and password (separated)"
5. Fill in:
   - **Username Variable**: `dockeruser`
   - **Password Variable**: `dockerpass`
   - **Credentials**: Click "Add" → "Jenkins"
     - Kind: Username with password
     - Username: `harshavardhan873`
     - Password: `Harsha<3dockerhub`
     - ID: `dockerhub-creds`
     - Description: `Docker Hub Credentials`
6. Click "Add" then "Generate Pipeline Script"
7. Copy the generated snippet for your Jenkinsfile

### Generated Code (for reference):

```groovy
withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                  passwordVariable: 'dockerpass',
                                  usernameVariable: 'dockeruser')]) {
    sh 'echo $dockerpass | docker login -u $dockeruser --password-stdin'
}
```

---

## SECTION H: Setup GitHub Webhook

### On GitHub (https://github.com/hvardhan1024/devops-el):

1. Go to: Settings → Webhooks → Add webhook
2. Configure:
   - **Payload URL**: `http://<EC2-PUBLIC-IP>:8080/github-webhook/`
   - **Content type**: `application/json`
   - **Secret**: (leave empty or add one)
   - **Events**: Select "Just the push event"
3. Click "Add webhook"

### On Jenkins:

1. Go to: Manage Jenkins → Plugins → Available plugins
2. Install: "GitHub Integration Plugin" (if not already installed)
3. In your Pipeline job configuration:
   - Check "GitHub hook trigger for GITScm polling"

---

## Quick Reference Commands

```bash
# Check Jenkins logs
docker logs jenkins

# Restart Jenkins
docker restart jenkins

# Get admin password again
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Check if Docker works inside Jenkins
docker exec jenkins docker ps

# Check swap status
free -h

# Check EC2 disk usage
df -h
```

---

## Troubleshooting

### Jenkins can't access Docker

```bash
docker exec -it -u root jenkins bash
chmod 666 /var/run/docker.sock
exit
```

### Swap not working after reboot

```bash
sudo swapon /swapfile
```

### Can't access Jenkins on port 8080

- Check EC2 Security Group has port 8080 open
- Check Jenkins is running: `docker ps`
- Check Jenkins logs: `docker logs jenkins`
