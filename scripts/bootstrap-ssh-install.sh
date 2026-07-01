#!/bin/bash
# ============================================================================
# Kitty Agent SSH Bootstrap Installer
# ============================================================================
# This script automates:
# 1. SSH key detection / generation
# 2. Prompting user to add key to GitHub
# 3. Connection status verification loop
# 4. Cloning the private Kitty repository
# 5. Launching the main setup-kitty.sh installer
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${CYAN}🐈 Kitty Agent SSH Bootstrapper${NC}"
echo "=========================================="

PRIVATE_KEY="$HOME/.ssh/id_ed25519"
PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub"

# --- 1. Detect or Generate SSH Key -------------------------------------------
if [ ! -f "$PRIVATE_KEY" ]; then
    echo -e "${CYAN}→${NC} Generating new Ed25519 SSH Key..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    PC_NAME=$(hostname)
    ssh-keygen -t ed25519 -C "kitty-enterprise-$PC_NAME" -N "" -f "$PRIVATE_KEY"
    echo -e "${GREEN}✓${NC} New SSH Key generated."
else
    echo -e "${GREEN}✓${NC} Found existing SSH Key at $PRIVATE_KEY"
    
    # Verify if the existing key's comment needs to be updated
    PUB_KEY_CONTENT=$(cat "$PUBLIC_KEY")
    EXPECTED_COMMENT="kitty-enterprise-$(hostname)"
    if [[ "$PUB_KEY_CONTENT" != *"$EXPECTED_COMMENT"* ]]; then
        echo -e "${CYAN}→${NC} Updating SSH Key comment to '$EXPECTED_COMMENT'..."
        chmod 600 "$PRIVATE_KEY"
        if ssh-keygen -c -C "$EXPECTED_COMMENT" -f "$PRIVATE_KEY" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} SSH Key comment updated."
        else
            echo -e "${YELLOW}⚠ Could not automatically update existing SSH Key comment.${NC}"
        fi
    fi
fi

# --- 2. Start ssh-agent and Add Key ------------------------------------------
echo -e "${CYAN}→${NC} Starting ssh-agent and adding key..."
eval "$(ssh-agent -s)"
ssh-add "$PRIVATE_KEY"

# --- 3. Prompt User to Add Key to GitHub --------------------------------------
echo ""
echo -e "${YELLOW}========================================================================${NC}"
echo -e "${YELLOW}YOUR SSH PUBLIC KEY:${NC}"
echo -e "${GREEN}$(cat "$PUBLIC_KEY")${NC}"
echo -e "${YELLOW}========================================================================${NC}"
echo ""
echo -e "${CYAN}Please copy the SSH public key above and add it to your GitHub account:${NC}"
echo -e "  1. Open: ${GREEN}https://github.com/settings/keys${NC} in your browser"
echo -e "  2. Click ${GREEN}'New SSH key'${NC}"
echo -e "  3. Paste the key and click ${GREEN}'Add SSH key'${NC}"
echo ""

# --- 4. Connection Status Verification Loop ----------------------------------
while true; do
    if ! read -p "Once you have added the key to GitHub, press [ENTER] to verify..." -r; then
        echo -e "\n${YELLOW}Input closed (EOF). Exiting bootstrap script.${NC}"
        exit 0
    fi
    
    echo -e "${CYAN}→${NC} Verifying connection to GitHub..."
    
    set +e
    ssh_output=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1)
    set -e
    
    if [[ "$ssh_output" == *"successfully authenticated"* ]]; then
        echo -e "${GREEN}✓ Connection successful! GitHub authenticated successfully.${NC}"
        break
    else
        echo -e "${RED}✗ Authentication failed.${NC}"
        echo -e "GitHub responded: $ssh_output"
        echo -e "${YELLOW}Please make sure you copied the key correctly and added it to the active account.${NC}"
        echo ""
    fi
done

# --- 5. Clone and Launch Main Installer --------------------------------------
echo ""
echo -e "${CYAN}→${NC} Cloning the private repository..."

CLONE_DIR="$HOME/Kitty"

if [ -d "$CLONE_DIR" ]; then
    echo -e "${YELLOW}⚠ Directory '$CLONE_DIR' already exists.${NC}"
    if ! read -p "Would you like to remove the existing '$CLONE_DIR' directory and re-clone? [y/N] " -n 1 -r; then
        echo
        echo -e "${YELLOW}Input closed. Proceeding with existing '$CLONE_DIR' directory and pulling latest changes...${NC}"
        cd "$CLONE_DIR"
        git pull
        cd - > /dev/null
    else
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$CLONE_DIR"
            git clone git@github.com:cuongvu300582-rgb/Kitty.git "$CLONE_DIR"
        else
            echo -e "${YELLOW}Proceeding with the existing '$CLONE_DIR' directory and pulling latest changes...${NC}"
            cd "$CLONE_DIR"
            git pull
            cd - > /dev/null
        fi
    fi
else
    git clone git@github.com:cuongvu300582-rgb/Kitty.git "$CLONE_DIR"
fi

if [ -d "$CLONE_DIR" ]; then
    cd "$CLONE_DIR"
    echo -e "${CYAN}→${NC} Launching setup-kitty.sh..."
    chmod +x setup-kitty.sh
    ./setup-kitty.sh
else
    echo -e "${RED}✗ Failed to clone repository. Exiting.${NC}"
    exit 1
fi
