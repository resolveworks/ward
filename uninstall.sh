#!/usr/bin/env bash
# Destructively remove Ward's rootless container, Quadlets, and image.

set -euo pipefail

readonly HOST_USER=johan
readonly HOST_UID=1000
readonly HOST_HOME=/home/johan
readonly QUADLET_DIR=/etc/containers/systemd/users/1000
readonly BUILD_LINK="$QUADLET_DIR/ward.build"
readonly CONTAINER_LINK="$QUADLET_DIR/ward.container"
readonly USER_MANAGER="${HOST_USER}@.host"
readonly IMAGE=localhost/ward:latest
readonly CONTAINER=ward

log() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

user_systemctl() {
    systemctl --user --machine="$USER_MANAGER" --no-ask-password "$@"
}

user_podman() {
    runuser --user "$HOST_USER" -- env -i \
        HOME="$HOST_HOME" \
        USER="$HOST_USER" \
        LOGNAME="$HOST_USER" \
        XDG_RUNTIME_DIR="/run/user/$HOST_UID" \
        PATH=/usr/local/bin:/usr/bin \
        /usr/bin/podman "$@"
}

main() {
    local manager_available=0

    (( EUID == 0 )) || die 'run this script as root'
    [[ $(id -u "$HOST_USER" 2>/dev/null || true) == "$HOST_UID" ]] || \
        die "$HOST_USER with UID $HOST_UID is required to remove rootless Ward state"

    if user_systemctl show-environment >/dev/null 2>&1; then
        manager_available=1
    fi

    if (( manager_available )); then
        if user_systemctl cat ward.service >/dev/null 2>&1; then
            log 'Stopping the Ward container service'
            user_systemctl stop ward.service
        fi
        if user_systemctl cat ward-build.service >/dev/null 2>&1; then
            log 'Stopping the Ward build service'
            user_systemctl stop ward-build.service
        fi
    fi

    rm -f -- "$BUILD_LINK" "$CONTAINER_LINK"

    if (( manager_available )); then
        log 'Reloading the user systemd manager'
        user_systemctl daemon-reload
    fi

    if [[ -x /usr/bin/podman ]]; then
        # Normally Quadlet removes the container when ward.service stops.
        # Remove an exact leftover so an interrupted uninstall can converge.
        if user_podman container exists "$CONTAINER"; then
            log 'Removing the Ward container'
            user_podman container rm --force "$CONTAINER"
        fi

        if user_podman image exists "$IMAGE"; then
            log 'Removing the Ward image'
            user_podman image rm "$IMAGE"
        fi
    fi

    log 'Ward is uninstalled'
}

main "$@"
