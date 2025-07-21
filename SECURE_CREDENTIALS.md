# SECURE CREDENTIALS - DO NOT COMMIT TO GIT

⚠️ **WARNING: This file contains sensitive information and should NEVER be committed to version control**

## SSH Keys Referenced in Logs

The following SSH key files are referenced in the project logs but do NOT contain actual key content:

### Working Keys (ED25519)
- `~/.ssh/vastai_ed25519` - Private key (working)
- `~/.ssh/vastai_ed25519.pub` - Public key (working)

### Failed Keys (RSA)  
- `~/.ssh/vastai_mibera` - Private key (failed RSA)
- `~/.ssh/vastai_mibera.pub` - Public key (failed RSA)

## Important Notes

1. **No actual key content was found in the logs** - only file paths and commands
2. **SSH commands shown are safe** - they only reference file paths, not key content
3. **Server IP and port are public information** - 136.59.129.136:34538
4. **This document is for reference only** - actual keys should be stored securely

## Security Recommendations

- Store SSH keys in `~/.ssh/` with proper permissions (600 for private, 644 for public)
- Never commit actual key content to version control
- Use SSH key passphrases for additional security
- Rotate keys regularly
- Monitor for unauthorized access

## Commands Referenced (Safe to Share)

```bash
# Key generation commands (safe)
ssh-keygen -t ed25519 -f ~/.ssh/vastai_ed25519
ssh-keygen -t rsa -f ~/.ssh/vastai_mibera

# Connection commands (safe - only file paths)
ssh -i ~/.ssh/vastai_ed25519 -p 34538 root@136.59.129.136
scp -i ~/.ssh/vastai_ed25519 -P 34538 root@136.59.129.136:/path/to/file local/path
```

---
**Last Updated**: $(date)
**Status**: No actual key content found in logs - only safe references 