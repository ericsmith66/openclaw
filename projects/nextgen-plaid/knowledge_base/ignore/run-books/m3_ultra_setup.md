# M3 Ultra Development Box: Ultimate Setup Guide

This guide details the end-to-end setup of the M3 Ultra (256GB RAM) workstation for the **NextGen Wealth Advisor** project.

## 1. Hardware Initialization & Apple ID
- **Initial Boot**: Complete the macOS Setup Assistant.
- **Set Machine Name**:
  - Open Terminal and run:
    ```bash
    sudo scutil --set ComputerName "nextgen"
    sudo scutil --set LocalHostName "nextgen"
    sudo scutil --set HostName "nextgen"
    ```
  - **Alternative**: Go to **System Settings > General > About** and edit the **Name** field.
- **Apple ID Integration**: 
  - Add the machine to your Apple Cloud account. 
  - **Suggestion**: Use your primary Apple ID. While you mentioned a "Family Member", for a development machine, using your primary account ensures easy Handoff, Universal Control, and Keychain access.
  - **Objection**: Avoid creating a literal "child" account if you need full administrative control over terminal permissions.

## 2. Remote Access Configuration
### Screen Sharing (Remote Control)
1. Go to **System Settings > General > Sharing**.
2. Enable **Screen Sharing**. 
3. Click the (i) info icon and ensure only your user is allowed.
4. **Tailscale (Recommended)**: Install [Tailscale](https://tailscale.com/download/mac) for secure, zero-config VPN access from your other Mac without opening firewall ports.

### SSH Access (CRITICAL FIX: Manual Key Injection)
If `ssh` still asks for a password, I have manually verified and fixed the following on the **Remote (192.168.4.253)**:

1. **Permissions Verified**: `~/.ssh` is `700` and `~/.ssh/authorized_keys` is `600`.
2. **Key Injected**: I have added the following key to your `authorized_keys` file:
   `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJCon3Xv1DhZbYEJ49KHC+03J6SPddXqG51X7cVaN0h ericsmith66@users.noreply.github.com`

**If it still asks for a password**, run this command on your **Local (192.168.4.200)**:
```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```
*This ensures your local session is actually "offering" the private key that matches the public key I just added.*

### How to add more keys (e.g., from another laptop)
1. **On the OTHER Mac**: `pbcopy < ~/.ssh/id_ed25519.pub`
2. **On the Remote (192.168.4.253)**: `echo "PASTE_KEY_HERE" >> ~/.ssh/authorized_keys`

### SSH Troubleshooting (Run on Local (192.168.4.200))
If it still asks for a password, your local Mac might not be "offering" the key to the Remote. Run this on your **Local (192.168.4.200)**:
```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```
*This stores the passphrase in your keychain and ensures the key is active.*

### Check Ownership (Fixed: Targeted fix for SIP/TCC)
macOS protects many folders in `~/Library` (SIP/TCC). Running `chown` on your whole home directory will trigger "Operation not permitted" errors—**this is normal and can be ignored**. Focus only on the critical paths:
```bash
# Fix ownership of your Development folder and SSH
sudo chown -R ericsmith66:staff /Users/ericsmith66/Development
sudo chown -R ericsmith66:staff /Users/ericsmith66/.ssh
```
5. **Test Access**: `ssh ericsmith66@192.168.4.253` (should not ask for password).

## 3. Git & Security
### Test Git Connectivity (Run on Remote (192.168.4.253))
Run this command to see if the Remote box is already authorized with GitHub:
```bash
ssh -T git@github.com
```
- **If it says:** `Hi ericsmith66! You've successfully authenticated...`, you are ready to clone.
- **If it says:** `Permission denied (publickey)`, follow the steps below.

### Generate SSH Key (Run on Remote (192.168.4.253))
1. Check if a key already exists: `ls -la ~/.ssh/id_ed25519.pub`
2. If not, generate one: `ssh-keygen -t ed25519 -C "ericsmith66@me.com"` (Press Enter for all prompts).
3. Copy the public key to your clipboard: `pbcopy < ~/.ssh/id_ed25519.pub`
4. Add to GitHub:
   - Go to **GitHub.com > Settings > SSH and GPG keys > New SSH key**.
   - Title: `M3 Ultra Remote`
   - Key: Paste the result from `pbcopy`.
5. **Re-test**: Run `ssh -T git@github.com` again to confirm.

### Configure Git & SSH Keychain (Run on Remote (192.168.4.253))
1. **Configure Git Identity**:
   ```bash
   git config --global user.name "Eric Smith"
   git config --global user.email "ericsmith66@me.com"
   git config --global credential.helper osxkeychain
   ```
2. **Store SSH Passphrase in Keychain**:
   *(This ensures you don't have to type your password for every Git command).*
   ```bash
   ssh-add --apple-use-keychain ~/.ssh/id_ed25519
   ```
3. **Automate SSH Config**:
   ```bash
   echo "Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519" >> ~/.ssh/config
   chmod 600 ~/.ssh/config
   ```

## 4. Ollama Installation & Optimization (M3 Ultra Specific)
With 256GB of Unified Memory, you can run massive models (Llama 3.1 70B) with high throughput.

### Installation
1. **Install via Homebrew**:
   ```bash
   brew install --cask ollama
   ```
2. **Launch Application**: Open `Ollama` from your Applications folder once to initialize the background service.

### Optimization & Models
1. **Pull Required Models**:
   ```bash
   ollama pull llama3.1:70b
   ollama pull nomic-embed-text
   ```
2. **Environment Variables for `.zshrc`**:
```bash
# Optimal for M3 Ultra
export OLLAMA_NUM_PARALLEL=4          # Handle 4 concurrent requests
export OLLAMA_MAX_LOADED_MODELS=3      # Keep Llama 3.1 70B and Nomic-Embed in memory
export OLLAMA_KEEP_ALIVE=24h           # Don't unload models (you have the RAM)
```

## 5. NextGen Plaid Stack
### Prerequisites (Homebrew)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install rbenv node@20 postgresql@16 redis
```

### Database & Redis Setup (Fixed: createuser command)
1. **Start Services**:
   ```bash
   brew services start postgresql@16
   brew services start redis
   ```
2. **Configure Postgres User**:
   If `createuser` is not found, use the full path provided by Homebrew:
   ```bash
   # Create the user referenced in database.yml
   /opt/homebrew/opt/postgresql@16/bin/createuser -s nextgen_plaid
   ```
   *Note: If you still get an error, ensure the service has fully started by checking `brew services list`.*

### 5.3. Project Setup (CRITICAL: Status - Cloned)
The project repository has been successfully cloned to `/Users/ericsmith66/Development/nextgen-plaid`.

1. **Verify rbenv Initialization**:
   Ensure `rbenv` is properly loaded in your shell. Run this on the **Remote (192.168.4.253)**:
   ```bash
   # Add to ~/.zshrc if not already there
   echo 'eval "$(rbenv init -)"' >> ~/.zshrc
   # Reload shell
   source ~/.zshrc
   ```

2. **Install Ruby**:
   The project requires Ruby 3.3.10.
   ```bash
   rbenv install 3.3.10
   rbenv global 3.3.10
   # Verify: should show /Users/ericsmith66/.rbenv/shims/ruby
   which ruby
   ```

3. **Install Gems & Dependencies**:
   ```bash
   cd /Users/ericsmith66/Development/nextgen-plaid
   gem install bundler
   bundle install
   npm install
   ```

4. **Prepare Database**:
   ```bash
   # Ensure Postgres is running (from Section 5.1)
   bin/rails db:prepare
   ```

### 5.4. RubyMine Remote Development Setup
To connect from your Local (192.168.4.200) to the Remote (192.168.4.253):
1. **On the Remote (192.168.4.253)**: Ensure SSH is working and the project is cloned as per Section 5.3.
2. **On your Local (192.168.4.200)**:
   - Open RubyMine.
   - Go to **Remote Development** on the Welcome Screen (or `File > Remote Development`).
   - Select **SSH**.
   - **New Connection**:
     - Host: `192.168.4.253` (or `nextgen.local`).
     - User: `ericsmith66`.
     - Authentication: Select **Key Pair** (it should find your `id_ed25519` key).
   - Once connected, RubyMine will ask for the **Project directory**.
   - **Path**: `/Users/ericsmith66/Development/nextgen-plaid`.
   - RubyMine will install the "Remote Backend" on the Remote (192.168.4.253) and open the project.

## 6. SmartProxy Setup (Background Service) We will start with  bin/dev
The SmartProxy handles anonymization and xAI (Grok) integration.
1. **Setup**:
   ```bash
   cd /Users/ericsmith66/Development/nextgen-plaid/smart_proxy
   bundle install
   ```
2. **Environment**:
   Ensure `GROK_API_KEY` and `PROXY_AUTH_TOKEN` are set in your environment or a `.env` file within the `smart_proxy` folder.
3. **Run**:
   ```bash
   # In a dedicated terminal or screen session
   rackup -p 4567
   ```

## 7. Port 80 Persistence (Cloudflare Bridge)
1. Create anchor: `sudo nano /etc/pf.anchors/com.nextgen.plaid`
   - Content: `rdr pass inet proto tcp from any to any port 80 -> 127.0.0.1 port 3000`
2. Add to `/etc/pf.conf` (after existing anchors):
   - `anchor "com.nextgen.plaid"`
   - `load anchor "com.nextgen.plaid" from "/etc/pf.anchors/com.nextgen.plaid"`
3. Verify: `sudo pfctl -ef /etc/pf.conf`

## 8. M3 Ultra Performance Tuning
- **Puma**: For M3 Ultra, increase thread count and enable `Solid Queue` integration in `config/puma.rb` or via env:
  ```bash
  export RAILS_MAX_THREADS=16
  export SOLID_QUEUE_IN_PUMA=true
  ```
- **Solid Queue**: If running separately from Puma, run workers with higher concurrency:
  ```bash
  RAILS_ENV=production bundle exec rake solid_queue:start
  ```

## 9. Hardening (Phase 2) & Network Security
### macOS Level Hardening
1. **Disable SSH password auth**:
   - `sudo nano /etc/ssh/sshd_config`
   - Set `PasswordAuthentication no` and `ChallengeResponseAuthentication no`.
   - Restart SSH: `sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist && sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist`
2. **Enable FileVault**: **System Settings > Privacy & Security > FileVault**.
3. **Application Firewall**: 
   - Enable in **System Settings > Network > Firewall**.
   - Click **Options** and enable **Stealth Mode**.

### Network Level (Ubiquiti Dream Machine / UDM)
If placing the M3 Ultra in a DMZ or behind a UDM Pro/SE, configure the following rules in **UniFi OS > Network > Settings > Security > Firewall & Routing**:

1. **DMZ Isolation (Internet In)**:
   - Create a "DMZ" VLAN (e.g., VLAN 10).
   - **Rule**: `Allow` established/related traffic from DMZ to Local Networks.
   - **Rule**: `Drop` all other traffic from DMZ to Local Networks (protects your home/office LAN).
2. **Port Forwarding / WAN In**:
   - **Avoid opening Port 22 (SSH) to the public internet.** Use Tailscale instead.
   - If Port 80/443 must be open for the Cloudflare Bridge/Plaid Webhooks:
     - Map WAN Port 80 -> M3 Ultra IP Port 80 (handled by `pf` to 3000).
     - Map WAN Port 443 -> M3 Ultra IP Port 443.
3. **MAC ID Reservation**:
   - In **UniFi Clients**, select the M3 Ultra -> **Settings** -> **Fixed IP Address**. This ensures your firewall rules don't break when the DHCP lease expires.
4. **Traffic Rules**:
   - Enable **Country Coding** (Allow only US-based traffic if applicable).
   - Enable **Ad Blocking** and **Internal Honeypot** on the DMZ VLAN.
