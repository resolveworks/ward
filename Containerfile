# Keep the base tag, digest, and ALA date aligned.
FROM docker.io/library/archlinux:base-20260712.0.555161@sha256:9edcc183d2505745a1da7a18bf12833dde174734610c72a5978031191504af1f

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
        tmux \
        zsh \
        ripgrep \
        jq \
        curl \
        nodejs \
        pnpm \
        python \
    && sed -i 's/^#en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && printf '%s\n' 'LANG=en_US.UTF-8' > /etc/locale.conf \
    && ln -sfn /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime \
    && groupadd --gid 1000 agent \
    && useradd \
        --uid 1000 \
        --gid 1000 \
        --home-dir /home/agent \
        --create-home \
        --shell /bin/zsh \
        agent \
    && passwd --lock agent \
    && install -d -o agent -g agent -m 0755 \
        /workspace \
        /home/agent \
        /home/agent/.pi \
        /home/agent/.oh-my-zsh \
    && install -o agent -g agent -m 0644 /dev/null \
        /home/agent/.tmux.conf \
    && install -o agent -g agent -m 0644 /dev/null \
        /home/agent/.zshrc \
    && printf '%s\n' 'new-session -d -s ward' > /etc/tmux.conf \
    && rm -rf /var/cache/pacman/pkg/*

ENV HOME=/home/agent \
    USER=agent \
    SHELL=/bin/zsh \
    LANG=en_US.UTF-8

WORKDIR /workspace
USER 1000:1000

# /etc/tmux.conf creates the session; -D keeps the server in the foreground.
CMD ["/usr/bin/tmux", "-D"]
