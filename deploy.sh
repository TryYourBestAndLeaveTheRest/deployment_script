#!/bin/bash

################################################################################
# Production-Grade Docker Deployment Automation Script
# Author: DevOps Automation Team
# Description: Automates setup, deployment, and configuration of Dockerized
#              applications on remote Linux servers with comprehensive error
#              handling, validation, and logging.
################################################################################

set -euo pipefail
IFS=$'\n\t'

################################################################################
# Global Variables and Configuration
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/deploy_$(date +%Y%m%d_%H%M%S).log"
TEMP_DIR="${SCRIPT_DIR}/.deploy_tmp"
REPO_DIR=""
CLEANUP_MODE=false

# ANSI Color Codes for Output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Exit Codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_INPUT=1
readonly EXIT_REPO_ERROR=2
readonly EXIT_SSH_ERROR=3
readonly EXIT_DOCKER_ERROR=4
readonly EXIT_NGINX_ERROR=5
readonly EXIT_DEPLOYMENT_ERROR=6

################################################################################
# Utility Functions
################################################################################

# Initialize logging
init_logging() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"
    log_info "=== Deployment Script Started at $(date) ==="
    log_info "Log file: ${LOG_FILE}"
}

# Log functions
log_info() {
    local message="[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo -e "${BLUE}${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

log_success() {
    local message="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo -e "${GREEN}${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

log_warning() {
    local message="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo -e "${YELLOW}${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

log_error() {
    local message="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo -e "${RED}${message}${NC}" >&2
    echo "${message}" >> "${LOG_FILE}"
}

# Progress indicator
show_progress() {
    local message="$1"
    echo -e "${CYAN}>>> ${message}${NC}"
    log_info "${message}"
}

# Error trap handler
error_handler() {
    local line_num=$1
    log_error "Script failed at line ${line_num}"
    log_error "Last command exit code: $?"
    cleanup_on_error
    exit "${EXIT_DEPLOYMENT_ERROR}"
}

# Cleanup on error
cleanup_on_error() {
    log_warning "Performing cleanup due to error..."
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
        log_info "Removed temporary directory"
    fi
}

# Set up error handling
trap 'error_handler ${LINENO}' ERR

################################################################################
# Input Validation Functions
################################################################################

# Validate Git URL
validate_git_url() {
    local url="$1"
    if [[ ! "${url}" =~ ^https?:// ]] && [[ ! "${url}" =~ ^git@ ]]; then
        log_error "Invalid Git URL format: ${url}"
        return 1
    fi
    return 0
}

# Validate IP address
validate_ip() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! "${ip}" =~ ${ip_regex} ]]; then
        return 1
    fi
    
    # Validate each octet
    IFS='.' read -ra OCTETS <<< "${ip}"
    for octet in "${OCTETS[@]}"; do
        if ((octet > 255)); then
            return 1
        fi
    done
    return 0
}

# Validate port number
validate_port() {
    local port="$1"
    if [[ ! "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        return 1
    fi
    return 0
}

# Validate file exists
validate_file_exists() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        log_error "File not found: ${file}"
        return 1
    fi
    return 0
}

################################################################################
# User Input Collection Functions
################################################################################

# Prompt for input with validation
prompt_input() {
    local prompt_message="$1"
    local var_name="$2"
    local default_value="${3:-}"
    local is_secret="${4:-false}"
    local validator="${5:-}"
    
    while true; do
        if [[ -n "${default_value}" ]]; then
            echo -en "${MAGENTA}${prompt_message} [${default_value}]: ${NC}"
        else
            echo -en "${MAGENTA}${prompt_message}: ${NC}"
        fi
        
        if [[ "${is_secret}" == "true" ]]; then
            read -rs input
            echo ""
        else
            read -r input
        fi
        
        # Use default if input is empty
        if [[ -z "${input}" ]] && [[ -n "${default_value}" ]]; then
            input="${default_value}"
        fi
        
        # Validate if validator function provided
        if [[ -n "${validator}" ]]; then
            if ${validator} "${input}"; then
                eval "${var_name}='${input}'"
                break
            else
                log_error "Invalid input. Please try again."
            fi
        else
            if [[ -n "${input}" ]]; then
                eval "${var_name}='${input}'"
                break
            else
                log_error "Input cannot be empty. Please try again."
            fi
        fi
    done
}

# Collect all required parameters
collect_parameters() {
    show_progress "Collecting deployment parameters..."
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Docker Deployment Configuration${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Git repository details
    prompt_input "Git Repository URL" GIT_REPO_URL "" false validate_git_url
    prompt_input "Personal Access Token (PAT)" GIT_PAT "" true
    prompt_input "Branch name" GIT_BRANCH "main" false
    
    # SSH details
    echo ""
    echo -e "${CYAN}--- Remote Server Configuration ---${NC}"
    prompt_input "SSH Username" SSH_USER "" false
    prompt_input "Server IP Address" SERVER_IP "" false validate_ip
    prompt_input "SSH Key Path" SSH_KEY_PATH "${HOME}/.ssh/id_rsa" false validate_file_exists
    
    # Application details
    echo ""
    echo -e "${CYAN}--- Application Configuration ---${NC}"
    prompt_input "Application Internal Port" APP_PORT "8000" false validate_port
    prompt_input "Application Name (for container)" APP_NAME "webapp" false
    
    # Confirmation
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Configuration Summary${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "Repository: ${GREEN}${GIT_REPO_URL}${NC}"
    echo -e "Branch: ${GREEN}${GIT_BRANCH}${NC}"
    echo -e "Server: ${GREEN}${SSH_USER}@${SERVER_IP}${NC}"
    echo -e "SSH Key: ${GREEN}${SSH_KEY_PATH}${NC}"
    echo -e "App Port: ${GREEN}${APP_PORT}${NC}"
    echo -e "App Name: ${GREEN}${APP_NAME}${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    read -p "Proceed with deployment? (yes/no): " -r confirm
    if [[ ! "${confirm}" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Deployment cancelled by user"
        exit "${EXIT_SUCCESS}"
    fi
    
    log_success "Parameters collected successfully"
}

################################################################################
# Git Repository Functions
################################################################################

# Clone or update repository
clone_or_update_repo() {
    show_progress "Cloning/updating Git repository..."
    
    # Extract repository name
    local repo_name=$(basename "${GIT_REPO_URL}" .git)
    REPO_DIR="${TEMP_DIR}/${repo_name}"
    
    mkdir -p "${TEMP_DIR}"
    
    # Prepare authenticated URL
    local auth_url
    if [[ "${GIT_REPO_URL}" =~ ^https?:// ]]; then
        auth_url=$(echo "${GIT_REPO_URL}" | sed "s|https://|https://${GIT_PAT}@|")
    else
        auth_url="${GIT_REPO_URL}"
    fi
    
    if [[ -d "${REPO_DIR}/.git" ]]; then
        log_info "Repository already exists, pulling latest changes..."
        cd "${REPO_DIR}"
        git fetch --all >> "${LOG_FILE}" 2>&1
        git checkout "${GIT_BRANCH}" >> "${LOG_FILE}" 2>&1
        git pull origin "${GIT_BRANCH}" >> "${LOG_FILE}" 2>&1
    else
        log_info "Cloning repository..."
        git clone -b "${GIT_BRANCH}" "${auth_url}" "${REPO_DIR}" >> "${LOG_FILE}" 2>&1
    fi
    
    cd "${REPO_DIR}"
    log_success "Repository ready at: ${REPO_DIR}"
    
    # Verify Dockerfile or docker-compose.yml exists
    if [[ -f "Dockerfile" ]]; then
        log_success "Found Dockerfile"
        DEPLOYMENT_TYPE="dockerfile"
    elif [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
        log_success "Found docker-compose.yml"
        DEPLOYMENT_TYPE="compose"
    else
        log_error "No Dockerfile or docker-compose.yml found in repository"
        exit "${EXIT_REPO_ERROR}"
    fi
}

################################################################################
# SSH Connection Functions
################################################################################

# Test SSH connectivity
test_ssh_connection() {
    show_progress "Testing SSH connection to remote server..."
    
    if ssh -i "${SSH_KEY_PATH}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "${SSH_USER}@${SERVER_IP}" "echo 'SSH connection successful'" >> "${LOG_FILE}" 2>&1; then
        log_success "SSH connection established"
        return 0
    else
        log_error "Failed to establish SSH connection"
        exit "${EXIT_SSH_ERROR}"
    fi
}

# Execute command on remote server
remote_exec() {
    local command="$1"
    local description="${2:-Executing remote command}"
    
    log_info "${description}"
    if ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no \
        "${SSH_USER}@${SERVER_IP}" "${command}" >> "${LOG_FILE}" 2>&1; then
        return 0
    else
        log_error "Remote command failed: ${description}"
        return 1
    fi
}

# Execute command on remote server with output
remote_exec_with_output() {
    local command="$1"
    ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no \
        "${SSH_USER}@${SERVER_IP}" "${command}" 2>> "${LOG_FILE}"
}

################################################################################
# Remote Environment Setup Functions
################################################################################

# Update system packages
update_system_packages() {
    show_progress "Updating system packages on remote server..."
    
    remote_exec "sudo apt-get update -y" "Updating package lists" || \
    remote_exec "sudo yum update -y" "Updating package lists (YUM)"
    
    log_success "System packages updated"
}

# Install Docker
install_docker() {
    show_progress "Installing Docker on remote server..."
    
    # Check if Docker is already installed
    if remote_exec "command -v docker" "Checking Docker installation" 2>/dev/null; then
        log_info "Docker is already installed"
        local docker_version=$(remote_exec_with_output "docker --version")
        log_info "Docker version: ${docker_version}"
        return 0
    fi
    
    log_info "Installing Docker..."
    
    # Install Docker using official script
    remote_exec "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sudo sh /tmp/get-docker.sh" \
        "Installing Docker via official script"
    
    # Add user to docker group
    remote_exec "sudo usermod -aG docker ${SSH_USER}" "Adding user to docker group"
    
    # Start and enable Docker service
    remote_exec "sudo systemctl start docker && sudo systemctl enable docker" \
        "Starting and enabling Docker service"
    
    log_success "Docker installed successfully"
}

# Install Docker Compose
install_docker_compose() {
    show_progress "Installing Docker Compose on remote server..."
    
    # Check if Docker Compose is already installed
    if remote_exec "command -v docker-compose" "Checking Docker Compose installation" 2>/dev/null; then
        log_info "Docker Compose is already installed"
        local compose_version=$(remote_exec_with_output "docker-compose --version")
        log_info "Docker Compose version: ${compose_version}"
        return 0
    fi
    
    log_info "Installing Docker Compose..."
    
    # Install Docker Compose
    remote_exec "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose" \
        "Downloading Docker Compose"
    
    remote_exec "sudo chmod +x /usr/local/bin/docker-compose" \
        "Making Docker Compose executable"
    
    log_success "Docker Compose installed successfully"
}

# Install Nginx
install_nginx() {
    show_progress "Installing Nginx on remote server..."
    
    # Check if Nginx is already installed
    if remote_exec "command -v nginx" "Checking Nginx installation" 2>/dev/null; then
        log_info "Nginx is already installed"
        local nginx_version=$(remote_exec_with_output "nginx -v 2>&1")
        log_info "Nginx version: ${nginx_version}"
        return 0
    fi
    
    log_info "Installing Nginx..."
    
    remote_exec "sudo apt-get install -y nginx" "Installing Nginx (APT)" || \
    remote_exec "sudo yum install -y nginx" "Installing Nginx (YUM)"
    
    # Start and enable Nginx
    remote_exec "sudo systemctl start nginx && sudo systemctl enable nginx" \
        "Starting and enabling Nginx service"
    
    log_success "Nginx installed successfully"
}

# Prepare remote environment
prepare_remote_environment() {
    show_progress "Preparing remote server environment..."
    
    update_system_packages
    install_docker
    install_docker_compose
    install_nginx
    
    # Create deployment directory
    remote_exec "mkdir -p /home/${SSH_USER}/deployments/${APP_NAME}" \
        "Creating deployment directory"
    
    log_success "Remote environment prepared successfully"
}

################################################################################
# Deployment Functions
################################################################################

# Transfer project files to remote server
transfer_files() {
    show_progress "Transferring project files to remote server..."
    
    local remote_path="/home/${SSH_USER}/deployments/${APP_NAME}"
    
    # Use rsync for efficient transfer
    if command -v rsync &> /dev/null; then
        log_info "Using rsync for file transfer..."
        rsync -avz --delete -e "ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no" \
            "${REPO_DIR}/" "${SSH_USER}@${SERVER_IP}:${remote_path}/" >> "${LOG_FILE}" 2>&1
    else
        log_info "Using scp for file transfer..."
        scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -r \
            "${REPO_DIR}/"* "${SSH_USER}@${SERVER_IP}:${remote_path}/" >> "${LOG_FILE}" 2>&1
    fi
    
    log_success "Files transferred successfully"
}

# Stop and remove existing containers (idempotency)
cleanup_existing_deployment() {
    show_progress "Cleaning up existing deployment (if any)..."
    
    local remote_path="/home/${SSH_USER}/deployments/${APP_NAME}"
    
    # Stop and remove containers
    remote_exec "cd ${remote_path} && docker ps -q --filter name=${APP_NAME} | xargs -r docker stop" \
        "Stopping existing containers" || true
    
    remote_exec "cd ${remote_path} && docker ps -aq --filter name=${APP_NAME} | xargs -r docker rm" \
        "Removing existing containers" || true
    
    log_success "Cleanup completed"
}

# Deploy using Dockerfile
deploy_with_dockerfile() {
    show_progress "Deploying application using Dockerfile..."
    
    local remote_path="/home/${SSH_USER}/deployments/${APP_NAME}"
    
    # Build Docker image
    log_info "Building Docker image..."
    remote_exec "cd ${remote_path} && docker build -t ${APP_NAME}:latest ." \
        "Building Docker image"
    
    # Run container
    log_info "Starting Docker container..."
    remote_exec "cd ${remote_path} && docker run -d --name ${APP_NAME} --restart unless-stopped -p ${APP_PORT}:${APP_PORT} ${APP_NAME}:latest" \
        "Running Docker container"
    
    log_success "Application deployed successfully"
}

# Deploy using docker-compose
deploy_with_compose() {
    show_progress "Deploying application using docker-compose..."
    
    local remote_path="/home/${SSH_USER}/deployments/${APP_NAME}"
    
    # Stop existing services
    remote_exec "cd ${remote_path} && docker-compose down" \
        "Stopping existing docker-compose services" || true
    
    # Start services
    log_info "Starting docker-compose services..."
    remote_exec "cd ${remote_path} && docker-compose up -d --build" \
        "Starting docker-compose services"
    
    log_success "Application deployed successfully"
}

# Deploy application
deploy_application() {
    show_progress "Deploying Dockerized application..."
    
    transfer_files
    cleanup_existing_deployment
    
    if [[ "${DEPLOYMENT_TYPE}" == "dockerfile" ]]; then
        deploy_with_dockerfile
    else
        deploy_with_compose
    fi
    
    # Wait for container to be healthy
    sleep 5
    
    # Verify deployment
    verify_deployment
}

# Verify deployment
verify_deployment() {
    show_progress "Verifying deployment..."
    
    local remote_path="/home/${SSH_USER}/deployments/${APP_NAME}"
    
    # Check if container is running
    local container_status=$(remote_exec_with_output "docker ps --filter name=${APP_NAME} --format '{{.Status}}'")
    
    if [[ -n "${container_status}" ]]; then
        log_success "Container is running: ${container_status}"
    else
        log_error "Container is not running"
        log_info "Container logs:"
        remote_exec_with_output "docker logs ${APP_NAME}" || true
        exit "${EXIT_DOCKER_ERROR}"
    fi
    
    # Check application accessibility on port
    log_info "Checking application accessibility on port ${APP_PORT}..."
    sleep 3
    
    if remote_exec "curl -f http://localhost:${APP_PORT} > /dev/null 2>&1" \
        "Testing application accessibility" || \
       remote_exec "wget -q --spider http://localhost:${APP_PORT}" \
        "Testing application accessibility (wget)"; then
        log_success "Application is accessible on port ${APP_PORT}"
    else
        log_warning "Could not verify application accessibility (this may be normal if app doesn't respond to GET /)"
    fi
}

################################################################################
# Nginx Configuration Functions
################################################################################

# Configure Nginx as reverse proxy
configure_nginx() {
    show_progress "Configuring Nginx as reverse proxy..."
    
    local nginx_config="/etc/nginx/sites-available/${APP_NAME}"
    local nginx_enabled="/etc/nginx/sites-enabled/${APP_NAME}"
    
    # Create Nginx configuration
    local config_content="server {
    listen 80;
    server_name ${SERVER_IP};

    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}"
    
    # Write configuration to remote server
    remote_exec "echo '${config_content}' | sudo tee ${nginx_config} > /dev/null" \
        "Creating Nginx configuration"
    
    # Create sites-enabled directory if it doesn't exist (for some distros)
    remote_exec "sudo mkdir -p /etc/nginx/sites-enabled" \
        "Creating sites-enabled directory" || true
    
    # Enable site
    remote_exec "sudo ln -sf ${nginx_config} ${nginx_enabled}" \
        "Enabling Nginx site"
    
    # Test Nginx configuration
    log_info "Testing Nginx configuration..."
    if remote_exec "sudo nginx -t" "Testing Nginx configuration"; then
        log_success "Nginx configuration is valid"
    else
        log_error "Nginx configuration test failed"
        exit "${EXIT_NGINX_ERROR}"
    fi
    
    # Reload Nginx
    remote_exec "sudo systemctl reload nginx" "Reloading Nginx"
    
    log_success "Nginx configured successfully"
    log_info "Application is now accessible at: http://${SERVER_IP}"
}

################################################################################
# Cleanup Functions
################################################################################

# Cleanup function for --cleanup flag
perform_cleanup() {
    show_progress "Performing cleanup of deployed resources..."
    
    local remote_path="/home/${SSH_USER}/deployments/${APP_NAME}"
    
    # Stop and remove containers
    remote_exec "cd ${remote_path} && docker-compose down -v" \
        "Stopping docker-compose services" || true
    
    remote_exec "docker stop ${APP_NAME}" "Stopping container" || true
    remote_exec "docker rm ${APP_NAME}" "Removing container" || true
    remote_exec "docker rmi ${APP_NAME}:latest" "Removing image" || true
    
    # Remove deployment directory
    remote_exec "rm -rf ${remote_path}" "Removing deployment directory" || true
    
    # Remove Nginx configuration
    remote_exec "sudo rm -f /etc/nginx/sites-available/${APP_NAME}" \
        "Removing Nginx configuration" || true
    remote_exec "sudo rm -f /etc/nginx/sites-enabled/${APP_NAME}" \
        "Removing Nginx symlink" || true
    remote_exec "sudo systemctl reload nginx" "Reloading Nginx" || true
    
    # Clean up local temp directory
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
        log_info "Removed local temporary directory"
    fi
    
    log_success "Cleanup completed successfully"
}

# Final cleanup
final_cleanup() {
    log_info "Performing final cleanup..."
    
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
        log_info "Removed temporary directory"
    fi
}

################################################################################
# Main Execution Flow
################################################################################

# Display usage information
show_usage() {
    cat << EOF
${CYAN}========================================${NC}
${CYAN} Docker Deployment Automation Script${NC}
${CYAN}========================================${NC}

${GREEN}Usage:${NC}
    $0 [OPTIONS]

${GREEN}Options:${NC}
    --cleanup    Remove all deployed resources and configurations
    --help       Display this help message

${GREEN}Description:${NC}
    This script automates the deployment of Dockerized applications
    to remote Linux servers with complete environment setup, Docker
    configuration, and Nginx reverse proxy setup.

${GREEN}Features:${NC}
    ✓ Automated Git repository cloning with PAT authentication
    ✓ Remote server environment preparation
    ✓ Docker and Docker Compose installation
    ✓ Automated application deployment
    ✓ Nginx reverse proxy configuration
    ✓ Comprehensive error handling and logging
    ✓ Idempotent execution (safe to re-run)

${GREEN}Exit Codes:${NC}
    0 - Success
    1 - Invalid input
    2 - Repository error
    3 - SSH connection error
    4 - Docker error
    5 - Nginx error
    6 - General deployment error

${GREEN}Log Files:${NC}
    Logs are stored in: ${LOG_DIR}/

EOF
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup)
                CLEANUP_MODE=true
                shift
                ;;
            --help)
                show_usage
                exit "${EXIT_SUCCESS}"
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit "${EXIT_INVALID_INPUT}"
                ;;
        esac
    done
    
    # Initialize
    init_logging
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║    ${GREEN}Docker Deployment Automation Script${CYAN}              ║${NC}"
    echo -e "${CYAN}║    ${YELLOW}Production-Grade Deployment Tool${CYAN}                 ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Collect parameters
    collect_parameters
    
    # Handle cleanup mode
    if [[ "${CLEANUP_MODE}" == "true" ]]; then
        test_ssh_connection
        perform_cleanup
        log_success "All operations completed successfully!"
        exit "${EXIT_SUCCESS}"
    fi
    
    # Execute deployment steps
    clone_or_update_repo
    test_ssh_connection
    prepare_remote_environment
    deploy_application
    configure_nginx
    
    # Final cleanup
    final_cleanup
    
    # Success message
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}║           🎉 DEPLOYMENT SUCCESSFUL! 🎉                 ║${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Application Details:${NC}"
    echo -e "  • URL: ${GREEN}http://${SERVER_IP}${NC}"
    echo -e "  • Container: ${GREEN}${APP_NAME}${NC}"
    echo -e "  • Port: ${GREEN}${APP_PORT}${NC}"
    echo -e "  • Log File: ${GREEN}${LOG_FILE}${NC}"
    echo ""
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "  • Check container: ${YELLOW}ssh -i ${SSH_KEY_PATH} ${SSH_USER}@${SERVER_IP} 'docker ps'${NC}"
    echo -e "  • View logs: ${YELLOW}ssh -i ${SSH_KEY_PATH} ${SSH_USER}@${SERVER_IP} 'docker logs ${APP_NAME}'${NC}"
    echo -e "  • Cleanup: ${YELLOW}./deploy.sh --cleanup${NC}"
    echo ""
    
    log_success "=== Deployment completed successfully at $(date) ==="
}

################################################################################
# Script Entry Point
################################################################################

# Execute main function
main "$@"

exit "${EXIT_SUCCESS}"
