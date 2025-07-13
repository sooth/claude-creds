#!/bin/bash
# docker-refresh-claude.sh - Main refresh script in Docker

set -euo pipefail

# Ensure PATH includes standard locations
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# Set up log file after checking directory exists
OUTPUT_DIR="/output"
LOG_DIR="/logs"

# Create log directory if it doesn't exist
[ -d "$LOG_DIR" ] || /bin/mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/refresh-$(/bin/date +%Y%m%d-%H%M%S 2>/dev/null || echo "unknown").log"

log() {
    local msg="[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -n "${CURRENT_PROFILE:-}" ]; then
        msg="[$(/bin/date '+%Y-%m-%d %H:%M:%S')] [$CURRENT_PROFILE] $*"
    fi
    echo "$msg" | /usr/bin/tee -a "$LOG_FILE"
}

# Process each credential profile
process_profile() {
    local profile_file="$1"
    local profile=$(basename "$profile_file" .json)
    
    # Set global profile for logging
    export CURRENT_PROFILE="$profile"
    
    log "Processing profile"
    
    # Extract credentials
    local service=$(jq -r .service "$profile_file")
    local account=$(jq -r .account "$profile_file")
    local password=$(jq -r .password "$profile_file")
    
    # Parse OAuth data
    local oauth_data=$(echo "$password" | jq -r '.claudeAiOauth')
    local access_token=$(echo "$oauth_data" | jq -r '.accessToken')
    local refresh_token=$(echo "$oauth_data" | jq -r '.refreshToken') 
    local expires_at=$(echo "$oauth_data" | jq -r '.expiresAt')
    local id_token=$(echo "$oauth_data" | jq -r '.idToken // empty')
    
    # Check token expiry
    local expires_date=$(/bin/date -d @$((expires_at/1000)) 2>/dev/null || echo "Unknown")
    log "Current token expires: $expires_date"
    
    # Create Claude config directory
    mkdir -p "$HOME/.claude"
    
    # Extract additional fields from OAuth data
    local scopes=$(echo "$oauth_data" | jq -c '.scopes // ["user:inference", "user:profile"]')
    local subscription_type=$(echo "$oauth_data" | jq -r '.subscriptionType // "max"')
    
    # Create Linux credentials file matching exact format
    cat > "$HOME/.claude/.credentials.json" <<EOF
{
  "claudeAiOauth": {
    "accessToken": "$access_token",
    "refreshToken": "$refresh_token",
    "expiresAt": $expires_at,
    "scopes": $scopes,
    "subscriptionType": "$subscription_type"
  }
}
EOF
    
    # Set proper permissions
    chmod 600 "$HOME/.claude/.credentials.json"
    
    # Run Claude to trigger refresh
    log "Running Claude to trigger token refresh..."
    
    # Try to run a simple Claude command that requires authentication
    local claude_output=""
    if claude_output=$(timeout 30s /opt/claude/bin/claude --print "What is 2+2?" 2>&1); then
        log "Claude executed successfully"
        if [[ "$claude_output" == *"4"* ]]; then
            log "Claude responded correctly"
        fi
    else
        log "Claude execution failed or timed out"
        log "Error: $claude_output"
    fi
    
    # Check if credentials were updated with new tokens
    if [ -f "$HOME/.claude/.credentials.json" ]; then
        local new_oauth=$(jq -r '.claudeAiOauth' "$HOME/.claude/.credentials.json" 2>/dev/null || echo "{}")
        
        if [ "$new_oauth" != "{}" ] && [ "$new_oauth" != "null" ]; then
            local new_access_token=$(echo "$new_oauth" | jq -r '.accessToken // empty')
            local new_refresh_token=$(echo "$new_oauth" | jq -r '.refreshToken // empty')
            local new_expires_at=$(echo "$new_oauth" | jq -r '.expiresAt // 0')
            
            if [ -n "$new_access_token" ] && [ "$new_access_token" != "$access_token" ]; then
                log "✅ Token was refreshed!"
                log "New token expires: $(/bin/date -d @$((new_expires_at/1000)) 2>/dev/null || echo "Unknown")"
                
                # Create updated OAuth data
                local updated_oauth=$(echo "$oauth_data" | jq \
                    --arg access "$new_access_token" \
                    --arg refresh "${new_refresh_token:-$refresh_token}" \
                    --arg expires "${new_expires_at}" \
                    '.accessToken = $access | .refreshToken = $refresh | .expiresAt = ($expires | tonumber)')
                
                # Create updated password field
                local updated_password=$(echo "$password" | jq \
                    --argjson oauth "$updated_oauth" \
                    '.claudeAiOauth = $oauth')
                
                # Save updated profile
                mkdir -p "$OUTPUT_DIR"
                jq --arg pw "$updated_password" '.password = $pw' "$profile_file" > "$OUTPUT_DIR/${profile}.json"
            else
                log "Token unchanged - might still be valid"
                # Copy original to output
                mkdir -p "$OUTPUT_DIR"
                cp "$profile_file" "$OUTPUT_DIR/${profile}.json"
            fi
        else
            log "No auth tokens found in config"
            mkdir -p "$OUTPUT_DIR"
            cp "$profile_file" "$OUTPUT_DIR/${profile}.json"
        fi
    fi
    
    # Clean up
    rm -f "$HOME/.claude/.credentials.json"
    
    # Clear profile from logging
    unset CURRENT_PROFILE
}

# Main
log "Starting Claude token refresh in Docker"

# Check if Claude is available
if [ ! -f "/opt/claude/bin/claude" ]; then
    log "ERROR: Claude not found at /opt/claude/bin/claude"
    exit 1
fi

# Process all profiles
for profile_file in /creds/*.json; do
    [ -f "$profile_file" ] || continue
    
    # Skip hidden files
    profile=$(basename "$profile_file" .json)
    if [[ "$profile" =~ ^\. ]]; then
        continue
    fi
    
    process_profile "$profile_file"
    
    # Small delay between profiles
    sleep 2
done

# Copy metadata files
for file in /creds/.*; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    [ "$filename" = "." ] || [ "$filename" = ".." ] && continue
    cp "$file" "$OUTPUT_DIR/$filename" 2>/dev/null || true
done

log "Token refresh complete"