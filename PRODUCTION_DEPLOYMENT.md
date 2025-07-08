# 🚀 AFFiNE Production Deployment Guide

## 📊 Current Status
- ✅ **Infrastructure**: Docker Swarm + Traefik + Swarmpit ready
- ✅ **Secrets**: AI API keys configured in Swarmpit
- ✅ **Configurations**: All Docker files and scripts ready
- ✅ **Domain**: `joyone.vn` resolves to `36.50.176.98`
- ⏳ **Subdomain**: `affine-staging.joyone.vn` needs DNS setup
- ⏳ **Deployment**: Ready to execute

## 🌐 Step 1: DNS Configuration

### Option A: Wildcard DNS (Recommended)
If wildcard DNS is already configured:
```bash
# Test if wildcard works
curl -I -H "Host: affine-staging.joyone.vn" http://36.50.176.98
```

### Option B: Specific A Record
Add DNS A record:
```
affine-staging.joyone.vn → 36.50.176.98
```

### Option C: Use Existing Subdomain Pattern
Based on working subdomains like `swarmpit-staging.joyone.vn`, use similar pattern.

## 🐳 Step 2: Deploy Test Service

### Method 1: Via Swarmpit UI (if working)
1. Go to Stacks → New Stack
2. Name: `affine-test`
3. Paste content from `docker-service-test.yml`
4. Deploy

### Method 2: Via SSH to Server
```bash
# SSH to Docker Swarm manager
ssh user@36.50.176.98

# Clone repository
git clone https://github.com/deptrai/AFFiNE.git
cd AFFiNE
git checkout clean-deployment

# Deploy test service
docker stack deploy -c docker-service-test.yml affine-test

# Check status
docker service ls | grep affine
docker service logs affine-test_affine-test
```

### Method 3: Via Jenkins Pipeline
Trigger Jenkins build to auto-deploy.

## 🔍 Step 3: Verify Test Service

### Check Service Status
```bash
# List services
docker service ls

# Check specific service
docker service ps affine-test_affine-test

# View logs
docker service logs -f affine-test_affine-test
```

### Test Domain Access
```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://affine-staging.joyone.vn

# Test HTTPS
curl -I https://affine-staging.joyone.vn

# Test with Host header if DNS not ready
curl -I -H "Host: affine-staging.joyone.vn" http://36.50.176.98
curl -I -H "Host: affine-staging.joyone.vn" https://36.50.176.98
```

### Expected Results
- ✅ Service status: `1/1 running`
- ✅ HTTP response: `200 OK` or `301/302 redirect`
- ✅ HTTPS response: `200 OK` with valid SSL
- ✅ Nginx welcome page visible

## 🚀 Step 4: Deploy AFFiNE Service

### Replace Test with AFFiNE
```bash
# Remove test service
docker stack rm affine-test

# Deploy AFFiNE service
docker stack deploy -c docker-service-affine.yml affine-staging

# Monitor deployment
watch docker service ls
```

### Verify Secrets Mount
```bash
# Check if secrets are accessible
docker exec -it $(docker ps -q -f name=affine-staging_affine) ls -la /run/secrets/

# Should show:
# copilot_openai_key
# copilot_anthropic_key
# copilot_gemini_key
# copilot_perplexity_key
```

## 🏥 Step 5: Health Checks

### Service Health
```bash
# Check all services
docker service ls

# Check AFFiNE service specifically
docker service ps affine-staging_affine --no-trunc

# Check logs
docker service logs -f affine-staging_affine
docker service logs -f affine-staging_postgres
docker service logs -f affine-staging_redis
```

### Application Health
```bash
# Test health endpoint
curl https://affine-staging.joyone.vn/api/health

# Test main application
curl https://affine-staging.joyone.vn

# Test AI functionality (if available)
curl -X POST https://affine-staging.joyone.vn/api/copilot/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}'
```

### Database Health
```bash
# Connect to PostgreSQL
docker exec -it $(docker ps -q -f name=affine-staging_postgres) psql -U affine -d affine

# Run health check
SELECT * FROM health_check();

# Check Redis
docker exec -it $(docker ps -q -f name=affine-staging_redis) redis-cli ping
```

## 🔧 Step 6: Fix Jenkins Pipeline

### Update Jenkinsfile Path
1. Go to Jenkins: https://vonic-jenkins.joyone.vn
2. Edit `affine-production-deploy` job
3. Set Pipeline → Definition → "Pipeline script from SCM"
4. Repository: `https://github.com/deptrai/AFFiNE.git`
5. Branch: `clean-deployment`
6. Script Path: `Jenkinsfile`

### Test CI/CD Pipeline
```bash
# Make a small change and push
echo "# Test CI/CD" >> README.md
git add README.md
git commit -m "test: Trigger CI/CD pipeline"
git push origin clean-deployment

# Check Jenkins build
# Should auto-trigger and deploy
```

## 🚨 Troubleshooting

### Common Issues

**1. Service Won't Start**
```bash
# Check service events
docker service ps affine-staging_affine --no-trunc

# Check node resources
docker node ls
docker system df
```

**2. Domain Not Accessible**
```bash
# Check Traefik logs
docker service logs proxy_traefik

# Verify network
docker network ls | grep proxy-net

# Test direct IP access
curl -I -H "Host: affine-staging.joyone.vn" http://36.50.176.98
```

**3. SSL Certificate Issues**
```bash
# Check Traefik configuration
docker service inspect proxy_traefik

# Check certificate resolver
docker service logs proxy_traefik | grep -i cert
```

**4. Database Connection Issues**
```bash
# Check PostgreSQL logs
docker service logs affine-staging_postgres

# Test connection
docker exec -it $(docker ps -q -f name=affine-staging_affine) \
  sh -c 'nc -z postgres 5432 && echo "DB accessible" || echo "DB not accessible"'
```

**5. Secrets Not Working**
```bash
# Verify secrets exist
docker secret ls | grep copilot

# Check secret mount in container
docker exec -it $(docker ps -q -f name=affine-staging_affine) cat /run/secrets/copilot_openai_key
```

## 📈 Monitoring & Maintenance

### Regular Checks
```bash
# Daily health check
curl -s https://affine-staging.joyone.vn/api/health | jq

# Weekly resource check
docker system df
docker service ls

# Monthly updates
docker service update --image new-image:tag affine-staging_affine
```

### Backup Procedures
```bash
# Database backup
docker exec $(docker ps -q -f name=affine-staging_postgres) \
  pg_dump -U affine affine > backup_$(date +%Y%m%d).sql

# Volume backup
docker run --rm -v affine-staging_postgres_data:/data \
  -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz /data
```

## ✅ Success Criteria

- [ ] Domain `affine-staging.joyone.vn` resolves correctly
- [ ] HTTPS access with valid SSL certificate
- [ ] AFFiNE application loads successfully
- [ ] All AI providers (OpenAI, Anthropic, Gemini, Perplexity) working
- [ ] Database and Redis healthy
- [ ] Jenkins CI/CD pipeline functional
- [ ] Health monitoring active

## 🎯 Next Steps After Deployment

1. **Performance Optimization**
   - Configure resource limits
   - Setup monitoring (Prometheus/Grafana)
   - Implement caching strategies

2. **Security Hardening**
   - Regular security updates
   - Access control review
   - Backup verification

3. **Feature Enhancement**
   - Custom domain setup
   - Additional AI providers
   - Advanced monitoring

4. **Documentation**
   - User guides
   - API documentation
   - Troubleshooting runbooks
