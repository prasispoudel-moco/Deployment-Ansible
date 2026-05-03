#!/bin/bash

# Configuration
MAX_RETRIES=30        # Number of times to check health
SLEEP_BETWEEN=5       # Seconds between checks (Total timeout: 150s)
HEALTH_URL="/health"  # Your app's health endpoint

# 1. Determine which port is currently active
CURRENT_PORT=$(ss -tulnp | grep  $(pgrep -f "app.jar") | awk '{print $5}' | awk -F':' '{print $NF}' | head -n1)

if [ "$CURRENT_PORT" == "5000" ]; then
    IDLE_PORT="8001"
else
    IDLE_PORT="5000"
fi

echo "🚀 Starting deployment to port $IDLE_PORT..."

# 2. Start the new version
systemctl start DemoApplication@$IDLE_PORT

# 3. Health Check with Timeout Logic
echo "⏳ Waiting for app to become healthy at http://localhost:$IDLE_PORT$HEALTH_URL..."
RETRIES=0
SUCCESS=false

while [ $RETRIES -lt $MAX_RETRIES ]; do
    # Use -f to return non-zero on 4xx/5xx errors
    if curl --output /dev/null --silent --head --fail "http://localhost:$IDLE_PORT$HEALTH_URL"; then
        SUCCESS=true
        break
    fi

    RETRIES=$((RETRIES + 1))
    echo -n "."
    sleep $SLEEP_BETWEEN
done

# 4. Handover or Rollback
if [ "$SUCCESS" = true ]; then
    echo -e "\n✅ Health check passed! Switching traffic..."
    
#    # Update Apache config
#    echo "Define APP_PORT $IDLE_PORT" > /etc/apache2/conf-available/myapp-backend.conf
#    systemctl reload apache2
#    
#    # Gracefully stop the old version
#    echo "🧹 Stopping old version on port $CURRENT_PORT..."
#    systemctl stop myapp@$CURRENT_PORT
    
    echo "🎉 Deployment Successful!"
else
    echo -e "\n❌ ERROR: Health check timed out after $((MAX_RETRIES * SLEEP_BETWEEN)) seconds."
    echo "🔙 Rolling back: Stopping the failed instance on port $IDLE_PORT."
    
#    # Rollback action
#    systemctl stop myapp@$IDLE_PORT
#    
#    echo "⚠️ The old version on port $CURRENT_PORT is still live. Check your logs!"
    exit 1
fi
