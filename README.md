# claude-creds 🔐

A convenient Bash script for managing multiple Claude CLI authentication profiles on macOS.

## Overview

`claude-creds` allows you to save and switch between different Claude CLI credentials stored in your macOS Keychain. This is particularly useful when working with multiple Claude accounts or switching between personal and work profiles.

## Features

- 🔑 **Secure Storage**: Leverages macOS Keychain for secure credential storage
- 👥 **Multiple Profiles**: Save and manage multiple authentication profiles
- 🔄 **Easy Switching**: Quickly switch between different Claude accounts
- 🔒 **Touch ID Support**: Integrates with macOS security features
- 📁 **JSON Backup**: Exports credentials to encrypted JSON files

## Requirements

- macOS (uses Keychain Services)
- Claude CLI installed and authenticated at least once
- Bash shell
- Python 3 (comes pre-installed on macOS)

## Installation

1. Clone this repository or download the script:
   ```bash
   git clone https://github.com/yourusername/claude-creds.git
   cd claude-creds
   ```

2. Make the script executable:
   ```bash
   chmod +x claude-creds.sh
   ```

3. (Optional) Add to your PATH for global access:
   ```bash
   ln -s $(pwd)/claude-creds.sh /usr/local/bin/claude-creds
   ```

## Usage

### Basic Commands

#### Backup current credentials
Save your current Claude CLI credentials to a named profile:
```bash
./claude-creds.sh backup work
```

#### Switch to a different profile
Restore credentials from a saved profile:
```bash
./claude-creds.sh switch personal
# or
./claude-creds.sh restore personal
```

#### List available profiles
View all saved credential profiles:
```bash
./claude-creds.sh list
```

### Advanced Options

#### Custom Keychain Service
If Claude CLI uses a non-standard Keychain service name:
```bash
./claude-creds.sh --service "Custom-Claude-Service" backup myprofile
```

#### Custom Storage Directory
Override the default credential storage location:
```bash
export CLAUDE_CREDS_DIR="$HOME/my-claude-profiles"
./claude-creds.sh backup myprofile
```

## How It Works

1. **Backup**: The script reads your current Claude credentials from the macOS Keychain and saves them to a JSON file in `~/.claude/cred_profiles/`
2. **Restore**: When switching profiles, it reads the saved JSON file and updates the Keychain with those credentials
3. **Security**: Profile files are created with 600 permissions (read/write for owner only)

## File Locations

- **Default credential storage**: `~/.claude/cred_profiles/`
- **Profile format**: `<profile-name>.json`
- **Keychain location**: `~/Library/Keychains/login.keychain-db`

## Security Considerations

- Credential files are stored with restrictive permissions (600)
- The script may trigger Touch ID or password prompts when accessing Keychain
- Profile names must contain only letters, numbers, underscores, or hyphens
- Consider encrypting the credential directory for additional security

## Troubleshooting

### "Claude credential not found"
Run `claude /login` first to authenticate with Claude CLI, or use the `--service` flag if your Keychain service has a custom name.

### "Keychain denied read access"
Approve the Keychain access prompt when it appears, then rerun the command.

### Profile not found
Check that the profile exists with `./claude-creds.sh list` and verify the profile name spelling.

## Example Workflow

```bash
# Initial setup - authenticate with work account
claude /login

# Save work credentials
./claude-creds.sh backup work

# Switch to personal account in Claude CLI
claude /logout
claude /login  # Login with personal credentials

# Save personal credentials
./claude-creds.sh backup personal

# Now you can switch between accounts easily
./claude-creds.sh switch work    # Switch to work account
./claude-creds.sh switch personal # Switch to personal account
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This script is provided as-is for personal use. See LICENSE file for details.

## Author

Created for managing multiple Claude CLI authentication profiles on macOS.