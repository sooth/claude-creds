# Claude OAuth Token Refresh System

Automatically refresh Claude OAuth tokens for multiple accounts using Docker isolation, preventing token expiration and maintaining continuous access.

## 🚀 Quick Start

**Prerequisites**: macOS, Docker, Claude CLI (`npm install -g @anthropic-ai/claude-code`)

### Single Account Setup
```bash
# 1. Export your Claude credentials from Keychain
./claude-creds.sh backup myprofile    # Creates a profile named 'myprofile'

# 2. Build the Docker image
./build.sh

# 3. Prepare Claude binary for Docker (first time only)
./claude-refresh-docker.sh prepare

# 4. Test token refresh manually
./claude-refresh-docker.sh run

# 5. Set up automatic refresh every 15 minutes
./setup-auto-refresh.sh
```

### Multiple Accounts Setup
```bash
# 1. Export credentials for first account (e.g., work)
./claude-creds.sh backup work

# 2. Switch accounts in Claude (restart Claude to apply changes)
./claude-creds.sh switch personal   # If you have 'personal' saved already
# OR manually login to your second account:
# - Quit Claude completely (Cmd+Q)
# - Start Claude and login with second account

# 3. Export credentials for second account
./claude-creds.sh backup personal

# 4. Continue with steps 2-5 from Single Account Setup above
```

That's it! Your tokens for both accounts will be refreshed automatically.

## 📋 User Scripts

These are the only scripts you need to interact with:

### `claude-creds.sh`
Manage credential profiles (backup/restore from macOS Keychain)
```bash
./claude-creds.sh backup dm      # Backup 'dm' profile
./claude-creds.sh restore dm     # Restore 'dm' profile  
./claude-creds.sh list           # List all profiles
./claude-creds.sh switch aa      # Switch to 'aa' profile
```
**Note**: After switching profiles with `restore` or `switch`, restart Claude (Cmd+Q and reopen) to use the new credentials.

### `build.sh`
Build the Docker image (run once or after updates)
```bash
./build.sh
```

### `claude-refresh-docker.sh`
Main refresh orchestration
```bash
./claude-refresh-docker.sh prepare  # Copy Claude binary (first time only)
./claude-refresh-docker.sh run      # Run token refresh for all profiles
```

### `setup-auto-refresh.sh`
Install automatic refresh every 15 minutes
```bash
./setup-auto-refresh.sh              # Install
launchctl unload ~/Library/LaunchAgents/com.claude.refresh.plist  # Uninstall
```

### `sync-refreshed-profiles.sh`
Sync refreshed tokens back to Keychain (called automatically)
```bash
./sync-refreshed-profiles.sh         # Manual sync if needed
```

## 🔧 How It Works

1. **Export**: Claude credentials are exported from macOS Keychain
2. **Docker**: Linux container runs Claude CLI with credentials
3. **Refresh**: Claude automatically refreshes tokens when accessed
4. **Sync**: Updated tokens are synced back to macOS Keychain

The system runs in complete isolation using Docker, preventing any interference with your active Claude sessions.

## 📚 Detailed Documentation

### Architecture

The system consists of three main components:

1. **Credential Management** (`claude-creds.sh`)
   - Interfaces with macOS Keychain using the `security` command
   - Exports credentials in JSON format
   - Manages multiple profiles (work, personal, etc.)

2. **Docker Refresh Environment**
   - Ubuntu 22.04 base with Node.js 22
   - Isolated environment prevents interference
   - Linux Claude CLI uses `.credentials.json` format

3. **Automatic Scheduling**
   - macOS LaunchAgent runs every 15 minutes
   - Logs to `~/.claude/sync_logs/`

### Token Format

Tokens are stored as JSON in the macOS Keychain:
```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1752466160663,
    "scopes": ["user:inference", "user:profile"],
    "subscriptionType": "max"
  }
}
```

### Monitoring

View logs to monitor token refresh:
```bash
# Watch real-time logs
tail -f ~/.claude/sync_logs/refresh-*.log

# Check specific profile
tail -f ~/.claude/sync_logs/refresh-*.log | grep "[dm]"

# View LaunchAgent logs
tail -f ~/.claude/sync_logs/launchd-refresh-stdout.log
```

### Configuration

- **Refresh Interval**: Edit `StartInterval` in `com.claude.refresh.plist` (default: 900 seconds)
- **Profiles**: Stored in `~/.claude/cred_profiles/`
- **Logs**: Located in `~/.claude/sync_logs/`

## 🔍 Troubleshooting

### "Claude AI usage limit reached"
This is normal for accounts that have hit their limit. The token is still valid but cannot be used until the limit resets.

### "Invalid API key"
The token has expired. The refresh should update it automatically. If not:
1. Log in manually: `claude` (on host)
2. Re-export the profile: `./claude-creds.sh backup [profile]`

### Docker build fails
Ensure Docker is running and you have sufficient disk space.

### Tokens not refreshing
Check logs for errors:
```bash
docker logs $(docker ps -lq)
cat ~/.claude/sync_logs/refresh-*.log | tail -50
```

## 📁 Complete File Reference

### Essential Files (7)
- `claude-creds.sh` - Credential management
- `Dockerfile` - Docker image definition
- `docker-refresh-claude.sh` - Runs inside container
- `claude-refresh-docker.sh` - Orchestrates refresh
- `setup-auto-refresh.sh` - Automatic scheduling
- `com.claude.refresh.plist` - LaunchAgent config
- `sync-refreshed-profiles.sh` - Sync tokens back

### Supporting Files
- `build.sh` - Simple Docker build script
- `.dockerignore` - Excludes unnecessary files from Docker
- `claude-docker/` - Directory with Claude binary and dependencies

### Generated Directories
- `~/.claude/cred_profiles/` - Stored credential profiles
- `~/.claude/cred_profiles_refreshed/` - Refreshed profiles
- `~/.claude/sync_logs/` - All logs

## 🔒 Security

- Credentials are stored in macOS Keychain (encrypted)
- Docker container runs as non-root user
- Credentials files have 600 permissions
- No credentials are logged or exposed

## 📝 License

This tool is provided as-is for managing Claude OAuth tokens. Use at your own risk.