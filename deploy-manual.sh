#!/bin/bash

# Manual deployment script for AFFiNE on Docker Swarm
# This script provides commands to deploy AFFiNE when Swarmpit UI has issues

set -e

echo "🚀 AFFiNE Manual Deployment Script"
echo "=================================="

# Configuration
STACK_NAME="affine-staging"
DOMAIN="affine-staging.joyone.vn"
IMAGE="nginx:alpine"  # Start with nginx for testing
NETWORK="proxy-net"

echo "📋 Configuration:"
echo "  Stack Name: $STACK_NAME"
echo "  Domain: $DOMAIN"
echo "  Image: $IMAGE"
echo "  Network: $NETWORK"
echo ""

# Function to create test service
create_test_service() {
    echo "🔧 Creating test service..."
    
    cat > docker-service-test.yml << EOF
version: '3.8'

services:
  affine-test:
    image: $IMAGE
    networks:
      - $NETWORK
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.affine-test-http.rule=Host(\`$DOMAIN\`)"
        - "traefik.http.routers.affine-test-http.entrypoints=web"
        - "traefik.http.routers.affine-test-http.service=affine-test-http"
        - "traefik.http.routers.affine-test-https.rule=Host(\`$DOMAIN\`)"
        - "traefik.http.routers.affine-test-https.entrypoints=websecure"
        - "traefik.http.routers.affine-test-https.service=affine-test-https"
        - "traefik.http.routers.affine-test-https.tls=true"
        - "traefik.http.routers.affine-test-https.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.affine-test-http.loadbalancer.server.port=80"
        - "traefik.http.services.affine-test-https.loadbalancer.server.port=80"

networks:
  $NETWORK:
    external: true
EOF

    echo "✅ Test service configuration created: docker-service-test.yml"
}

# Function to create full AFFiNE service
create_affine_service() {
    echo "🔧 Creating AFFiNE service..."
    
    cat > docker-service-affine.yml << EOF
version: '3.8'

services:
  affine:
    image: node:18-alpine
    networks:
      - $NETWORK
      - affine-internal
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgres://affine:affine@postgres:5432/affine
      - REDIS_SERVER_HOST=redis
      - REDIS_SERVER_PORT=6379
    secrets:
      - copilot_openai_key
      - copilot_anthropic_key
      - copilot_gemini_key
      - copilot_perplexity_key
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.affine-http.rule=Host(\`$DOMAIN\`)"
        - "traefik.http.routers.affine-http.entrypoints=web"
        - "traefik.http.routers.affine-http.service=affine-http"
        - "traefik.http.routers.affine-https.rule=Host(\`$DOMAIN\`)"
        - "traefik.http.routers.affine-https.entrypoints=websecure"
        - "traefik.http.routers.affine-https.service=affine-https"
        - "traefik.http.routers.affine-https.tls=true"
        - "traefik.http.routers.affine-https.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.affine-http.loadbalancer.server.port=3010"
        - "traefik.http.services.affine-https.loadbalancer.server.port=3010"
    command: ["sh", "-c", "echo 'AFFiNE placeholder - replace with actual build' && sleep 3600"]
    volumes:
      - affine_storage:/app/storage

  postgres:
    image: postgres:15-alpine
    networks:
      - affine-internal
    environment:
      - POSTGRES_DB=affine
      - POSTGRES_USER=affine
      - POSTGRES_PASSWORD=affine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      placement:
        constraints:
          - node.role == manager

  redis:
    image: redis:7-alpine
    networks:
      - affine-internal
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  affine_storage:
    driver: local

networks:
  $NETWORK:
    external: true
  affine-internal:
    driver: overlay
    attachable: true

secrets:
  copilot_openai_key:
    external: true
  copilot_anthropic_key:
    external: true
  copilot_gemini_key:
    external: true
  copilot_perplexity_key:
    external: true
EOF

    echo "✅ AFFiNE service configuration created: docker-service-affine.yml"
}

# Function to show deployment commands
show_deployment_commands() {
    echo ""
    echo "🚀 DEPLOYMENT COMMANDS:"
    echo "======================"
    echo ""
    echo "1. Deploy test service:"
    echo "   docker stack deploy -c docker-service-test.yml $STACK_NAME-test"
    echo ""
    echo "2. Check test service status:"
    echo "   docker service ls | grep $STACK_NAME"
    echo "   docker service logs $STACK_NAME-test_affine-test"
    echo ""
    echo "3. Test domain access:"
    echo "   curl -I http://$DOMAIN"
    echo "   curl -I https://$DOMAIN"
    echo ""
    echo "4. Deploy full AFFiNE service:"
    echo "   docker stack deploy -c docker-service-affine.yml $STACK_NAME"
    echo ""
    echo "5. Monitor deployment:"
    echo "   docker service ls"
    echo "   docker service logs $STACK_NAME_affine"
    echo "   docker service ps $STACK_NAME_affine"
    echo ""
    echo "6. Health check:"
    echo "   curl https://$DOMAIN/api/health"
    echo ""
    echo "7. Cleanup if needed:"
    echo "   docker stack rm $STACK_NAME-test"
    echo "   docker stack rm $STACK_NAME"
    echo ""
}

# Function to show troubleshooting
show_troubleshooting() {
    echo "🔍 TROUBLESHOOTING:"
    echo "=================="
    echo ""
    echo "1. Check if domain resolves:"
    echo "   nslookup $DOMAIN"
    echo ""
    echo "2. Check Traefik status:"
    echo "   docker service ls | grep traefik"
    echo "   docker service logs proxy_traefik"
    echo ""
    echo "3. Check network connectivity:"
    echo "   docker network ls | grep $NETWORK"
    echo ""
    echo "4. Check secrets:"
    echo "   docker secret ls | grep copilot"
    echo ""
    echo "5. Service debugging:"
    echo "   docker service inspect $STACK_NAME_affine"
    echo "   docker service ps $STACK_NAME_affine --no-trunc"
    echo ""
    echo "6. Container debugging:"
    echo "   docker exec -it \$(docker ps -q -f name=$STACK_NAME) sh"
    echo ""
}

# Main execution
echo "🔧 Generating deployment configurations..."
create_test_service
create_affine_service
show_deployment_commands
show_troubleshooting

echo ""
echo "✅ Manual deployment script completed!"
echo "📁 Files created:"
echo "   - docker-service-test.yml (test service)"
echo "   - docker-service-affine.yml (full AFFiNE service)"
echo ""
echo "🎯 Next steps:"
echo "   1. SSH to your Docker Swarm manager node"
echo "   2. Copy the generated YAML files to the server"
echo "   3. Run the deployment commands shown above"
echo "   4. Monitor and verify the deployment"
echo ""
