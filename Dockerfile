# Dockerfile
FROM ghcr.io/tenstorrent/tt-metal/tt-metalium/ubuntu-22.04-dev-amd64:latest

ENV DEBIAN_FRONTEND=noninteractive

# 1) Pull in the essentials for the Nix installer
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      xz-utils \
      sudo

RUN echo "loudbox-n150" > /etc/hostname

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
# 2) Prepare the Nix store mount point
# RUN mkdir -m 0755 /nix && chown root:root /nix
# enable nix-command (new CLI) and flakes
RUN mkdir -p /etc/nix \
 && printf "experimental-features = nix-command flakes\n" >> /etc/nix/nix.conf

# 4) Switch to a shell that auto‑sources the nix‑daemon env for all subsequent RUNs
SHELL ["/bin/bash", "-lc"]

# add a non‑root user with UID/GID 1001 and give them passwordless sudo
ARG USERNAME=j
ARG USER_UID=1001
ARG USER_GID=1001
RUN groupadd -g ${USER_GID} ${USERNAME} \
 && useradd -m -u ${USER_UID} -g ${USER_GID} -G sudo -s /bin/bash ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}


# switch to that user
USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENV USER=j
ENV HOME=/home/j
ENV PATH=$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH

RUN bash <(curl -L https://nixos.org/nix/install) --yes

RUN nix profile install \
#     nixpkgs#cmake \
    nixpkgs#emacs \
    nixpkgs#stow \
    nixpkgs#zsh \
    nixpkgs#zellij \
    nixpkgs#git \
    nixpkgs#helix \
    nixpkgs#fd \
    nixpkgs#libtool \
    nixpkgs#ripgrep

# Create a script file sourced by both interactive and non-interactive bash shells
ENV BASH_ENV /home/${USERNAME}/.bash_env
RUN touch "${BASH_ENV}"
RUN echo '. "${BASH_ENV}"' >> ~/.bashrc

# Download and install nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | PROFILE="${BASH_ENV}" bash
RUN echo node > .nvmrc
RUN nvm install
RUN npm install -g @anthropic-ai/claude-code

RUN git clone https://github.com/jaykru/dotfiles
RUN cd dotfiles && \
    git submodule update --init --recursive && \
    stow doom && \
    stow zsh && \
    stow git

# RUN git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
# RUN ~/.config/emacs/bin/doom install --no-config --env --install --hooks --fonts --force

# Run zsh once to trigger zinit setup
RUN zsh -ic 'exit'

CMD ["zsh"]
