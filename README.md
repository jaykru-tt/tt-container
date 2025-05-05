# Usage
Tweak the Dockerfile as you wish, change the username, etc.
Build the container: `sudo docker built -t jaykrutt/tt-dev:latest .` from this directory.

Then you can start up a new instance with `./dock.rb`. Make sure you have docker
installed. This currently requires sudo to be installed and your user to be a
sudoer. dock.rb will map most things in your home folder into the container.
Please look carefully at dock.rb to make sure this fits your requirements.

# Overview
This is an opinionated container setup derived from the tt-metalium Ubuntu 22.04
container image. It come with nix pre-installed, as well as a handful of
packages installed from nix:

- emacs
- stow (for installing dotfiles)
- zsh
- zellij
- git
- helix
- fd
- libtool (for a fancy terminal emulator in emacs)
- ripgrep

It also installs nvm/npm and Claude Code, if that's your jam.

It comes with my [dotfiles](https://github.com/jaykru/dotfiles) set up out of
the box. My dotfiles include a couple of handy utility functions for working on
tt-metal:

- `install_env`, which sets up a direnv in the `tt-train` directory for managing a handful of metalium environment variables.
- `cleanup`, which does a pretty complete purge of the working tree to a clean HEAD state. *Use it with care.*
- `setup_python_env`, which allows you to source the metalium Python venv.
- `build_metal`, a handy wrapper around build_metal.sh.
- `build_train`, a handy wrapper for building TT-Train.
- `test_train`, a wrapper around the TT-Train gtest suite. Pass it a filter and it will run tests matching `*filter*`.
- `init`, which cleans up the working tree, configures and builds Metalium, sets up the Python venv for Metalium, sources it, then builds TT-Train. This is very nice for setting up a new worktree or cloned repo.
