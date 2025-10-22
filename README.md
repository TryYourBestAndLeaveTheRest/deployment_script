# 🚀 Docker Deployment Automation Script

A production-grade Bash script that automates the complete setup, deployment, and configuration of Dockerized applications on remote Linux servers.

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Error Handling](#error-handling)
- [Logging](#logging)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## ✨ Features

### Core Functionality
- ✅ **Interactive Parameter Collection** - Prompts for all required configuration with validation
- ✅ **Git Repository Management** - Clones or updates repositories with PAT authentication
- ✅ **Automated Environment Setup** - Installs Docker, Docker Compose, and Nginx automatically
- ✅ **Smart Deployment** - Supports both Dockerfile and docker-compose.yml based projects
- ✅ **Nginx Reverse Proxy** - Automatically configures Nginx to forward traffic to your app
- ✅ **Comprehensive Logging** - Timestamped logs with color-coded console output
- ✅ **Error Handling** - Robust error handling with meaningful exit codes
- ✅ **Idempotent Execution** - Safe to run multiple times without breaking existing setups
- ✅ **Cleanup Mode** - Easy removal of all deployed resources

### Technical Highlights
- 🔒 Secure PAT-based Git authentication
- 🔄 Automatic retry and update logic for existing deployments
- 📊 Real-time deployment progress indicators
- 🛡️ Input validation for all user-provided parameters
- 🔍 Container health verification
- 📝 Detailed logging to timestamped log files

## 🔧 Prerequisites

### Local Machine Requirements
- Bash 4.0 or higher
- Git installed
- SSH client
- `fzf` (optional, for interactive branch selection)
- Network connectivity to remote server

### Remote Server Requirements
- Linux-based OS (Ubuntu/Debian/CentOS/RHEL)
- SSH access configured
- Sudo privileges for the SSH user
- Port 22 (SSH) open
- Port 80 (HTTP) open for web access
- Sufficient disk space for Docker images

### Application Requirements
- Git repository containing either:
  - `Dockerfile`, OR
  - `docker-compose.yml` / `docker-compose.yaml`
- Valid Git Personal Access Token with repository access

## 📦 Installation

1. **Clone or download the script:**
   ```bash
   git clone <your-repo-url>
   cd hng-devops
   ```

2. **Make the script executable:**
   ```bash
   chmod +x deploy.sh
   ```

3. **Verify the script:**
   ```bash
   ./deploy.sh --help
   ```

## 🎯 Usage

### Basic Deployment

Run the script and follow the interactive prompts:

```bash
./deploy.sh
```

The script will prompt you for:
1. **Git Repository URL** - HTTPS URL of your application repository
2. **Personal Access Token** - GitHub/GitLab PAT with repo access
3. **Branch Name** - Branch to deploy (default: main)
4. **SSH Username** - Username for remote server access
5. **Server IP Address** - IP address of the target server
6. **SSH Key Path** - Path to your SSH private key (default: ~/.ssh/id_rsa)
7. **Application Port** - Internal container port your app listens on
8. **Application Name** - Name for the container/deployment

### Example Session

```bash
./deploy.sh

========================================
   Docker Deployment Configuration
========================================

Git Repository URL: https://github.com/username/myapp.git
Personal Access Token: ****************************
Branch name [main]: main
--- Remote Server Configuration ---
SSH Username: ubuntu
Server IP Address: 192.168.1.100
SSH Key Path [/home/user/.ssh/id_rsa]: /home/user/.ssh/id_rsa
--- Application Configuration ---
Application Internal Port [8000]: 3000
Application Name (for container) [webapp]: myapp

========================================
   Configuration Summary
========================================
Repository: https://github.com/username/myapp.git
Branch: main
Server: ubuntu@192.168.1.100
SSH Key: /home/user/.ssh/id_rsa
App Port: 3000
App Name: myapp
========================================

Proceed with deployment? (yes/no): yes
```

### Cleanup Mode

To remove all deployed resources:

```bash
./deploy.sh --cleanup
```

This will:
- Stop and remove Docker containers
- Remove Docker images
- Delete deployment directories
- Remove Nginx configuration
- Clean up local temporary files

### Help

Display usage information:

```bash
./deploy.sh --help
```

## ⚙️ Configuration

### SSH Key Setup

Ensure your SSH key is properly configured:

```bash
# Generate a new SSH key if needed
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copy your public key to the remote server
ssh-copy-id -i ~/.ssh/id_rsa.pub username@server_ip

# Test SSH connection
ssh -i ~/.ssh/id_rsa username@server_ip
```

### Git Personal Access Token

Create a PAT with repository access:

**GitHub:**
1. Go to Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select `repo` scope
4. Copy the token

**GitLab:**
1. Go to Preferences → Access Tokens
2. Add new token
3. Select `read_repository` scope
4. Copy the token

### Application Port Configuration

Ensure your application's Dockerfile or docker-compose.yml exposes the correct port:

**Dockerfile example:**
```dockerfile
EXPOSE 3000
CMD ["npm", "start"]
```

**docker-compose.yml example:**
```yaml
version: '3'
services:
  app:
    build: .
    ports:
      - "3000:3000"
```

## 🏗️ Architecture

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    1. Parameter Collection                   │
│              (Interactive prompts with validation)           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    2. Repository Cloning                     │
│         (Clone or update repo with PAT authentication)       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    3. SSH Connection Test                    │
│              (Verify connectivity to remote server)          │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 4. Environment Preparation                   │
│      • Update system packages                                │
│      • Install Docker & Docker Compose                       │
│      • Install and configure Nginx                           │
│      • Create deployment directories                         │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    5. Application Deployment                 │
│      • Transfer files via rsync/scp                          │
│      • Cleanup existing containers                           │
│      • Build and run new containers                          │
│      • Verify container health                               │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   6. Nginx Configuration                     │
│      • Create reverse proxy config                           │
│      • Test configuration                                    │
│      • Reload Nginx                                          │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    7. Verification & Cleanup                 │
│      • Verify application accessibility                      │
│      • Clean temporary files                                 │
│      • Display success message                               │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
hng-devops/
├── deploy.sh              # Main deployment script
├── logs/                  # Log files directory
│   └── deploy_YYYYMMDD_HHMMSS.log
└── .deploy_tmp/           # Temporary directory (auto-cleaned)
    └── <repo-name>/       # Cloned repository

Remote Server:
/home/<username>/deployments/<app-name>/
                          # Deployed application files
```

## 🛡️ Error Handling

### Exit Codes

The script uses specific exit codes for different error scenarios:

| Exit Code | Description |
|-----------|-------------|
| 0 | Success |
| 1 | Invalid input parameters |
| 2 | Git repository error |
| 3 | SSH connection error |
| 4 | Docker error |
| 5 | Nginx configuration error |
| 6 | General deployment error |

### Error Recovery

The script includes:
- **Automatic cleanup** on errors via trap handlers
- **Detailed error logging** with line numbers
- **Validation** at each step before proceeding
- **Safe failure modes** that don't leave partial deployments

### Common Error Scenarios

1. **SSH Connection Failed**
   - Verify SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
   - Test manual SSH: `ssh -i <key> user@ip`
   - Check firewall rules on remote server

2. **Git Clone Failed**
   - Verify PAT has correct permissions
   - Check repository URL is accessible
   - Ensure PAT hasn't expired

3. **Docker Build Failed**
   - Review Dockerfile syntax
   - Check Docker logs: `docker logs <container>`
   - Verify all dependencies are available

4. **Port Already in Use**
   - Check existing containers: `docker ps`
   - Use cleanup mode: `./deploy.sh --cleanup`
   - Choose a different port

## 📊 Logging

### Log File Format

Logs are stored in `logs/deploy_YYYYMMDD_HHMMSS.log` with the following format:

```
[INFO] 2025-10-21 10:30:45 - === Deployment Script Started at Tue Oct 21 10:30:45 UTC 2025 ===
[SUCCESS] 2025-10-21 10:30:47 - Parameters collected successfully
[INFO] 2025-10-21 10:30:48 - Cloning repository...
[SUCCESS] 2025-10-21 10:30:52 - Repository ready at: /path/to/repo
[ERROR] 2025-10-21 10:31:00 - SSH connection failed
```

### Log Levels

- **[INFO]** - General information and progress updates
- **[SUCCESS]** - Successful completion of operations
- **[WARNING]** - Non-critical issues that don't stop execution
- **[ERROR]** - Critical errors that halt execution

### Viewing Logs

```bash
# View latest log
tail -f logs/deploy_$(ls -t logs/ | head -1)

# Search for errors
grep ERROR logs/*.log

# View specific deployment
cat logs/deploy_20251021_103045.log
```

## 🔍 Troubleshooting

### Script Won't Execute

```bash
# Ensure script is executable
chmod +x deploy.sh

# Check bash version
bash --version  # Should be 4.0 or higher
```

### SSH Connection Issues

```bash
# Test SSH manually
ssh -v -i /path/to/key user@server_ip

# Check SSH key permissions
ls -la ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
```

### Docker Not Starting

```bash
# SSH into server and check Docker status
ssh user@server_ip
sudo systemctl status docker
sudo systemctl start docker

# Check Docker permissions
sudo usermod -aG docker $USER
newgrp docker
```

### Nginx Configuration Issues

```bash
# SSH into server and test Nginx
ssh user@server_ip
sudo nginx -t
sudo systemctl status nginx

# View Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### Application Not Accessible

```bash
# Check container status
ssh user@server_ip 'docker ps'

# View container logs
ssh user@server_ip 'docker logs <container_name>'

# Test port locally on server
ssh user@server_ip 'curl http://localhost:<port>'

# Check firewall
ssh user@server_ip 'sudo ufw status'
```

## 🔐 Security Considerations

### Best Practices

1. **SSH Keys**
   - Use strong SSH keys (RSA 4096-bit or Ed25519)
   - Never commit private keys to version control
   - Use separate keys for different servers
   - Rotate keys regularly

2. **Personal Access Tokens**
   - Use tokens with minimal required scope
   - Set expiration dates
   - Rotate tokens regularly
   - Never commit tokens to version control

3. **Server Security**
   - Keep system packages updated
   - Use firewall (ufw, iptables)
   - Disable password authentication
   - Use fail2ban for SSH protection
   - Regular security audits

4. **Docker Security**
   - Use official base images
   - Scan images for vulnerabilities
   - Run containers as non-root users
   - Limit container resources
   - Keep Docker updated

5. **Nginx Security**
   - Use HTTPS (add SSL/TLS certificates)
   - Implement rate limiting
   - Hide Nginx version
   - Configure security headers

### Sensitive Data Handling

The script handles sensitive data securely:
- PAT input is hidden (password mode)
- Logs don't contain credentials
- Temporary files are cleaned up
- SSH keys are never transferred

### Recommended Enhancements

For production use, consider adding:
- SSL/TLS certificate automation (Let's Encrypt)
- Secrets management (Vault, AWS Secrets Manager)
- Monitoring integration (Prometheus, Datadog)
- Backup automation
- Database migration handling
- Blue-green deployment support
- Rollback capabilities

## 📝 Examples

### Example 1: Node.js Application

**Repository structure:**
```
myapp/
├── Dockerfile
├── package.json
├── server.js
└── ...
```

**Deployment:**
```bash
./deploy.sh
# Enter: Node.js app repo URL
# Enter: PAT
# Enter: branch (main)
# Enter: server details
# Enter: port (3000)
# Enter: app name (nodejs-app)
```

### Example 2: Docker Compose Application

**Repository structure:**
```
fullstack-app/
├── docker-compose.yml
├── frontend/
├── backend/
└── database/
```

**docker-compose.yml:**
```yaml
version: '3'
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
  backend:
    build: ./backend
    ports:
      - "8000:8000"
```

**Deployment:**
```bash
./deploy.sh
# Script automatically detects docker-compose.yml
# Uses docker-compose up for deployment
```

### Example 3: Python Flask Application

**Repository structure:**
```
flask-app/
├── Dockerfile
├── requirements.txt
├── app.py
└── ...
```

**Dockerfile:**
```dockerfile
FROM python:3.9
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
```

**Deployment:**
```bash
./deploy.sh
# Enter: Flask app repo URL
# Enter: port (5000)
```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes with proper comments
4. Test thoroughly
5. Submit a pull request

## 📄 License

This script is provided as-is for educational and production use.

## 📞 Support

For issues, questions, or contributions:
- Open an issue in the repository
- Check the troubleshooting section
- Review the logs for detailed error messages

## 🎓 Learning Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)
- [SSH Key Management](https://www.ssh.com/academy/ssh/keygen)

---

**Happy Deploying! 🚀**
