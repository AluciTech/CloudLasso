#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ICONS_DIR="$SCRIPT_DIR/icons"
ICON_HAPPY="$ICONS_DIR/icons8-happy-cloud-48.png"
ICON_SAD="$ICONS_DIR/icons8-sad-cloud-48.png"
ICON_SYNC="$ICONS_DIR/icons8-sync-cloud-48.png"
CONFIG_DIR="$HOME/.config/CloudLasso"
CONFIG_FILE="$CONFIG_DIR/cloudlasso.conf"

MIN_RETRY_DELAY=5
MAX_RETRY_DELAY=60

# Helpers 

notify() {
    local message="$1"
    local icon="$2"
    notify-send "CloudLasso" "$message" -i "$icon" 2>/dev/null
}

check_internet() {
    wget -q --spider http://google.com
}

wait_for_internet() {
    local retry_delay=$MIN_RETRY_DELAY
    until check_internet; do
        echo "  Waiting for internet... next check in ${retry_delay}s"
        notify "Waiting for internet... Next check in $retry_delay seconds." "$ICON_SYNC"
        sleep $retry_delay
        retry_delay=$(( retry_delay < MAX_RETRY_DELAY ? retry_delay * 2 : MAX_RETRY_DELAY ))
    done
}

is_mounted() {
    mountpoint -q "$1" 2>/dev/null
}

execute_mount() {
    local remote_name="$1"
    local mount_point="$2"

    [ ! -d "$mount_point" ] && mkdir -p "$mount_point"

    rclone mount "$remote_name" "$mount_point" \
        --file-perms=0777 \
        --vfs-cache-mode=full \
        --network-mode \
        --buffer-size=0 \
        --daemon

    sleep $MIN_RETRY_DELAY
    is_mounted "$mount_point"
}

process_mount() {
    local remote_name="$1"
    local mount_point="$2"
    local friendly_name="$3"

    if is_mounted "$mount_point"; then
        echo "  $friendly_name already mounted at '$mount_point'"
        notify "$friendly_name is already mounted at '$mount_point'" "$ICON_HAPPY"
        return
    fi

    echo "  Mounting $friendly_name..."
    notify "Attempting to mount $friendly_name..." "$ICON_SYNC"

    local attempt=1
    local retry_delay=$MIN_RETRY_DELAY

    until execute_mount "$remote_name" "$mount_point"; do
        echo "  Failed (attempt $attempt). Retrying in ${retry_delay}s..."
        notify "Failed to mount $friendly_name (Attempt $attempt). Retrying in $retry_delay s..." "$ICON_SAD"
        sleep $retry_delay
        retry_delay=$(( retry_delay < MAX_RETRY_DELAY ? retry_delay * 2 : MAX_RETRY_DELAY ))
        ((attempt++))
    done

    echo "  $friendly_name mounted successfully!"
    notify "$friendly_name mounted successfully!" "$ICON_HAPPY"
}

# Config persistence 

load_config() {
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    CLOUDLASSO_REMOTES=("${CLOUDLASSO_REMOTES[@]}")
}

save_config() {
    [ ! -d "$CONFIG_DIR" ] && mkdir -p "$CONFIG_DIR"
    {
        echo "# CloudLasso configuration — auto-generated"
        echo "CLOUDLASSO_REMOTES=("
        for entry in "${CLOUDLASSO_REMOTES[@]}"; do
            echo "  $(printf '%q' "$entry")"
        done
        echo ")"
    } > "$CONFIG_FILE"
}

# Display 

print_banner() {
    echo -e "${CYAN}"
    cat << 'BANNER'
   _____ _                 _ _
  / ____| |               | | |
 | |    | | ___  _   _  __| | |     __ _ ___ ___  ___
 | |    | |/ _ \| | | |/ _` | |    / _` / __/ __|/ _ \
 | |____| | (_) | |_| | (_| | |___| (_| \__ \__ \ (_) |
  \_____|_|\___/ \__,_|\__,_|______\__,_|___/___/\___/
BANNER
    echo -e "${NC}"
    echo -e "  ${DIM}Lasso your cloud files down to local disk${NC}"
    echo ""
}

print_configured_remotes() {
    if [ ${#CLOUDLASSO_REMOTES[@]} -eq 0 ]; then
        echo "  No remotes configured yet."
    else
        echo "  Configured remotes:"
        echo "  "
        local i=1
        for entry in "${CLOUDLASSO_REMOTES[@]}"; do
            IFS='|' read -r remote mountpoint name <<< "$entry"
            local status="unmounted"
            is_mounted "$mountpoint" && status="mounted"
            echo "  $i) $name  ($remote → $mountpoint) [$status]"
            ((i++))
        done
    fi
    echo ""
}

# Rclone remotes listing 

list_rclone_remotes() {
    if ! command -v rclone &>/dev/null; then
        echo "  rclone not found. Install it first."
        return 1
    fi

    local remotes
    remotes=$(rclone listremotes 2>/dev/null)

    echo "  Available rclone remotes:"
    echo "  "
    local i=1
    local remote_array=()
    if [ -n "$remotes" ]; then
        while IFS= read -r line; do
            remote_array+=("$line")
            echo "  $i) $line"
            ((i++))
        done <<< "$remotes"
    else
        echo "  (none found)"
    fi
    echo ""
    echo "  N) Add a new remote in rclone"

    RCLONE_REMOTE_LIST=("${remote_array[@]}")
    return 0
}

# Menu actions 

setup_new_remote() {
    while true; do
        echo ""
        echo "   Setup New Remote "
        echo ""

        if ! list_rclone_remotes; then
            echo ""
            read -rp "  Press Enter to return..." _
            return
        fi

        echo ""
        read -rp "  Select remote number, N for new, 0 to cancel: " choice

        if [[ "$choice" == "0" || -z "$choice" ]]; then
            return
        fi

        if [[ "${choice,,}" == "n" ]]; then
            echo ""
            echo "  Launching rclone config..."
            echo "  "
            rclone config
            echo ""
            echo "  Back to CloudLasso."
            continue
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#RCLONE_REMOTE_LIST[@]} )); then
            echo "  Invalid selection."
            read -rp "  Press Enter to return..." _
            return
        fi

        break
    done

    local selected_remote="${RCLONE_REMOTE_LIST[$((choice - 1))]}"
    echo "  Selected: $selected_remote"

    local default_name="${selected_remote%:}"
    read -rp "  Friendly name [$default_name]: " friendly_name
    friendly_name="${friendly_name:-$default_name}"

    local default_mount="$HOME/${default_name}"
    read -rp "  Mount point [$default_mount]: " mount_point
    mount_point="${mount_point:-$default_mount}"

    for entry in "${CLOUDLASSO_REMOTES[@]}"; do
        IFS='|' read -r existing_remote _ _ <<< "$entry"
        if [[ "$existing_remote" == "$selected_remote" ]]; then
            echo "  Remote '$selected_remote' already configured. Use 'Modify' instead."
            read -rp "  Press Enter to return..." _
            return
        fi
    done

    CLOUDLASSO_REMOTES+=("${selected_remote}|${mount_point}|${friendly_name}")
    save_config
    echo ""
    echo "  Remote '$friendly_name' added."

    read -rp "  Mount now? [Y/n]: " mount_now
    if [[ "${mount_now,,}" != "n" ]]; then
        wait_for_internet
        process_mount "$selected_remote" "$mount_point" "$friendly_name"
    fi

    echo ""
    read -rp "  Press Enter to return..." _
}

modify_existing_remote() {
    echo ""
    echo "   Modify Existing Remote "
    echo ""

    if [ ${#CLOUDLASSO_REMOTES[@]} -eq 0 ]; then
        echo "  No remotes configured."
        read -rp "  Press Enter to return..." _
        return
    fi

    print_configured_remotes

    read -rp "  Select remote number (0 to cancel): " choice

    if [[ "$choice" == "0" || -z "$choice" ]]; then
        return
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#CLOUDLASSO_REMOTES[@]} )); then
        echo "  Invalid selection."
        read -rp "  Press Enter to return..." _
        return
    fi

    local idx=$((choice - 1))
    local entry="${CLOUDLASSO_REMOTES[$idx]}"
    IFS='|' read -r remote mountpoint name <<< "$entry"

    echo "  Editing: $name ($remote → $mountpoint)"
    echo ""
    echo "  1) Change friendly name"
    echo "  2) Change mount point"
    echo "  3) Mount / remount"
    echo "  4) Unmount"
    echo "  5) Remove remote"
    echo "  0) Back"
    echo ""
    read -rp "  Action: " action

    case "$action" in
        1)
            read -rp "  New friendly name [$name]: " new_name
            new_name="${new_name:-$name}"
            CLOUDLASSO_REMOTES[$idx]="${remote}|${mountpoint}|${new_name}"
            save_config
            echo "  Renamed to '$new_name'."
            ;;
        2)
            if is_mounted "$mountpoint"; then
                echo "  Unmount first before changing mount point."
                read -rp "  Press Enter to return..." _
                return
            fi
            read -rp "  New mount point [$mountpoint]: " new_mp
            new_mp="${new_mp:-$mountpoint}"
            CLOUDLASSO_REMOTES[$idx]="${remote}|${new_mp}|${name}"
            save_config
            echo "  Mount point changed to '$new_mp'."
            ;;
        3)
            if is_mounted "$mountpoint"; then
                echo "  Unmounting first..."
                fusermount -u "$mountpoint" 2>/dev/null
                sleep 2
            fi
            wait_for_internet
            process_mount "$remote" "$mountpoint" "$name"
            ;;
        4)
            if is_mounted "$mountpoint"; then
                fusermount -u "$mountpoint" 2>/dev/null
                echo "  Unmounted '$name'."
                notify "$name unmounted." "$ICON_HAPPY"
            else
                echo "  '$name' is not mounted."
            fi
            ;;
        5)
            if is_mounted "$mountpoint"; then
                echo "  Unmounting first..."
                fusermount -u "$mountpoint" 2>/dev/null
                sleep 2
            fi
            unset 'CLOUDLASSO_REMOTES[idx]'
            CLOUDLASSO_REMOTES=("${CLOUDLASSO_REMOTES[@]}")
            save_config
            echo "  Remote '$name' removed."
            ;;
        0|"") return ;;
        *) echo "  Invalid action." ;;
    esac

    echo ""
    read -rp "  Press Enter to return..." _
}

# Startup management 

SERVICE_FILE="$HOME/.config/systemd/user/cloudlasso.service"

is_startup_enabled() {
    systemctl --user is-enabled cloudlasso.service &>/dev/null
}

enable_startup() {
    mkdir -p "$HOME/.config/systemd/user"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=CloudLasso — mount cloud remotes
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$(readlink -f "$0") --mount-all
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable cloudlasso.service
    echo "  Startup enabled. Remotes will mount on login."
}

disable_startup() {
    systemctl --user disable cloudlasso.service 2>/dev/null
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
    echo "  Startup disabled."
}

toggle_startup() {
    echo ""
    if is_startup_enabled; then
        echo "  Startup is currently: ENABLED"
        read -rp "  Disable startup? [y/N]: " confirm
        if [[ "${confirm,,}" == "y" ]]; then
            disable_startup
        fi
    else
        echo "  Startup is currently: DISABLED"
        read -rp "  Enable startup? [Y/n]: " confirm
        if [[ "${confirm,,}" != "n" ]]; then
            enable_startup
        fi
    fi
    echo ""
    read -rp "  Press Enter to return..." _
}

mount_all() {
    if [ ${#CLOUDLASSO_REMOTES[@]} -eq 0 ]; then
        echo "  No remotes configured."
        return
    fi

    wait_for_internet

    for entry in "${CLOUDLASSO_REMOTES[@]}"; do
        IFS='|' read -r remote mountpoint name <<< "$entry"
        process_mount "$remote" "$mountpoint" "$name"
    done
}

# Main menu 

main_menu() {
    load_config

    while true; do
        clear
        print_banner
        print_configured_remotes

        local startup_status="OFF"
        is_startup_enabled && startup_status="ON"

        echo "  1) Setup a new remote"
        echo "  2) Modify existing remote"
        echo "  3) Mount all remotes"
        echo "  4) Startup on login [$startup_status]"
        echo "  5) Exit"
        echo ""
        read -rp "  Choose an option: " choice

        case "$choice" in
            1) setup_new_remote ;;
            2) modify_existing_remote ;;
            3) mount_all ;;
            4) toggle_startup ;;
            5)
                echo "  Bye!"
                exit 0
                ;;
            *)
                echo "  Invalid choice."
                sleep 1
                ;;
        esac
    done
}

# Entry point

if [[ "$1" == "--mount-all" ]]; then
    load_config
    mount_all
else
    main_menu
fi
