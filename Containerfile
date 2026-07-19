# Keep the base tag, digest, and ALA date aligned.
FROM docker.io/library/archlinux:base-20260712.0.555161@sha256:9edcc183d2505745a1da7a18bf12833dde174734610c72a5978031191504af1f

ARG WARD_USER
ARG WARD_HOME

LABEL org.opencontainers.image.title="Ward" \
      org.opencontainers.image.description="Rootless pi and tmux development environment" \
      org.opencontainers.image.source="https://github.com/resolveworks/ward"

# Install the complete package set in one transaction against the ALA snapshot.
RUN printf '%s\n' \
        'Server = https://archive.archlinux.org/repos/2026/07/12/$repo/os/$arch' \
        > /etc/pacman.d/mirrorlist \
    && pacman --noconfirm --needed --noprogressbar -Syu \
        base \
        base-devel \
        git \
        openssh \
        tmux \
        zsh \
        ripgrep \
        jq \
        curl \
        nodejs \
        pnpm \
        python \
        uv \
        alsa-lib \
        gtk3 \
        libcups \
        libxss \
        libxtst \
        nss \
        ttf-liberation \
        xorg-server-xvfb \
    && printf '%s\n' 'en_US.UTF-8 UTF-8' > /etc/locale.gen \
    && locale-gen \
    && printf '%s\n' 'LANG=en_US.UTF-8' > /etc/locale.conf \
    && ln -sfn /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime \
    && groupadd --gid 1000 "$WARD_USER" \
    && useradd \
        --uid 1000 \
        --gid 1000 \
        --home-dir "$WARD_HOME" \
        --create-home \
        --shell /bin/zsh \
        "$WARD_USER" \
    && passwd --lock "$WARD_USER" \
    && install -d -o "$WARD_USER" -g "$WARD_USER" -m 0755 \
        "$WARD_HOME" \
        "$WARD_HOME/Projects" \
        "$WARD_HOME/.cache" \
        "$WARD_HOME/.pi" \
        "$WARD_HOME/.oh-my-zsh" \
    && install -d -o "$WARD_USER" -g "$WARD_USER" -m 0700 \
        "$WARD_HOME/.ssh" \
    && install -o "$WARD_USER" -g "$WARD_USER" -m 0644 /dev/null \
        "$WARD_HOME/.gitconfig" \
    && install -o "$WARD_USER" -g "$WARD_USER" -m 0644 /dev/null \
        "$WARD_HOME/.tmux.conf" \
    && install -o "$WARD_USER" -g "$WARD_USER" -m 0644 /dev/null \
        "$WARD_HOME/.zshrc" \
    && install -o "$WARD_USER" -g "$WARD_USER" -m 0644 /dev/null \
        "$WARD_HOME/.ssh/allowed_signers" \
    && install -o "$WARD_USER" -g "$WARD_USER" -m 0644 /dev/null \
        "$WARD_HOME/.ssh/known_hosts" \
    && rm -rf /var/cache/pacman/pkg/*

ENV HOME=${WARD_HOME} \
    USER=${WARD_USER} \
    SHELL=/bin/zsh \
    LANG=en_US.UTF-8

WORKDIR ${WARD_HOME}/Projects
USER 1000:1000

# Start an empty server in the foreground; host clients create sessions.
CMD ["/usr/bin/tmux", "-S", "/run/ward/tmux.sock", "-D"]
