#!/bin/bash

# common_os.sh - OS detection helpers for installer
# Location: scripts/installation_scripts/common/common_os.sh

detect_os_family() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|raspbian|linuxmint)
                echo "debian"
                ;;
            rhel|centos|fedora|rocky|almalinux|ol)
                echo "redhat"
                ;;
            opensuse*|sles|sled)
                echo "suse"
                ;;
            arch|manjaro|endeavouros|artix)
                echo "arch"
                ;;
            slackware)
                echo "slackware"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    elif [ -f /etc/redhat-release ]; then
        echo "redhat"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/slackware-version ]; then
        echo "slackware"
    else
        echo "unknown"
    fi
}

export -f detect_os_family
