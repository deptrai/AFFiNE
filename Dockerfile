# Multi-stage build for AFFiNE production
FROM node:18-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    curl \
    git \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Copy package files for dependency installation
COPY package.json yarn.lock ./
COPY packages/backend/server/package.json ./packages/backend/server/
COPY packages/frontend/core/package.json ./packages/frontend/core/
COPY packages/common/infra/package.json ./packages/common/infra/

# Install dependencies
RUN yarn install --frozen-lockfile --production=false

# Build stage
FROM base AS builder

# Copy source code
COPY . .

# Build the application
RUN yarn build

# Production stage
FROM node:18-alpine AS production

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    dumb-init \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S affine && \
    adduser -S affine -u 1001

# Copy built application from builder stage
COPY --from=builder --chown=affine:affine /app/dist ./dist
COPY --from=builder --chown=affine:affine /app/packages ./packages
COPY --from=builder --chown=affine:affine /app/scripts ./scripts
COPY --from=builder --chown=affine:affine /app/node_modules ./node_modules
COPY --from=builder --chown=affine:affine /app/package.json ./

# Copy config template
COPY --chown=affine:affine config.json ./config.json

# Create necessary directories
RUN mkdir -p /app/storage /app/config && \
    chown -R affine:affine /app

# Switch to non-root user
USER affine

# Expose port
EXPOSE 3010

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3010/api/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "./dist/index.js"]
