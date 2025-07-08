# 🚀 AFFiNE Production Deployment Guide

Complete guide for deploying AFFiNE to production using Docker Swarm, Jenkins CI/CD, and Swarmpit.

## 📋 Prerequisites

- Docker Swarm cluster running
- Swarmpit dashboard access
- Jenkins server access
- Domain with SSL certificate
- Docker registry access

## 🔧 Phase 1: Infrastructure Setup

### 1.1 Swarmpit Secrets Configuration

Access Swarmpit at: https://swarmpit-staging.joyone.vn
- Username: `admin`
- Password: `SlTy6stYQ5BIeq2CHvAMlwt6i8`

**Create the following secrets:**

1. **OpenAI API Key**
   - Name: `copilot_openai_key`
   - Data: Your OpenAI API key (sk-...)

2. **Anthropic API Key**
   - Name: `copilot_anthropic_key`
   - Data: Your Anthropic API key (sk-ant-...)

3. **Gemini API Key**
   - Name: `copilot_gemini_key`
   - Data: Your Google Gemini API key

4. **Perplexity API Key**
   - Name: `copilot_perplexity_key`
   - Data: Your Perplexity API key (pplx-...)

### 1.2 Network Setup

Ensure the following networks exist:
- `traefik_network` (external, for reverse proxy)
- `affine_network` (overlay, for internal communication)

## 🐳 Phase 2: Docker Registry Setup

### 2.1 Build and Push Initial Image

```bash
# Build the image
docker build -t registry.joyone.vn/affine:latest .

# Push to registry
docker push registry.joyone.vn/affine:latest
```

### 2.2 Test Local Deployment

```bash
# Copy environment file
cp .env.example .env

# Edit .env with your actual values
nano .env

# Start local stack
docker-compose up -d

# Test health endpoint
curl http://localhost:3010/api/health

# Stop local stack
docker-compose down
```

## 🔄 Phase 3: Jenkins CI/CD Setup

### 3.1 Create Jenkins Pipeline

1. Access Jenkins: https://vonic-jenkins.joyone.vn
2. Create new Pipeline job:
   - Name: `affine-production-deploy`
   - Type: Pipeline
   - Source: SCM (Git)
   - Repository: Your AFFiNE repository
   - Branch: `clean-deployment`
   - Script Path: `Jenkinsfile`

### 3.2 Configure Build Triggers

1. Enable "GitHub hook trigger for GITScm polling"
2. Configure webhook in GitHub:
   - URL: `https://vonic-jenkins.joyone.vn/github-webhook/`
   - Content-Type: `application/json`
   - Events: Push events

### 3.3 Environment Variables in Jenkins

Configure the following environment variables in Jenkins:
- `DOCKER_REGISTRY=registry.joyone.vn`
- `STACK_NAME=affine-production`
- `DOMAIN=affine.joyone.vn`

## 🌊 Phase 4: Docker Swarm Deployment

### 4.1 Deploy Stack via Swarmpit

1. Go to Stacks in Swarmpit
2. Create new stack:
   - Name: `affine-production`
   - Compose file: Copy content from `docker-stack.yml`
3. Deploy the stack

### 4.2 Manual Stack Deployment (Alternative)

```bash
# Deploy stack via command line
docker stack deploy -c docker-stack.yml affine-production

# Check stack status
docker stack ps affine-production

# Check service logs
docker service logs affine-production_affine
```

## 🔍 Phase 5: Monitoring & Verification

### 5.1 Health Checks

```bash
# Check application health
curl https://affine-staging.joyone.vn/api/health

# Check service status
docker service ls | grep affine

# Check container logs
docker service logs -f affine-production_affine
```

### 5.2 Database Verification

```bash
# Connect to PostgreSQL
docker exec -it $(docker ps -q -f name=affine-production_postgres) psql -U affine -d affine

# Run health check
SELECT * FROM health_check();

# Exit
\q
```

### 5.3 Redis Verification

```bash
# Connect to Redis
docker exec -it $(docker ps -q -f name=affine-production_redis) redis-cli

# Test connection
ping

# Exit
exit
```

## 🚨 Phase 6: Troubleshooting

### 6.1 Common Issues

**Issue: Container fails to start**
```bash
# Check container logs
docker service logs affine-production_affine

# Check service events
docker service ps affine-production_affine --no-trunc
```

**Issue: Database connection fails**
```bash
# Check PostgreSQL logs
docker service logs affine-production_postgres

# Verify database is accessible
docker exec -it $(docker ps -q -f name=postgres) pg_isready -U affine
```

**Issue: AI features not working**
```bash
# Verify secrets are mounted
docker exec -it $(docker ps -q -f name=affine) ls -la /run/secrets/

# Check configuration
docker exec -it $(docker ps -q -f name=affine) cat /app/config/config.json
```

### 6.2 Rollback Procedure

```bash
# Rollback to previous version
docker service rollback affine-production_affine

# Or deploy specific version
docker service update --image registry.joyone.vn/affine:previous-tag affine-production_affine
```

### 6.3 Scaling

```bash
# Scale application service
docker service scale affine-production_affine=3

# Check scaling status
docker service ps affine-production_affine
```

## 📊 Phase 7: Maintenance

### 7.1 Regular Tasks

**Daily:**
- Check application logs
- Monitor resource usage
- Verify health endpoints

**Weekly:**
- Update Docker images
- Clean up unused images/containers
- Review security logs

**Monthly:**
- Update dependencies
- Review and rotate secrets
- Performance optimization

### 7.2 Backup Procedures

**Database Backup:**
```bash
# Manual backup
docker exec $(docker ps -q -f name=postgres) pg_dump -U affine affine > backup_$(date +%Y%m%d).sql

# Automated backup (included in stack with profile)
docker stack deploy -c docker-stack.yml --with-registry-auth affine-production
```

**Configuration Backup:**
```bash
# Backup Swarmpit configuration
# Export stack configuration from Swarmpit UI

# Backup Jenkins configuration
# Use Jenkins backup plugins
```

## 🔐 Security Considerations

1. **Secrets Management:**
   - Rotate API keys regularly
   - Use Docker secrets, not environment variables
   - Monitor secret access logs

2. **Network Security:**
   - Use overlay networks for internal communication
   - Implement proper firewall rules
   - Enable SSL/TLS for all external connections

3. **Access Control:**
   - Limit Swarmpit access
   - Use role-based access in Jenkins
   - Regular security audits

## 📈 Performance Optimization

1. **Resource Limits:**
   - Set appropriate CPU/memory limits
   - Monitor resource usage
   - Scale based on demand

2. **Database Optimization:**
   - Regular VACUUM and ANALYZE
   - Monitor slow queries
   - Optimize indexes

3. **Caching:**
   - Configure Redis properly
   - Implement application-level caching
   - Use CDN for static assets

## 🎯 Success Criteria

✅ Application accessible at https://affine-staging.joyone.vn
✅ All AI providers working correctly
✅ Database and Redis healthy
✅ CI/CD pipeline functional
✅ Monitoring and logging active
✅ Backup procedures in place
✅ Security measures implemented
