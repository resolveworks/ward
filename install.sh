#!/usr/bin/env bash
# Build and deploy the rootless Ward Quadlets for host user johan.

set -euo pipefail

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly EXPECTED_REPO_DIR=/home/johan/Projects/ward
readonly HOST_USER=johan
readonly HOST_UID=1000
readonly HOST_GID=1001
readonly HOST_HOME=/home/johan
readonly QUADLET_DIR=/etc/containers/systemd/users/1000
readonly BUILD_LINK="$QUADLET_DIR/ward.build"
readonly CONTAINER_LINK="$QUADLET_DIR/ward.container"
readonly SUBID_START=100000
readonly SUBID_COUNT=65536
readonly LEGACY_UNIT=systemd-nspawn@ward.service
readonly LEGACY_ROOT=/var/lib/machines/ward
readonly LEGACY_DEFINITION=/etc/systemd/nspawn/ward.nspawn
readonly LEGACY_DROP_IN=/etc/systemd/system/systemd-nspawn@ward.service.d
readonly USER_MANAGER="${HOST_USER}@.host"
readonly -a BIND_DIRECTORIES=(
    /home/johan/Projects
    /home/johan/.pi
    /home/johan/.oh-my-zsh
)
readonly -a BIND_FILES=(
    /home/johan/.tmux.conf
    /home/johan/.zshrc
)

log() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_root() {
    (( EUID == 0 )) || die 'run this script as root'
}

validate_host_user() {
    local entry name password uid gid gecos home shell

    entry=$(getent passwd "$HOST_USER") || die "host user $HOST_USER does not exist"
    IFS=: read -r name password uid gid gecos home shell <<<"$entry"
    [[ "$uid" == "$HOST_UID" ]] || \
        die "$HOST_USER must have UID $HOST_UID (found $uid)"
    [[ "$gid" == "$HOST_GID" ]] || \
        die "$HOST_USER must have primary GID $HOST_GID (found $gid)"
    [[ "$home" == "$HOST_HOME" ]] || \
        die "$HOST_USER must have home $HOST_HOME (found $home)"
}

validate_bind_sources() {
    local path

    for path in "${BIND_DIRECTORIES[@]}"; do
        [[ ! -L "$path" && -d "$path" ]] || \
            die "$path must be a real directory"
    done
    for path in "${BIND_FILES[@]}"; do
        [[ ! -L "$path" && -f "$path" ]] || \
            die "$path must be a real regular file"
    done
}

reject_legacy_ward() {
    if systemctl is-active --quiet "$LEGACY_UNIT"; then
        die "$LEGACY_UNIT is active; remove the legacy Ward machine first"
    fi

    [[ ! -e "$LEGACY_ROOT" && ! -L "$LEGACY_ROOT" ]] || \
        die "$LEGACY_ROOT still exists; remove the legacy Ward machine first"
    [[ ! -e "$LEGACY_DEFINITION" && ! -L "$LEGACY_DEFINITION" ]] || \
        die "$LEGACY_DEFINITION still exists; remove the legacy Ward machine first"
    [[ ! -e "$LEGACY_DROP_IN" && ! -L "$LEGACY_DROP_IN" ]] || \
        die "$LEGACY_DROP_IN still exists; remove the legacy Ward machine first"
}

install_host_prerequisite() {
    if ! pacman -Qq podman >/dev/null 2>&1; then
        log 'Installing Podman'
        pacman --noconfirm --needed -S podman
    fi

    [[ -x /usr/bin/podman ]] || die '/usr/bin/podman is unavailable'
    [[ -x /usr/lib/systemd/system-generators/podman-system-generator ]] || \
        die 'the Podman Quadlet generator is unavailable'
}

validate_user_namespaces() {
    local maximum

    [[ $(uname -m) == x86_64 ]] || \
        die 'the pinned Ward image supports only x86_64'

    maximum=$(< /proc/sys/user/max_user_namespaces)
    [[ "$maximum" =~ ^[0-9]+$ ]] || die 'cannot read user.max_user_namespaces'
    (( maximum > 0 )) || die 'unprivileged user namespaces are disabled'

    if [[ -e /proc/sys/kernel/unprivileged_userns_clone ]]; then
        [[ $(< /proc/sys/kernel/unprivileged_userns_clone) == 1 ]] || \
            die 'kernel.unprivileged_userns_clone must be 1'
    fi

    [[ $(stat -f -c %T /sys/fs/cgroup) == cgroup2fs ]] || \
        die 'Podman Quadlets require cgroup v2'
}

ensure_subid_range() {
    local file=$1
    local kind=$2
    local status

    if [[ ! -e "$file" ]]; then
        install -o root -g root -m 0644 /dev/null "$file"
    fi
    [[ ! -L "$file" && -f "$file" ]] || die "$file must be a regular file"

    set +e
    awk -F: \
        -v user="$HOST_USER" \
        -v target_start="$SUBID_START" \
        -v target_count="$SUBID_COUNT" '
        BEGIN {
            exact = 0
            bad = 0
            target_end = target_start + target_count
        }
        /^[[:space:]]*($|#)/ { next }
        NF != 3 || $2 !~ /^[0-9]+$/ || $3 !~ /^[0-9]+$/ {
            print "malformed subordinate-ID entry: " $0 > "/dev/stderr"
            bad = 1
            next
        }
        {
            range_start = $2 + 0
            range_end = range_start + $3
        }
        $1 == user {
            if (range_start == target_start && $3 == target_count) {
                exact++
            } else {
                print user " has an unexpected subordinate-ID range: " $0 \
                    > "/dev/stderr"
                bad = 1
            }
            next
        }
        range_start < target_end && target_start < range_end {
            print "the fixed " target_start ":" target_count \
                " range overlaps: " $0 > "/dev/stderr"
            bad = 1
        }
        END {
            if (exact > 1) {
                print "duplicate fixed subordinate-ID range for " user \
                    > "/dev/stderr"
                bad = 1
            }
            if (bad) exit 2
            if (exact == 1) exit 0
            exit 1
        }
    ' "$file"
    status=$?
    set -e

    case "$status" in
        0) ;;
        1)
            log "Adding the fixed $kind range for $HOST_USER"
            printf '%s:%s:%s\n' "$HOST_USER" "$SUBID_START" "$SUBID_COUNT" \
                >> "$file"
            ;;
        *) die "conflicting entries in $file" ;;
    esac
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

install_quadlet_link() {
    local source=$1
    local destination=$2

    [[ -r "$source" ]] || die "$source is not readable"
    if [[ -e "$destination" && -d "$destination" && ! -L "$destination" ]]; then
        die "$destination must not be a directory"
    fi
    ln -sfnT -- "$source" "$destination"
}

report_failure() {
    printf '\nWard unit status:\n' >&2
    user_systemctl --no-pager --full status \
        ward-build.service ward.service >&2 || true
    printf '\nWard container status:\n' >&2
    user_podman ps --all --filter name=ward >&2 || true
}

main() {
    require_root
    [[ "$REPO_DIR" == "$EXPECTED_REPO_DIR" ]] || \
        die "Ward must be deployed from $EXPECTED_REPO_DIR"

    validate_host_user
    validate_bind_sources
    reject_legacy_ward
    install_host_prerequisite
    validate_user_namespaces
    ensure_subid_range /etc/subuid subordinate-UID
    ensure_subid_range /etc/subgid subordinate-GID

    log "Enabling lingering for $HOST_USER"
    loginctl enable-linger "$HOST_USER"

    install -d -o root -g root -m 0755 "$QUADLET_DIR"
    install_quadlet_link "$REPO_DIR/ward.build" "$BUILD_LINK"
    install_quadlet_link "$REPO_DIR/ward.container" "$CONTAINER_LINK"

    runuser --user "$HOST_USER" -- test -r "$BUILD_LINK"
    runuser --user "$HOST_USER" -- test -r "$CONTAINER_LINK"

    log 'Reloading the user systemd manager'
    user_systemctl daemon-reload
    if ! user_systemctl cat ward-build.service ward.service >/dev/null; then
        report_failure
        die 'Quadlet did not generate the Ward services'
    fi

    log 'Building the Ward image'
    user_systemctl start podman-user-wait-network-online.service
    # ward.service Requires the build service. A normal build-service restart
    # would propagate a restart to a running Ward before the build completed.
    # Ignore requirement propagation for this explicit build job while still
    # honoring its ordering dependencies. RemainAfterExit then prevents the
    # container start below from triggering a second build.
    if ! user_systemctl --job-mode=ignore-requirements \
        restart ward-build.service; then
        report_failure
        die 'the Ward image build failed; the existing container was not stopped'
    fi

    log 'Starting Ward from the successfully built image'
    if ! user_systemctl restart ward.service; then
        report_failure
        die 'the Ward container failed to start'
    fi

    log 'Ward is built and running'
}

main "$@"
