#!/bin/bash

# 👑 Wasabi S3 Mount Script - The Immortal Edition 👑
# The final, definitive script with an optional auto-mount feature on reboot
# using systemd services. This is the perfect blend of style, substance, and persistence.
# Date: July 11, 2024 (Immortal Edition - systemctl Fix)

# --- Stop on any error ---
set -e

# --- Awesome Colors & Emojis ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_WHITE='\033[1;37m'

E_SUCCESS="✅"
E_ERROR="❌"
E_WARN="⚠️"
E_ROCKET="🚀"
E_POINT="👉"
E_GEAR="⚙️"
E_CLOUD="☁️"
E_REBOOT="🔄"
E_SPINNER=("🌏" "🌍" "🌎")

# --- Helper Functions ---
print_banner() { echo -e "\n${C_MAGENTA}====================================================${C_RESET}\n${C_WHITE}$1${C_RESET}\n${C_MAGENTA}====================================================${C_RESET}"; }
print_status() { echo -e "${C_CYAN}${E_GEAR} $1${C_RESET}"; }
print_success() { echo -e "${C_GREEN}${E_SUCCESS} $1${C_RESET}"; }
print_error() { echo -e "${C_RED}${E_ERROR} $1${C_RESET}"; }
print_warning() { echo -e "${C_YELLOW}${E_WARN} $1${C_RESET}"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
get_random_color() { local colors=("$C_RED" "$C_GREEN" "$C_YELLOW" "$C_BLUE" "$C_MAGENTA" "$C_CYAN"); echo "${colors[$((RANDOM % ${#colors[@]}))]}"; }

run_with_loader() {
    local message="$1"; shift
    local i=0
    "$@" &> /dev/null &
    local pid=$!
    while kill -0 $pid 2> /dev/null; do
        printf "\r${C_CYAN}${E_SPINNER[i++ % 3]} ${message}... ${C_RESET}"
        sleep 0.2
    done
    wait $pid
    local exit_code=$?
    printf "\r%${COLUMNS}s\r" ""
    if [ $exit_code -eq 0 ]; then echo -e "${C_GREEN}${E_SUCCESS} ${message}... Done!${C_RESET}"; else echo -e "${C_RED}${E_ERROR} ${message}... Failed!${C_RESET}"; exit 1; fi
}

# --- Configuration Variables ---
REMOTE_NAME=""
BUCKET_NAME=""
ACCESS_KEY=""
SECRET_KEY=""
REGION=""
MOUNT_POINT=""
LOG_FILE=""

# --- Script Logic ---

show_dashboard_banner() {
    clear; COLOR=$(get_random_color); BOLD='\033[1m'
    echo -e "${COLOR}"; echo "██████╗ ███████╗██╗   ██╗██╗██╗     "; echo "██╔══██╗██╔════╝██║   ██║██║██║     "; echo "██║  ██║█████╗  ██║   ██║██║██║     "; echo "██║  ██║██╔══╝  ╚██╗ ██╔╝██║██║     "; echo "██████╔╝███████╗ ╚████╔╝ ██║███████╗"; echo "╚═════╝ ╚══════╝  ╚═══╝  ╚═╝╚══════╝"; echo -e "${BOLD}🔥 WASABI S3 MOUNT SCRIPT BY DEVIL 🔥${C_RESET}"
    echo; echo -e "${C_WHITE}${BOLD}Configuration Summary:${C_RESET}"; echo -e "${C_MAGENTA}----------------------------------------------------${C_RESET}"
    echo -e "${C_CYAN}Remote Name:${C_RESET} ${C_WHITE}${REMOTE_NAME}${C_RESET}"; echo -e "${C_CYAN}Bucket Name:${C_RESET} ${C_WHITE}${BUCKET_NAME}${C_RESET}"; echo -e "${C_CYAN}Region:     ${C_RESET} ${C_WHITE}${REGION}${C_RESET}"; echo -e "${C_CYAN}Mount Point:${C_RESET} ${C_WHITE}${MOUNT_POINT}${C_RESET}"; echo -e "${C_MAGENTA}----------------------------------------------------${C_RESET}"
}

get_user_config() {
    clear; local temp_color=$(get_random_color)
    echo -e "${temp_color}"; echo "██████╗ ███████╗██╗   ██╗██╗██╗     "; echo "██╔══██╗██╔════╝██║   ██║██║██║     "; echo "██║  ██║█████╗  ██║   ██║██║██║     "; echo "██║  ██║██╔══╝  ╚██╗ ██╔╝██║██║     "; echo "██████╔╝███████╗ ╚████╔╝ ██║███████╗"; echo "╚═════╝ ╚══════╝  ╚═══╝  ╚═╝╚══════╝"
    echo -e "${temp_color}\033[1m🔥 JAADU SCRIPT BY DEVIL 🔥${C_RESET}"; echo; echo "Please provide your Wasabi S3 details to begin."; echo
    read -p "$(echo -e ${C_YELLOW}${E_POINT} "Enter a remote name [wasabi]: "${C_RESET})" REMOTE_NAME; REMOTE_NAME=${REMOTE_NAME:-wasabi}
    read -p "$(echo -e ${C_YELLOW}${E_POINT} "Enter Bucket Name [${REMOTE_NAME}]: "${C_RESET})" BUCKET_NAME; BUCKET_NAME=${BUCKET_NAME:-${REMOTE_NAME}}
    read -p "$(echo -e ${C_YELLOW}${E_POINT} "Enter Wasabi Region [ap-southeast-1]: "${C_RESET})" REGION; REGION=${REGION:-ap-southeast-1}
    read -p "$(echo -e ${C_YELLOW}${E_POINT} "Enter Access Key: "${C_RESET})" ACCESS_KEY
    read -sp "$(echo -e ${C_YELLOW}${E_POINT} "Enter Secret Key (hidden): "${C_RESET})" SECRET_KEY; echo
    if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then print_error "Keys cannot be empty."; exit 1; fi
    MOUNT_POINT="$HOME/wasabi-bucket"; LOG_FILE="$HOME/${REMOTE_NAME}-mount.log"
}

install_and_configure_prereqs() {
    print_status "Installing prerequisites..."
    run_with_loader "Updating package lists" sudo apt-get update -y
    if ! command_exists rclone; then run_with_loader "Installing rclone" bash -c "curl https://rclone.org/install.sh | sudo bash"; fi
    if ! dpkg -l | grep -q 'fuse3'; then run_with_loader "Installing FUSE" sudo apt-get install -y fuse3 libfuse3-3; fi
    if ! grep -q "^user_allow_other" /etc/fuse.conf &>/dev/null; then run_with_loader "Enabling 'user_allow_other' in FUSE" sudo bash -c "echo 'user_allow_other' >> /etc/fuse.conf"; fi
    print_success "Prerequisites are ready."
    
    print_status "Configuring rclone remote..."
    local RCONFIG="$HOME/.config/rclone/rclone.conf"; local ENDPOINT="s3.${REGION}.wasabisys.com"
    mkdir -p "$(dirname "$RCONFIG")"
    if ! ([ -f "$RCONFIG" ] && grep -q "\[${REMOTE_NAME}\]" "$RCONFIG"); then
        printf "[%s]\ntype = s3\nprovider = Wasabi\naccess_key_id = %s\nsecret_access_key = %s\nregion = %s\nendpoint = %s\n" \
            "$REMOTE_NAME" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$ENDPOINT" >> "$RCONFIG"; chmod 600 "$RCONFIG"
    fi
    print_success "Rclone remote '${REMOTE_NAME}' is configured."
    
    print_status "Verifying Wasabi bucket..."
    if ! rclone lsf "${REMOTE_NAME}:${BUCKET_NAME}" &> /dev/null; then run_with_loader "Creating bucket '${BUCKET_NAME}'" rclone mkdir "${REMOTE_NAME}:${BUCKET_NAME}"; else print_success "Bucket found."; fi
}

setup_auto_mount() {
    local SERVICE_NAME="wasabi-mount.service"; local SERVICE_PATH="$HOME/.config/systemd/user/${SERVICE_NAME}"
    read -p "$(echo -e ${C_YELLOW}${E_POINT} "Automatically mount on system restart? (Highly Recommended) [Y/n]: "${C_RESET})" choice
    case "$choice" in
        [nN])
            print_warning "Skipping auto-mount setup. You will need to mount manually after each reboot."
            run_with_loader "Performing a one-time mount" rclone mount "${REMOTE_NAME}:${BUCKET_NAME}" "${MOUNT_POINT}" --allow-other --vfs-cache-mode full --log-file "${LOG_FILE}" --daemon
            return
            ;;
        *)
            print_status "Setting up auto-mount service..."
            mkdir -p "$(dirname "$SERVICE_PATH")"
            cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Wasabi Mount Service for ${REMOTE_NAME}
After=network-online.target
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/bin/rclone mount ${REMOTE_NAME}:${BUCKET_NAME} ${MOUNT_POINT} --allow-other --vfs-cache-mode full --log-file ${LOG_FILE}
ExecStop=/bin/fusermount -u ${MOUNT_POINT}
Restart=always
RestartSec=10
[Install]
WantedBy=default.target
EOF
            print_success "Systemd service file created."
            
            print_warning "Sudo password may be required to enable user lingering."
            print_status "Enabling user lingering (for boot-time start)..."
            if sudo loginctl enable-linger "$(whoami)"; then print_success "User lingering enabled."; else print_error "Failed to enable user lingering."; fi
            
            # --- THE FIX IS HERE: Using 'systemctl' instead of 'systemd' ---
            run_with_loader "Reloading systemd daemon" systemctl --user daemon-reload
            run_with_loader "Enabling service to start on boot" systemctl --user enable "$SERVICE_NAME"
            run_with_loader "Starting the service now" systemctl --user start "$SERVICE_NAME"
            # --- END OF FIX ---

            sleep 2
            if ! systemctl --user is-active --quiet "$SERVICE_NAME"; then
                print_error "The auto-mount service failed to start."
                echo -e "${C_YELLOW}Check status with: systemctl --user status ${SERVICE_NAME}${C_RESET}"
                exit 1
            fi
            print_success "Auto-mount service is active and will start on reboot."
            ;;
    esac
}

post_mount_checks() {
    print_status "Running post-mount verification..."
    if ! mount | grep -q "${MOUNT_POINT}"; then print_error "Mount verification failed!"; exit 1; fi
    print_success "Read/Write test..."
    echo "Hello from Devil's script! $(date)" > "${MOUNT_POINT}/.mount_test.txt" && rm "${MOUNT_POINT}/.mount_test.txt"
    print_success "Disk usage information:"
    df -h "${MOUNT_POINT}"
}

main() {
    get_user_config
    show_dashboard_banner
    install_and_configure_prereqs
    setup_auto_mount
    post_mount_checks
    echo; print_banner "${E_CLOUD} Your Cloud Drive is Ready! ${E_CLOUD}"; echo -e "To check service status: ${C_CYAN}systemctl --user status wasabi-mount.service${C_RESET}"
}

case "${1:-}" in
    unmount)
        SERVICE_NAME="wasabi-mount.service"; print_status "Stopping and disabling auto-mount service..."
        if systemctl --user is-active --quiet "$SERVICE_NAME"; then run_with_loader "Stopping the service" systemctl --user stop "$SERVICE_NAME"; fi
        if systemctl --user is-enabled --quiet "$SERVICE_NAME"; then run_with_loader "Disabling auto-start on boot" systemctl --user disable "$SERVICE_NAME"; fi
        print_success "Auto-mount has been fully disabled and unmounted."
        ;;
    *)
        main
        ;;
esac
echo
