#!/bin/bash

# Remote deployment script for AFFiNE
# This script deploys AFFiNE to remote Docker Swarm via SSH

set -e

# Configuration
REMOTE_HOST="36.50.176.98"
REMOTE_USER="root"  # Adjust as needed
STACK_NAME="affine-staging"
DOMAIN="affine-staging.joyone.vn"
REPO_URL="https://github.com/deptrai/AFFiNE.git"
BRANCH="clean-deployment"

echo "🚀 AFFiNE Remote Deployment Script"
echo "=================================="
echo "Target: $REMOTE_USER@$REMOTE_HOST"
echo "Stack: $STACK_NAME"
echo "Domain: $DOMAIN"
echo ""

# Function to execute remote commands
remote_exec() {
    echo "📡 Executing: $1"
    ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "$1"
}

# Function to copy files to remote
remote_copy() {
    echo "📁 Copying: $1 → $2"
    scp -o StrictHostKeyChecking=no "$1" "$REMOTE_USER@$REMOTE_HOST:$2"
}

# Function to test SSH connection
test_connection() {
    echo "🔍 Testing SSH connection..."
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo 'Connection successful'"; then
        echo "✅ SSH connection successful"
        return 0
    else
        echo "❌ SSH connection failed"
        echo "💡 Please ensure:"
        echo "   - SSH key is configured"
        echo "   - User has Docker Swarm access"
        echo "   - Host is accessible"
        return 1
    fi
}

# Function to check Docker Swarm status
check_swarm() {
    echo "🐳 Checking Docker Swarm status..."
    remote_exec "docker node ls" || {
        echo "❌ Docker Swarm not accessible"
        return 1
    }
    echo "✅ Docker Swarm is running"
}

# Function to check existing services
check_existing() {
    echo "🔍 Checking existing services..."
    remote_exec "docker service ls | grep -E '(affine|$STACK_NAME)' || echo 'No existing AFFiNE services found'"
}

# Function to deploy test service
deploy_test() {
    echo "🧪 Deploying test service..."
    
    # Copy test service file
    remote_copy "docker-service-test.yml" "/tmp/docker-service-test.yml"
    
    # Deploy test service
    remote_exec "docker stack deploy -c /tmp/docker-service-test.yml $STACK_NAME-test"
    
    # Wait for deployment
    echo "⏳ Waiting for test service to start..."
    sleep 30
    
    # Check status
    remote_exec "docker service ls | grep $STACK_NAME-test"
    remote_exec "docker service ps $STACK_NAME-test_affine-test --no-trunc"
}

# Function to test domain access
test_domain() {
    echo "🌐 Testing domain access..."
    
    # Test with Host header
    echo "Testing with Host header..."
    curl -I -H "Host: $DOMAIN" "http://$REMOTE_HOST" || echo "HTTP test failed"
    
    # Test direct domain (if DNS is ready)
    echo "Testing direct domain..."
    curl -I "http://$DOMAIN" || echo "Direct domain test failed (DNS may not be ready)"
    
    # Check service logs
    echo "📋 Checking service logs..."
    remote_exec "docker service logs $STACK_NAME-test_affine-test --tail 20"
}

# Function to deploy full AFFiNE service
deploy_affine() {
    echo "🚀 Deploying full AFFiNE service..."
    
    # Remove test service
    echo "🗑️ Removing test service..."
    remote_exec "docker stack rm $STACK_NAME-test" || echo "No test service to remove"
    
    # Wait for cleanup
    sleep 10
    
    # Copy AFFiNE service file
    remote_copy "docker-service-affine.yml" "/tmp/docker-service-affine.yml"
    
    # Deploy AFFiNE service
    remote_exec "docker stack deploy -c /tmp/docker-service-affine.yml $STACK_NAME"
    
    # Wait for deployment
    echo "⏳ Waiting for AFFiNE service to start..."
    sleep 60
    
    # Check status
    remote_exec "docker service ls | grep $STACK_NAME"
    remote_exec "docker service ps $STACK_NAME_affine --no-trunc"
}

# Function to verify deployment
verify_deployment() {
    echo "🔍 Verifying deployment..."
    
    # Check all services
    echo "📊 Service status:"
    remote_exec "docker service ls"
    
    # Check AFFiNE service specifically
    echo "🎯 AFFiNE service details:"
    remote_exec "docker service ps $STACK_NAME_affine"
    
    # Check logs
    echo "📋 Recent logs:"
    remote_exec "docker service logs $STACK_NAME_affine --tail 50"
    
    # Test health endpoint
    echo "🏥 Testing health endpoint..."
    curl -s "http://$DOMAIN/api/health" || curl -s -H "Host: $DOMAIN" "http://$REMOTE_HOST/api/health" || echo "Health check failed"
}

# Function to show status
show_status() {
    echo ""
    echo "📊 DEPLOYMENT STATUS"
    echo "==================="
    remote_exec "docker service ls | grep -E '(NAME|$STACK_NAME)'"
    echo ""
    echo "🌐 Access URLs:"
    echo "   HTTP:  http://$DOMAIN"
    echo "   HTTPS: https://$DOMAIN"
    echo "   Health: https://$DOMAIN/api/health"
    echo ""
}

# Function to cleanup
cleanup() {
    echo "🗑️ Cleaning up deployment..."
    remote_exec "docker stack rm $STACK_NAME" || echo "No stack to remove"
    remote_exec "docker stack rm $STACK_NAME-test" || echo "No test stack to remove"
    echo "✅ Cleanup completed"
}

# Main execution
case "${1:-deploy}" in
    "test-connection")
        test_connection
        ;;
    "check")
        test_connection && check_swarm && check_existing
        ;;
    "test")
        test_connection && check_swarm && deploy_test && test_domain
        ;;
    "deploy")
        test_connection && check_swarm && deploy_test && test_domain && deploy_affine && verify_deployment && show_status
        ;;
    "affine-only")
        test_connection && check_swarm && deploy_affine && verify_deployment && show_status
        ;;
    "verify")
        test_connection && verify_deployment && show_status
        ;;
    "status")
        test_connection && show_status
        ;;
    "cleanup")
        test_connection && cleanup
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  test-connection  Test SSH connection only"
        echo "  check           Check infrastructure status"
        echo "  test            Deploy and test nginx service only"
        echo "  deploy          Full deployment (test → AFFiNE)"
        echo "  affine-only     Deploy AFFiNE service only"
        echo "  verify          Verify existing deployment"
        echo "  status          Show current status"
        echo "  cleanup         Remove all deployed services"
        echo "  help            Show this help"
        echo ""
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

echo ""
echo "✅ Script completed!"
