#!/bin/bash

# Script to create runtime configuration for AFFiNE
# This script reads secrets and environment variables to create the final config.json

set -e

CONFIG_DIR="/app/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
TEMPLATE_FILE="/app/config.json"

echo "🔧 Creating runtime configuration..."

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Function to read secret or environment variable
read_secret_or_env() {
    local secret_file="/run/secrets/$1"
    local env_var="$2"
    
    if [ -f "$secret_file" ]; then
        cat "$secret_file"
    elif [ -n "${!env_var}" ]; then
        echo "${!env_var}"
    else
        echo ""
    fi
}

# Read API keys from secrets or environment variables
OPENAI_KEY=$(read_secret_or_env "copilot_openai_key" "COPILOT_OPENAI_API_KEY")
ANTHROPIC_KEY=$(read_secret_or_env "copilot_anthropic_key" "COPILOT_ANTHROPIC_API_KEY")
GEMINI_KEY=$(read_secret_or_env "copilot_gemini_key" "COPILOT_GEMINI_API_KEY")
PERPLEXITY_KEY=$(read_secret_or_env "copilot_perplexity_key" "COPILOT_PERPLEXITY_API_KEY")

# Create the configuration JSON
cat > "$CONFIG_FILE" << EOF
{
  "\$schema": "https://github.com/toeverything/affine/releases/latest/download/config.schema.json",
  "copilot": {
    "enabled": true,
    "providers": {
      "openai": {
        "apiKey": "$OPENAI_KEY"
      },
      "anthropic": {
        "apiKey": "$ANTHROPIC_KEY"
      },
      "gemini": {
        "apiKey": "$GEMINI_KEY"
      },
      "perplexity": {
        "apiKey": "$PERPLEXITY_KEY"
      }
    }
  },
  "imageProxyUrl": "/api/worker/image-proxy",
  "server": {
    "host": "0.0.0.0",
    "port": 3010
  },
  "database": {
    "url": "${DATABASE_URL:-postgres://affine:affine@postgres:5432/affine}"
  },
  "redis": {
    "host": "${REDIS_SERVER_HOST:-redis}",
    "port": ${REDIS_SERVER_PORT:-6379}
  },
  "storage": {
    "path": "/app/storage"
  },
  "logging": {
    "level": "${LOG_LEVEL:-info}",
    "format": "json"
  },
  "security": {
    "cors": {
      "origin": true,
      "credentials": true
    }
  }
}
EOF

echo "✅ Runtime configuration created at $CONFIG_FILE"

# Validate JSON
if command -v node >/dev/null 2>&1; then
    if node -e "JSON.parse(require('fs').readFileSync('$CONFIG_FILE', 'utf8'))" 2>/dev/null; then
        echo "✅ Configuration JSON is valid"
    else
        echo "❌ Configuration JSON is invalid"
        exit 1
    fi
fi

# Set proper permissions
chmod 600 "$CONFIG_FILE"

echo "🚀 Configuration ready for AFFiNE startup"
