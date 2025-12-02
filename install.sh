#!/bin/sh

# ============================================
# RakitanManager-Reborn Installer
# ============================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Animation characters
SPINNER="⣾⣽⣻⢿⡿⣟⣯⣷"
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="➜"

# Configuration
REPO_URL="https://github.com/rtaserver-wrt/RakitanManager-Reborn"
REPO_API="https://api.github.com/repos/rtaserver-wrt/RakitanManager-Reborn"
REPO="rtaserver-wrt/RakitanManager-Reborn"
TEMP_DIR="/tmp/rakitanmanager_install"
LOG_FILE="/tmp/rakitanmanager_install.log"
CONFIG_FILE="/etc/config/rakitanmanager"

# Package lists for different package managers
PACKAGE_BASE="coreutils-sleep curl git git-http python3-pip bc screen adb httping jq procps-ng-pkill unzip dos2unix"
PACKAGE_PHP7="php7-mod-curl php7-mod-session php7-mod-zip php7-cgi"
PACKAGE_PHP8="php8-mod-curl php8-mod-session php8-mod-zip php8-cgi"
PACKAGE_PYTHON="python3-requests python3-pip python3-setuptools"

# Global variables
INSTALLATION_STEPS=0
CURRENT_STEP=0
SUCCESS_STEPS=0
FAILED_STEPS=0
ARCH=""
BRANCH=""
PACKAGE_MANAGER=""
OS_INFO=""
EXTRACTED_DIR=""
DOWNLOADED_FILE=""
SYSTEM_TYPE=""
LATEST_TAG=""

# ============================================
# Utility Functions
# ============================================

print_color() {
    echo -e "${1}${2}${NC}"
}

log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
    echo -e "${CYAN}[${timestamp}]${NC} [${BOLD}${level}${NC}] ${message}" | tee -a "$LOG_FILE" >&2
}

step_header() {
    INSTALLATION_STEPS=$((INSTALLATION_STEPS + 1))
    CURRENT_STEP="$1"
    echo -e "\n${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║  Step ${1}: ${2}"
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}\n"
}

check_success() {
    local result=$?
    if [ $result -eq 0 ]; then
        SUCCESS_STEPS=$((SUCCESS_STEPS + 1))
        print_color "$GREEN" "✓ Success"
        return 0
    else
        FAILED_STEPS=$((FAILED_STEPS + 1))
        print_color "$RED" "✗ Failed"
        return $result
    fi
}

check_internet() {
    log "Checking internet connectivity..." "INFO"
    # Try multiple methods
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log "Internet connectivity check passed" "SUCCESS"
        return 0
    elif ping -c 1 -W 3 google.com >/dev/null 2>&1; then
        log "Internet connectivity check passed" "SUCCESS"
        return 0
    elif command -v curl >/dev/null 2>&1 && curl -s --connect-timeout 5 https://github.com >/dev/null 2>&1; then
        log "Internet connectivity check passed" "SUCCESS"
        return 0
    else
        log "No internet connection detected. Please check your network." "ERROR"
        return 1
    fi
}

check_disk_space() {
    local required="$1"
    local available
    # Try different methods to get disk space
    if df /tmp >/dev/null 2>&1; then
        available=$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    else
        available=$(df / 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    fi
    if [ "$available" -lt "$required" ]; then
        log "Insufficient disk space. Required: ${required}KB, Available: ${available}KB" "ERROR"
        return 1
    fi
    return 0
}

detect_package_manager() {
    if [ -x "/bin/opkg" ] || [ -x "/usr/bin/opkg" ]; then
        PACKAGE_MANAGER="opkg"
        SYSTEM_TYPE="openwrt_stable"
        log "Detected package manager: opkg (OpenWrt Stable)" "INFO"
        return 0
    elif [ -x "/usr/bin/apk" ]; then
        PACKAGE_MANAGER="apk"
        SYSTEM_TYPE="openwrt_snapshot"
        log "Detected package manager: apk (OpenWrt Snapshot)" "INFO"
        return 0
    else
        log "Unsupported or missing package manager (opkg or apk required)" "ERROR"
        return 1
    fi
}

detect_system() {
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release
        ARCH="${DISTRIB_ARCH:-$(uname -m 2>/dev/null)}"
        OS_INFO="${DISTRIB_DESCRIPTION:-${DISTRIB_ID} ${DISTRIB_RELEASE}}"

        case "$DISTRIB_RELEASE" in
            *"21.02"*) BRANCH="openwrt-21.02" ;;
            *"22.03"*) BRANCH="openwrt-22.03" ;;
            *"23.05"*) BRANCH="openwrt-23.05" ;;
            *"24.10"*) BRANCH="openwrt-24.10" ;;
            "SNAPSHOT") BRANCH="SNAPSHOT" ;;
            *) BRANCH="${DISTRIB_RELEASE:-unknown}" ;;
        esac
    else
        ARCH=$(uname -m 2>/dev/null)
        OS_INFO="Unknown System"
        BRANCH="unknown"
    fi

    # Clean up ARCH for consistency
    case "$ARCH" in
        "x86_64") ARCH="x86_64" ;;
        "aarch64") ARCH="aarch64" ;;
        "armv7l"|"armv7") ARCH="armv7" ;;
        "mips"|"mipsel") ARCH="mipsel" ;;
        *) ARCH="$ARCH" ;;
    esac

    log "Detected: ${OS_INFO}" "INFO"
    log "Architecture: ${ARCH}" "INFO"
    log "Branch: ${BRANCH}" "INFO"
    log "System Type: ${SYSTEM_TYPE}" "INFO"
    return 0
}

install_package() {
    local package="$1"
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        case $PACKAGE_MANAGER in
            "opkg")
                if opkg list-installed | grep -q "^${package} "; then
                    log "Package already installed: ${package}" "INFO"
                    return 0
                fi

                log "Installing: ${package}" "INFO"
                if opkg update >/dev/null 2>&1 && opkg install "$package" >/dev/null 2>&1; then
                    log "Successfully installed: ${package}" "SUCCESS"
                    return 0
                fi
                ;;
            "apk")
                if apk info -e "$package" >/dev/null 2>&1; then
                    log "Package already installed: ${package}" "INFO"
                    return 0
                fi

                log "Installing: ${package}" "INFO"
                if apk add --no-cache "$package" >/dev/null 2>&1; then
                    log "Successfully installed: ${package}" "SUCCESS"
                    return 0
                fi
                ;;
        esac

        retry_count=$((retry_count + 1))
        log "Retrying installation (${retry_count}/${max_retries}): ${package}" "WARNING"
        sleep 2
    done

    log "Failed to install: ${package} after ${max_retries} attempts" "ERROR"
    return 1
}

install_packages() {
    local packages="$1"
    local failed=0
    
    log "Updating package repository..." "INFO"
    case $PACKAGE_MANAGER in
        "opkg")
            opkg update >/dev/null 2>&1 || log "Failed to update opkg repository" "WARNING"
            ;;
        "apk")
            apk update >/dev/null 2>&1 || log "Failed to update apk repository" "WARNING"
            ;;
    esac
    
    for package in $packages; do
        if ! install_package "$package"; then
            log "Package installation may have failed: ${package}" "WARNING"
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        log "All packages installed successfully" "SUCCESS"
        return 0
    else
        log "${failed} package(s) may have failed to install" "WARNING"
        return 1
    fi
}

get_system_packages() {
    case $PACKAGE_MANAGER in
        "opkg")
            if [ "$BRANCH" = "openwrt-21.02" ] || echo "$OS_INFO" | grep -q "21.02"; then
                echo "$PACKAGE_BASE $PACKAGE_PHP7 $PACKAGE_PYTHON"
            else
                echo "$PACKAGE_BASE $PACKAGE_PHP8 $PACKAGE_PYTHON"
            fi
            ;;
        "apk")
            echo "$PACKAGE_BASE php8-mod-curl php8-mod-session php8-mod-zip php8-cgi $PACKAGE_PYTHON"
            ;;
        *)
            echo ""
            ;;
    esac
}

cleanup() {
    log "Cleaning up temporary files..." "INFO"
    rm -rf "$TEMP_DIR" 2>/dev/null
    rm -f "/tmp/rakitanmanager_install/RakitanManager-Reborn-*.zip" 2>/dev/null
    rm -f "/tmp/rakitanmanager_install/*.zip" 2>/dev/null
    log "Cleanup completed" "SUCCESS"
}

create_directories() {
    for dir in "/usr/share/rakitanmanager" "/www/rakitanmanager" "/etc/init.d" "$TEMP_DIR"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log "Created directory: ${dir}" "INFO"
        fi
    done
}

set_permissions() {
    log "Setting permissions..." "INFO"
    # Find and make executable files executable
    find "/usr/share/rakitanmanager" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null
    find "/usr/share/rakitanmanager" -type f -name "*.py" -exec chmod +x {} \; 2>/dev/null
    # Set ownership
    chown -R root:root "/usr/share/rakitanmanager" 2>/dev/null
    chown -R root:root "/www/rakitanmanager" 2>/dev/null
    # Make init script executable
    if [ -f "/etc/init.d/rakitanmanager" ]; then
        chmod +x "/etc/init.d/rakitanmanager"
    fi
    log "Permissions set successfully" "SUCCESS"
}

validate_installation() {
    local errors=0
    local warnings=0
    log "Validating installation..." "INFO"

    # Check directories
    for dir in "/usr/share/rakitanmanager" "/www/rakitanmanager"; do
        if [ ! -d "$dir" ]; then
            log "Missing directory: ${dir}" "ERROR"
            errors=$((errors + 1))
        fi
    done

    # Check essential files
    if [ ! -f "/www/rakitanmanager/index.php" ]; then
        log "Missing web interface file: index.php" "WARNING"
        warnings=$((warnings + 1))
    fi

    if [ ! -f "/etc/init.d/rakitanmanager" ]; then
        log "Missing init script" "WARNING"
        warnings=$((warnings + 1))
    fi

    if [ ! -f "/usr/share/rakitanmanager/main.py" ]; then
        log "Missing main script" "WARNING"
        warnings=$((warnings + 1))
    fi

    if [ $errors -eq 0 ]; then
        if [ $warnings -eq 0 ]; then
            log "Installation validation passed!" "SUCCESS"
        else
            log "Installation validation passed with ${warnings} warning(s)" "WARNING"
        fi
        return 0
    else
        log "Installation validation failed with ${errors} error(s)" "ERROR"
        return 1
    fi
}

show_summary() {
    echo -e "\n${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║                     INSTALLATION SUMMARY                     "
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${BOLD}System Information:${NC}\n"
    echo -e "  ${ARROW} OS: ${OS_INFO:-Not detected}"
    echo -e "  ${ARROW} Architecture: ${ARCH:-Not detected}"
    echo -e "  ${ARROW} Branch: ${BRANCH:-Not detected}"
    echo -e "  ${ARROW} Package Manager: ${PACKAGE_MANAGER:-Not detected}"
    echo -e "  ${ARROW} System Type: ${SYSTEM_TYPE:-Not detected}"

    echo -e "\n${BOLD}Installation Results:${NC}\n"
    echo -e "  ${GREEN}${CHECK_MARK} Successful steps: ${SUCCESS_STEPS}/${INSTALLATION_STEPS}"
    if [ $FAILED_STEPS -gt 0 ]; then
        echo -e "  ${RED}${CROSS_MARK} Failed steps: ${FAILED_STEPS}"
    fi

    echo -e "\n${BOLD}Installed Components:${NC}\n"
    echo -e "  ${ARROW} Core scripts: /usr/share/rakitanmanager/"
    echo -e "  ${ARROW} Web interface: /www/rakitanmanager/"
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  ${ARROW} Configuration: ${CONFIG_FILE}"
    else
        echo -e "  ${YELLOW}⚠ Configuration: Not found (will be created on first run)"
    fi
    if [ -f "/etc/init.d/rakitanmanager" ]; then
        echo -e "  ${ARROW} Init script: /etc/init.d/rakitanmanager"
    fi
    
    # Show LuCI integration status
    if [ -f "/usr/lib/lua/luci/controller/rakitanmanager.lua" ]; then
        echo -e "  ${ARROW} LuCI Integration: Installed"
    else
        echo -e "  ${YELLOW}⚠ LuCI Integration: Not installed"
    fi

    echo -e "\n${BOLD}Next Steps:${NC}\n"
    echo -e "  1. Access web interface: http://<your-router-ip>/rakitanmanager"
    echo -e "  2. Configure your modems in the web interface"
    if [ -f "/etc/init.d/rakitanmanager" ]; then
        echo -e "  3. Start the service: /etc/init.d/rakitanmanager start"
        echo -e "  4. Enable auto-start: /etc/init.d/rakitanmanager enable"
    fi

    if [ -f "/usr/lib/lua/luci/controller/rakitanmanager.lua" ]; then
        echo -e "  5. Access via LuCI: Services → Rakitan Manager"
    fi

    echo -e "\n${GREEN}${BOLD}Installation completed!${NC}\n\n"
}

# ============================================
# Download Functions
# ============================================

get_latest_tag() {
    log "Checking latest release tag for $REPO..." "INFO"
    
    # Try multiple methods to get the latest tag
    local tag=""
    
    # Method 1: GitHub API with curl
    if command -v curl >/dev/null 2>&1; then
        tag=$(curl -s -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | \
            grep -o '"tag_name": *"[^"]*"' | \
            cut -d'"' -f4)
    fi
    
    # Method 2: Direct from releases page (fallback)
    if [ -z "$tag" ] && command -v curl >/dev/null 2>&1; then
        tag=$(curl -s -I "https://github.com/$REPO/releases/latest" 2>/dev/null | \
              grep -i '^location:' | \
              sed 's|.*/tag/||' | \
              tr -d '\r\n')
    fi
    
    # Method 3: Use git if available
    if [ -z "$tag" ] && command -v git >/dev/null 2>&1; then
        tag=$(git ls-remote --tags "https://github.com/$REPO.git" | \
              awk -F/ '{print $3}' | \
              sort -V | \
              tail -1)
    fi
    
    if [ -n "$tag" ]; then
        log "Latest release tag: $tag" "SUCCESS"
        LATEST_TAG="$tag"
        echo "$tag"
        return 0
    else
        log "Could not determine latest release tag" "ERROR"
        return 1
    fi
}

download_release() {
    local tag="$1"
    local filename="RakitanManager-Reborn-$tag.zip"
    local download_url="https://github.com/$REPO/archive/refs/tags/$tag.zip"
    
    DOWNLOADED_FILE="/tmp/rakitanmanager_install/$filename"
    
    log "Downloading release $tag..." "INFO"
    log "Download URL: $download_url" "DEBUG"
    
    # Create temp directory if it doesn't exist
    mkdir -p "$TEMP_DIR"
    
    # Check if curl or wget is available
    local download_cmd=""
    if command -v curl >/dev/null 2>&1; then
        if curl --help 2>&1 | grep -q "\-\-progress-bar"; then
            download_cmd="curl -L --progress-bar -o '$DOWNLOADED_FILE' '$download_url'"
        else
            download_cmd="curl -L -s -o '$DOWNLOADED_FILE' '$download_url'"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget --help 2>&1 | grep -q "\-\-show-progress"; then
            download_cmd="wget -q --show-progress -O '$DOWNLOADED_FILE' '$download_url'"
        else
            download_cmd="wget -q -O '$DOWNLOADED_FILE' '$download_url'"
        fi
    else
        log "No download tool available (curl or wget required)" "ERROR"
        return 1
    fi
    
    # Download the file
    log "Executing: $download_cmd" "DEBUG"
    if eval "$download_cmd"; then
        if [ -f "$DOWNLOADED_FILE" ]; then
            local filesize
            if command -v stat >/dev/null 2>&1; then
                filesize=$(stat -c%s "$DOWNLOADED_FILE" 2>/dev/null || stat -f%z "$DOWNLOADED_FILE" 2>/dev/null || echo "unknown")
            else
                filesize=$(ls -l "$DOWNLOADED_FILE" | awk '{print $5}' 2>/dev/null || echo "unknown")
            fi
            log "Download completed: $filename (${filesize} bytes)" "SUCCESS"
            
            # Verify ZIP file
            if command -v unzip >/dev/null 2>&1; then
                if unzip -t "$DOWNLOADED_FILE" >/dev/null 2>&1; then
                    log "ZIP file verification passed" "SUCCESS"
                    
                    # Extract to temp directory
                    EXTRACTED_DIR="$TEMP_DIR/RakitanManager-Reborn-$tag"
                    rm -rf "$EXTRACTED_DIR" 2>/dev/null
                    if unzip -q "$DOWNLOADED_FILE" -d "$TEMP_DIR" 2>/dev/null; then
                        # Check if extraction created the expected directory
                        if [ -d "$EXTRACTED_DIR" ]; then
                            log "Extracted to: $EXTRACTED_DIR" "SUCCESS"
                            return 0
                        else
                            # Try to find the extracted directory
                            local extracted_name
                            extracted_name=$(unzip -l "$DOWNLOADED_FILE" | head -5 | grep -o "RakitanManager-Reborn-[^/]*/" | head -1 | sed 's|/$||')
                            if [ -n "$extracted_name" ]; then
                                EXTRACTED_DIR="$TEMP_DIR/$extracted_name"
                                log "Found extracted directory: $EXTRACTED_DIR" "INFO"
                                return 0
                            else
                                log "Could not find extracted directory" "ERROR"
                                return 1
                            fi
                        fi
                    else
                        log "Failed to extract ZIP file" "ERROR"
                        return 1
                    fi
                else
                    log "ZIP file appears to be corrupted" "ERROR"
                    return 1
                fi
            else
                log "unzip not available, skipping extraction" "WARNING"
                return 0
            fi
        else
            log "Download failed - file not created" "ERROR"
            return 1
        fi
    else
        log "Download failed" "ERROR"
        return 1
    fi
}

# ============================================
# Package Manager Specific Functions
# ============================================

install_system_packages() {
    log "Installing system packages for ${PACKAGE_MANAGER}..." "INFO"
    
    # Get appropriate package list
    local packages
    packages=$(get_system_packages)
    
    if [ -z "$packages" ]; then
        log "No packages defined for ${PACKAGE_MANAGER}" "WARNING"
        return 1
    fi
    
    log "Packages to install: ${packages}" "DEBUG"
    
    # Install packages
    if install_packages "$packages"; then
        log "System packages installed successfully" "SUCCESS"
        return 0
    else
        log "Some packages may have failed to install" "WARNING"
        return 1
    fi
}

install_luci_integration() {
    log "Checking for LuCI integration..." "INFO"
    
    # Check if LuCI is installed
    if ! command -v uci >/dev/null 2>&1; then
        log "LuCI not detected, skipping integration" "INFO"
        return 0
    fi
    
    log "Installing LuCI integration..." "INFO"
    
    # Create LuCI directories if they don't exist
    mkdir -p /usr/lib/lua/luci/view /usr/lib/lua/luci/controller /usr/lib/lua/luci/model/cbi 2>/dev/null
    
    # Install LuCI view template
    cat > /usr/lib/lua/luci/view/rakitanmanager.htm << 'EOF'
<%+header%>
<div class="cbi-map">
<iframe id="rakitanmanager" style="width: 100%; min-height: 750px; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("rakitanmanager").src = "http://" + window.location.hostname + "/rakitanmanager/index.php";
</script>
<%+footer%>
EOF
    
    # Install LuCI controller
    cat > /usr/lib/lua/luci/controller/rakitanmanager.lua << 'EOF'
module("luci.controller.rakitanmanager", package.seeall)
function index()
    entry({"admin","modem","rakitanmanager"}, template("rakitanmanager"), _("Rakitan Manager"), 7).leaf=true
end
EOF
    
    log "LuCI integration installed successfully" "SUCCESS"
    return 0
}

# ============================================
# Main Installation Function
# ============================================

install_rakitanmanager() {
    > "$LOG_FILE"
    log "Starting RakitanManager-Reborn installation..." "INFO"

    # Step 1: System Check
    step_header 1 "System Check"
    (
        detect_system &&
        detect_package_manager &&
        check_internet &&
        check_disk_space 50000
    )
    check_success || {
        log "Prerequisite check failed (continuing anyway)" "WARNING"
        # Don't exit, just warn
    }

    # Step 2: Install System Dependencies
    step_header 2 "Installing System Dependencies"
    if [ -n "$PACKAGE_MANAGER" ]; then
        install_system_packages
    else
        log "Package manager not detected, skipping package installation" "WARNING"
    fi
    check_success || echo "${YELLOW}Continuing with partial dependencies...${NC}"

    # Step 3: Download Latest Release
    step_header 3 "Downloading Latest Release"
    (
        create_directories
        
        # Get latest tag
        LATEST_TAG=$(get_latest_tag)
        if [ -z "$LATEST_TAG" ]; then
            log "Failed to get latest release tag" "ERROR"
            exit 1
        fi
        
        # Download release
        if ! download_release "$LATEST_TAG"; then
            log "Failed to download release" "ERROR"
            exit 1
        fi
        
        log "Successfully downloaded and extracted release $LATEST_TAG" "SUCCESS"
    )
    check_success || { 
        log "Download failed" "ERROR"
        echo -e "${RED}Failed to download. Please check your internet connection.${NC}"
        exit 1
    }

    # Step 4: Install Files
    step_header 4 "Installing Files"
    (
        if [ -z "$EXTRACTED_DIR" ] || [ ! -d "$EXTRACTED_DIR" ]; then
            log "Extracted directory not found. Looking for alternatives..." "ERROR"
            # Try to find any extracted directory
            EXTRACTED_DIR=$(find "$TEMP_DIR" -type d -name "RakitanManager-Reborn-*" | head -1)
            if [ -z "$EXTRACTED_DIR" ] || [ ! -d "$EXTRACTED_DIR" ]; then
                log "No extracted directory found at all" "ERROR"
                exit 1
            fi
        fi

        # Stop existing service if running
        if [ -f "/etc/init.d/rakitanmanager" ]; then
            /etc/init.d/rakitanmanager stop 2>/dev/null
            log "Stopped existing RakitanManager service" "INFO"
        fi

        # First, let's see what's in the extracted directory
        log "Contents of extracted directory ($EXTRACTED_DIR):" "DEBUG"
        ls -la "$EXTRACTED_DIR/" 2>/dev/null >> "$LOG_FILE"
        
        # Find config file
        local config_src=$(find "$EXTRACTED_DIR" -name "rakitanmanager" -type f | grep -E "(config|etc)" | head -1)
        if [ -n "$config_src" ] && [ -f "$config_src" ]; then
            cp -f "$config_src" "$CONFIG_FILE" 2>/dev/null && log "Copied configuration file" "SUCCESS" || log "Failed to copy config" "WARNING"
        else
            log "Config file not found in release, will use default" "INFO"
        fi

        # Find and copy core files
        local core_src=$(find "$EXTRACTED_DIR" -type d -name "core" | head -1)
        if [ -n "$core_src" ] && [ -d "$core_src" ]; then
            cp -rf "$core_src/"* "/usr/share/rakitanmanager/" 2>/dev/null && log "Copied core files" "SUCCESS" || log "Failed to copy core files" "WARNING"
        else
            # Look for python files or other core files
            find "$EXTRACTED_DIR" -type f \( -name "*.py" -o -name "*.sh" \) -exec cp -f {} "/usr/share/rakitanmanager/" 2>/dev/null \;
            log "Copied individual core files" "INFO"
        fi

        # Find and copy init script
        local init_src=$(find "$EXTRACTED_DIR" -name "rakitanmanager" -type f -path "*/init.d/*" | head -1)
        if [ -z "$init_src" ]; then
            init_src=$(find "$EXTRACTED_DIR" -name "*rakitanmanager*" -type f | grep -i init | head -1)
        fi
        if [ -n "$init_src" ] && [ -f "$init_src" ]; then
            cp -f "$init_src" "/etc/init.d/rakitanmanager" 2>/dev/null && log "Copied init script" "SUCCESS" || log "Failed to copy init script" "WARNING"
        fi

        # Find and copy web interface
        local web_src=$(find "$EXTRACTED_DIR" -type d -name "web" | head -1)
        if [ -z "$web_src" ]; then
            web_src=$(find "$EXTRACTED_DIR" -type d -name "www" | head -1)
        fi
        if [ -z "$web_src" ]; then
            web_src=$(find "$EXTRACTED_DIR" -type f -name "index.php" | head -1 | xargs dirname 2>/dev/null)
        fi
        
        if [ -n "$web_src" ] && [ -d "$web_src" ]; then
            cp -rf "$web_src/"* "/www/rakitanmanager/" 2>/dev/null && log "Copied web interface" "SUCCESS" || log "Failed to copy web interface" "WARNING"
        else
            # Copy any PHP/HTML files
            find "$EXTRACTED_DIR" -type f \( -name "*.php" -o -name "*.html" -o -name "*.css" -o -name "*.js" \) -exec cp -f --parents {} "/www/rakitanmanager/" 2>/dev/null \;
            log "Copied web files individually" "INFO"
        fi
        # Install LuCI integration if available
        install_luci_integration
        
        log "Files installed successfully" "SUCCESS"
    )
    check_success || {
        log "File installation had issues, but continuing..." "WARNING"
    }

    step_header 5 "Setting Permissions"
    set_permissions
    check_success

    step_header 6 "Validating Installation"
    validate_installation
    check_success

    step_header 7 "Cleaning Up"
    cleanup
    check_success

    show_summary

    # Enable service if init script exists
    if [ -f /etc/init.d/rakitanmanager ]; then
        /etc/init.d/rakitanmanager enable >/dev/null 2>&1 && log "Service enabled" "SUCCESS"
    fi
    
    log "Installation process completed" "INFO"
}

# ============================================
# Other Functions (Uninstall, Update, Repair, Menu)
# ============================================

uninstall_rakitanmanager() {
    echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║                    UNINSTALL WARNING                      ║"
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}\n"
    echo -e "${YELLOW}This will remove RakitanManager and all components.${NC}\n"
    echo -n "Type 'YES' to confirm: "
    read -r confirmation
    [ "$confirmation" != "YES" ] && { echo "${GREEN}Uninstall cancelled.${NC}"; exit 0; }

    if [ -f "/etc/init.d/rakitanmanager" ]; then
        /etc/init.d/rakitanmanager stop 2>/dev/null
        /etc/init.d/rakitanmanager disable 2>/dev/null
    fi
    
    rm -rf /usr/share/rakitanmanager /www/rakitanmanager 2>/dev/null
    rm -f "$CONFIG_FILE" /etc/init.d/rakitanmanager 2>/dev/null
    
    # Remove LuCI integration
    rm -f /usr/lib/lua/luci/view/rakitanmanager.htm /usr/lib/lua/luci/controller/rakitanmanager.lua 2>/dev/null
    
    # Clean uci config if exists
    if command -v uci >/dev/null 2>&1; then
        uci delete rakitanmanager 2>/dev/null
        uci commit 2>/dev/null
    fi
    
    echo "${GREEN}Uninstalled.${NC}"
}

update_rakitanmanager() {
    if [ ! -d /usr/share/rakitanmanager ]; then
        echo "${RED}Not installed! Please install first.${NC}"
        exit 1
    fi
    echo -n "Update to latest version? (y/n): "
    read -r r
    if [ "$r" = "y" ] || [ "$r" = "Y" ]; then
        install_rakitanmanager
    else
        echo "Cancelled."
        exit 0
    fi
}

repair_installation() {
    echo -n "Repair installation? This will reinstall packages and fix permissions. (y/n): "
    read -r r
    if [ "$r" != "y" ] && [ "$r" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    echo -e "\n${BLUE}Starting repair process...${NC}\n"
    
    detect_package_manager
    detect_system
    
    # Install system packages
    echo -e "${YELLOW}Reinstalling system packages...${NC}"
    install_system_packages
    
    # Fix permissions
    echo -e "${YELLOW}Fixing permissions...${NC}"
    set_permissions
    
    # Validate installation
    echo -e "${YELLOW}Validating installation...${NC}"
    validate_installation
    
    echo -e "\n${GREEN}Repair completed!${NC}\n"
}

check_system_compatibility() {
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║               SYSTEM COMPATIBILITY CHECK                ║"
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    detect_system
    detect_package_manager
    check_internet
    check_disk_space 10000
    
    echo -e "\n${BOLD}Compatibility Results:${NC}\n"
    
    # Check required tools
    local missing_tools=""
    for tool in curl unzip; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools="$missing_tools $tool"
        fi
    done
    
    if [ -n "$missing_tools" ]; then
        echo -e "  ${RED}✗ Missing tools:${missing_tools}${NC}"
    else
        echo -e "  ${GREEN}✓ All required tools available${NC}"
    fi
    
    # Check package manager
    if [ -n "$PACKAGE_MANAGER" ]; then
        echo -e "  ${GREEN}✓ Package manager: ${PACKAGE_MANAGER}${NC}"
    else
        echo -e "  ${RED}✗ No supported package manager found${NC}"
    fi
    
    # Check architecture
    if [ -n "$ARCH" ]; then
        echo -e "  ${GREEN}✓ Architecture: ${ARCH}${NC}"
    else
        echo -e "  ${YELLOW}⚠ Architecture: Unknown${NC}"
    fi
    
    echo -e "\n${GREEN}Compatibility check completed!${NC}\n"
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r _
}

# ============================================
# Menu Functions
# ============================================

show_menu() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║${BOLD}               OpenWrt Rakitan Manager Installer           ${CYAN}║"
    echo -e "║${BOLD}                     Installer Version 2.7                 ${CYAN}║"
    echo -e "║${BOLD}               Multi-System Support (opkg/apk)             ${CYAN}║"
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"
    echo -e "\n"
    echo -e "${CYAN}${BOLD}Select an option:${NC}\n"
    echo -e "  ${GREEN}1${NC}. Install RakitanManager-Reborn (Fresh installation)\n"
    echo -e "  ${YELLOW}2${NC}. Update RakitanManager-Reborn (To latest version)\n"
    echo -e "  ${BLUE}3${NC}. Repair Installation (Fix issues)\n"
    echo -e "  ${RED}4${NC}. Uninstall RakitanManager-Reborn (Remove completely)\n"
    echo -e "  ${CYAN}5${NC}. Check System Compatibility\n"
    echo -e "  ${WHITE}6${NC}. View Installation Log\n"
    echo -e "  ${GRAY}0${NC}. Exit\n"
    echo -n "Enter your choice [0-6]: "
    read -r choice

    case "$choice" in
        1) 
            install_rakitanmanager
            echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
            read -r _
            show_menu
            ;;
        2) 
            update_rakitanmanager
            echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
            read -r _
            show_menu
            ;;
        3) 
            repair_installation
            echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
            read -r _
            show_menu
            ;;
        4) 
            uninstall_rakitanmanager
            echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
            read -r _
            show_menu
            ;;
        5) 
            check_system_compatibility
            show_menu
            ;;
        6)
            clear
            if [ -f "$LOG_FILE" ]; then
                echo -e "${CYAN}${BOLD}Installation Log:${NC}\n"
                cat "$LOG_FILE"
            else
                echo "No log file found."
            fi
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r _
            show_menu
            ;;
        0) 
            cleanup
            echo "${GREEN}Goodbye!${NC}"
            exit 0 
            ;;
        *) 
            echo "${RED}Invalid option!${NC}"
            sleep 1
            show_menu 
            ;;
    esac
}

# ============================================
# Entry Point
# ============================================

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}This script must be run as root!${NC}"
    echo "Try: sudo $0"
    exit 1
fi

# Create temp directory
mkdir -p "$TEMP_DIR"

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Show main menu
show_menu