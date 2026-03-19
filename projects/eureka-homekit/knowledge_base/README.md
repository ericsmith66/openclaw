# Knowledge Base - Security Guidelines

## Purpose
This directory contains documentation, blueprints, and reference materials for the Eureka HomeKit project. 

## ⚠️ CRITICAL: Preventing Sensitive Data Leaks

### Rules for Knowledge Base Content

1. **NEVER commit raw configuration files**
   - ❌ No `config.json`, `homebridge.json`, `.env` files
   - ❌ No files containing plaintext passwords, API keys, or tokens
   - ❌ No private keys, certificates, or cryptographic materials
   - ✅ Use `.example` files with placeholders (e.g., `homebridge.json.example`)

2. **Use placeholders for examples**
   - Replace credentials with `YOUR_API_KEY`, `YOUR_PASSWORD`, `REDACTED`
   - Replace device IDs with `YOUR_DEVICE_ID` or `XXXXXXXX`
   - Replace IP addresses with `192.168.1.XXX` or `YOUR_IP_ADDRESS`

3. **Sanitize before committing**
   - Review files with `git diff` before committing
   - Search for patterns: passwords, tokens, keys, certificates
   - Use Gitleaks CI checks (automatically runs on push)

4. **Use .local/ for sensitive reference files**
   - Store sensitive materials in `knowledge_base/.local/` (gitignored)
   - This directory is for local-only reference, never committed

### Protected File Patterns (in .gitignore)

```
*.key
*.pem  
*.p12
*.pfx
**/homebridge.json
**/config.json
**/*.credentials
knowledge_base/.local/
```

## Credential Rotation Protocol

If sensitive data is accidentally committed:

1. **Immediately** make the repository private
2. Follow the remediation plan in `tmp/REMEDIATION-PLAN.md`
3. Rotate ALL exposed credentials
4. Scrub Git history with `git-filter-repo`
5. Force push to rewrite remote history (after backup)

## CI Security Scanning

The project uses Gitleaks to detect secrets in commits:
- Runs automatically on every push via GitHub Actions
- Blocks commits containing detected secrets
- Configuration: `.github/workflows/ci.yml`

## Questions?

If unsure whether a file should be committed, ask yourself:
- Does this file contain passwords, tokens, or keys? → **Don't commit**
- Could someone use this file to access my systems? → **Don't commit**
- Is this a configuration export from a live system? → **Don't commit**

When in doubt, use an `.example` file with redacted values.
