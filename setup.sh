#!/bin/zsh

# Exit on any error
set -e

# --- Helper Functions ---
# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Package Installation Function ---
install_dependencies() {
  echo "Checking and installing required dependencies..."
  local os_type
  os_type=$(uname -s)

  # --- macOS Specific Installation (using Homebrew) ---
  if [[ "$os_type" == "Darwin" ]]; then
    echo "Detected macOS. Using Homebrew for package management."
    if ! command_exists brew; then
      echo "ERROR: Homebrew (brew) not found. Please install Homebrew first: https://brew.sh/"
      echo "Skipping package installations that depend on Homebrew."
      # Optionally exit here: exit 1
    else
      echo "Homebrew found. Updating Homebrew..."
      brew update

      local pkgs_to_install_brew=()

      # Core System Tools
      if ! command_exists git; then pkgs_to_install_brew+=("git"); else echo "git is already installed."; fi
      if ! command_exists curl; then pkgs_to_install_brew+=("curl"); else echo "curl is already installed."; fi
      if ! brew list openssh &>/dev/null && ! command_exists ssh; then pkgs_to_install_brew+=("openssh"); else echo "OpenSSH client appears to be installed."; fi
      
      # Development Tools
      if ! command_exists nvim; then pkgs_to_install_brew+=("neovim"); else echo "Neovim (nvim) is already installed."; fi
      if ! command_exists fd; then pkgs_to_install_brew+=("fd"); else echo "fd is already installed."; fi
      if ! command_exists tmux; then pkgs_to_install_brew+=("tmux"); else echo "tmux is already installed."; fi
      if ! command_exists python3.12 && ! (command_exists python3 && python3 -V 2>&1 | grep -q "3\.12"); then
          if brew info python@3.12 &>/dev/null; then pkgs_to_install_brew+=("python@3.12"); 
          elif brew info python@3.11 &>/dev/null; then pkgs_to_install_brew+=("python@3.11");
          else pkgs_to_install_brew+=("python"); fi
      else echo "Python 3.12 (or compatible) seems installed."; fi
      if ! command_exists gdb; then pkgs_to_install_brew+=("gdb"); else echo "gdb is already installed."; fi
      if ! command_exists clang; then echo "Clang not found. Part of Xcode Command Line Tools. Run 'xcode-select --install'."; else echo "clang is already installed."; fi

      # Node.js 20.x
      local install_node_brew=false
      if command_exists node; then
        current_node_version=$(node -v)
        if [[ "$current_node_version" == v20.* ]]; then echo "Node.js version 20.x ($current_node_version) is already installed.";
        else echo "Node.js is installed ($current_node_version) but not v20.x. Will attempt upgrade via Homebrew."; install_node_brew=true; fi
      else echo "Node.js not found. Will install version 20.x using Homebrew."; install_node_brew=true; fi
      if [[ "$install_node_brew" == "true" ]]; then
        if brew info node@20 &>/dev/null; then pkgs_to_install_brew+=("node@20"); else pkgs_to_install_brew+=("node"); fi
      fi

      # Shell Utilities (replacing curl methods)
      if ! command_exists oh-my-posh; then pkgs_to_install_brew+=("oh-my-posh"); else echo "Oh My Posh is already installed."; fi
      if ! command_exists zoxide; then pkgs_to_install_brew+=("zoxide"); else echo "Zoxide is already installed."; fi
      if ! command_exists fzf; then pkgs_to_install_brew+=("fzf"); else echo "fzf is already installed."; fi

      # Install collected Homebrew packages
      if [ ${#pkgs_to_install_brew[@]} -gt 0 ]; then
        echo "Attempting to install/update packages via Homebrew: ${pkgs_to_install_brew[*]}"
        local unique_pkgs_to_install_brew
        unique_pkgs_to_install_brew=($(echo "${pkgs_to_install_brew[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
        if brew install "${unique_pkgs_to_install_brew[@]}"; then
            echo "Homebrew packages installed successfully."
            if printf '%s\n' "${unique_pkgs_to_install_brew[@]}" | grep -q -w "fzf"; then
                 echo "Running fzf post-install steps (key-bindings, completion)..."
                 # Attempt to run non-interactive install for fzf's shell integration if brew didn't do it
                 # Checgrek if the brew formula for fzf handles this automatically. Often it does.
                 # If not, this might be needed: $(brew --prefix)/opt/fzf/install --all --no-update-rc
                 echo "NOTE: For fzf shell integration, you might need to add 'eval \"\$(fzf --zsh)\"' or similar to your .zshrc if brew didn't set it up."
            fi
        else
            echo "Error installing some Homebrew packages. Please check the output above."
        fi
      else
        echo "All required Homebrew packages appear to be already installed or up-to-date."
      fi

      # build-essential equivalent: Xcode Command Line Tools
      if ! command_exists clang || ! command_exists make || ! command_exists git; then
          echo "INFO: Xcode Command Line Tools might be missing or incomplete. Run 'xcode-select --install'."
      else
          echo "Xcode Command Line Tools seem to be present."
      fi
    fi # End of if command_exists brew

  # --- Linux Specific Installation (using apt) ---
  elif [[ "$os_type" == "Linux" ]]; then
    echo "Detected Linux. Using apt for package management."
    if ! command_exists apt; then
        echo "ERROR: apt package manager not found on Linux system. Cannot install dependencies."
    else
        local pkgs_to_install_apt=()

        # Core & Dev Tools
        if ! command_exists git; then pkgs_to_install_apt+=("git"); fi
        if ! command_exists curl; then pkgs_to_install_apt+=("curl"); fi
        if ! command_exists sshd; then pkgs_to_install_apt+=("openssh-server"); fi
        if ! command_exists nvim; then pkgs_to_install_apt+=("neovim"); fi
        if ! command_exists fd; then pkgs_to_install_apt+=("fd-find"); fi
        if ! command_exists tmux; then pkgs_to_install_apt+=("tmux"); fi
        if ! command_exists python3.12-venv; then pkgs_to_install_apt+=("python3.12-venv"); fi
        if ! dpkg -s build-essential >/dev/null 2>&1; then pkgs_to_install_apt+=("build-essential"); fi
        if ! command_exists gdb; then pkgs_to_install_apt+=("gdb"); fi
        if ! command_exists clang; then pkgs_to_install_apt+=("clang"); fi

        # Node.js 20.x via NodeSource
        local install_node_from_nodesource=false
        if command_exists node; then
            current_node_version=$(node -v)
            if [[ "$current_node_version" == v20.* ]]; then
                if ! command_exists npm; then pkgs_to_install_apt+=("npm"); fi
            else install_node_from_nodesource=true; fi
        else install_node_from_nodesource=true; fi

        if [[ "$install_node_from_nodesource" == "true" ]]; then
            if ! command_exists curl; then
                if ! printf '%s\n' "${pkgs_to_install_apt[@]}" | grep -q -w "curl"; then pkgs_to_install_apt+=("curl"); fi
                # Temporarily install curl if needed now
                if ! command_exists curl && [ ${#pkgs_to_install_apt[@]} -gt 0 ]; then
                    sudo apt update && sudo apt install -y curl
                fi
            fi
            if command_exists curl; then
                echo "Setting up NodeSource repository for Node.js 20.x..."
                curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
                pkgs_to_install_apt+=("nodejs")
            else echo "Curl still not available. Skipping Node.js setup via NodeSource."; fi
        fi

        # Install collected apt packages
        if [ ${#pkgs_to_install_apt[@]} -gt 0 ]; then
            local unique_pkgs_to_install_apt
            unique_pkgs_to_install_apt=($(echo "${pkgs_to_install_apt[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
            if [ ${#unique_pkgs_to_install_apt[@]} -gt 0 ]; then
                echo "Attempting to install/update system packages via apt: ${unique_pkgs_to_install_apt[*]}"
                sudo apt update && sudo apt install -y "${unique_pkgs_to_install_apt[@]}"
                if command_exists fdfind && ! command_exists fd; then
                    local fd_link_path="/usr/local/bin/fd"; if [ ! -w /usr/local/bin ] && [ -w /usr/bin ]; then fd_link_path="/usr/bin/fd"; fi
                    sudo ln -sf "$(command -v fdfind)" "$fd_link_path" && echo "Symlinked fdfind to fd."
                fi
            fi
        else echo "All required system packages (apt) appear to be installed or up-to-date."; fi
        
        # Shell Utilities (using curl/git for Linux)
        # Oh My Posh (curl)
        if ! command_exists oh-my-posh; then
            if command_exists curl; then
                local arch; case $(uname -m) in "x86_64") arch="amd64" ;; "arm64" | "aarch64") arch="arm64" ;; *) arch="" ;; esac
                if [[ -n "$arch" ]]; then
                    echo "Installing Oh My Posh (Linux)..."
                    sudo curl -L "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-${arch}" -o /usr/local/bin/oh-my-posh
                    sudo chmod +x /usr/local/bin/oh-my-posh
                fi
            else echo "curl needed for Oh My Posh on Linux."; fi
        else echo "Oh My Posh already installed."; fi

        # Zoxide (curl script)
        if ! command_exists zoxide; then
            if command_exists curl; then
                echo "Installing Zoxide (Linux)..."
                curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
            else echo "curl needed for Zoxide on Linux."; fi
        else echo "Zoxide already installed."; fi

        # fzf (git clone + install script)
        if ! command_exists fzf; then
            if command_exists git; then
                echo "Installing fzf (Linux)..."
                if [ ! -d "$HOME/.fzf" ]; then git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"; fi
                "$HOME/.fzf/install" --all
            else echo "git needed for fzf on Linux."; fi
        else echo "fzf already installed."; fi
    fi # End of if command_exists apt
  else
    echo "Unsupported operating system: $os_type. Skipping OS-specific package installations."
  fi # End of OS type check

  # --- Tmux Plugin Manager (TPM) --- (Common, assumes git/tmux are present)
  echo "Checking Tmux Plugin Manager (TPM)..."
  local tpm_install_dir="$HOME/dotfiles/tmux/plugins/tpm"
  if command_exists tmux && command_exists git; then
    if [ ! -d "$tpm_install_dir" ]; then
      echo "Installing TPM to $tpm_install_dir..."
      mkdir -p "$(dirname "$tpm_install_dir")"
      if git clone https://github.com/tmux-plugins/tpm "$tpm_install_dir"; then echo "TPM installed successfully.";
      else echo "Failed to clone TPM repository."; fi
    else echo "TPM already found at $tpm_install_dir."; fi
  else echo "tmux and git are required for TPM. One or both not found. Skipping TPM."; fi

  echo "Dependency check and tool installation phase complete."
}
# --- Main Script Execution ---

# Step 1: Install Dependencies and Tools
install_dependencies

# Step 2: Symlink Dotfiles

DOTFILES_DIR="$HOME/dotfiles"
config_folder="$HOME/.config"
ssh_folder="$HOME/.ssh"

echo "Setting up $config_folder..."
mkdir -p "$config_folder"

config_targets_to_ensure_parents_for=(
    "$config_folder/tmux/tmux.conf"
    "$config_folder/ohmyposh/catppuccin.omp.json"
    "$config_folder/nvim"
)
for target_path in "${config_targets_to_ensure_parents_for[@]}"; do
  mkdir -p "$(dirname "$target_path")"
done

echo "Setting up $ssh_folder..."
if [ ! -d "$ssh_folder" ]; then
  mkdir -p "$ssh_folder"
  chmod 700 "$ssh_folder"
  echo "Created $ssh_folder with 700 permissions."
else
  echo "$ssh_folder already exists. Verifying permissions..."
  chmod 700 "$ssh_folder"
fi

echo "Creating symlinks..."

local SSHCONFIG=""
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
    echo "Found linux system"
    SSHCONFIG="$DOTFILES_DIR/.ssh/linux-config"
else
    echo "Found osx system"
    SSHCONFIG="$DOTFILES_DIR/.ssh/osx-config"
fi

local ZSHRC=""
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
    echo "Found linux system"
    ZSHRC="$DOTFILES_DIR/.zshrc-linux"
else
    echo "Found osx system"
    ZSHRC="$DOTFILES_DIR/.zshrc-osx"
fi

declare -A symlinks
symlinks=(
  ["$ZSHRC"]="$HOME/.zshrc"
  ["$DOTFILES_DIR/nvim"]="$config_folder/nvim"
  ["$SSHCONFIG"]="$ssh_folder/config"
  ["$DOTFILES_DIR/.gitconfig"]="$HOME/.gitconfig"
  ["$DOTFILES_DIR/tmux/tmux.conf"]="$config_folder/tmux/tmux.conf"
  ["$DOTFILES_DIR/ohmyposh/catppuccin.omp.json"]="$config_folder/ohmyposh/catppuccin.omp.json"
)

for source in "${(@k)symlinks}"; do
  target="${symlinks[$source]}"
  target_dir=$(dirname "$target")

  if [ ! -d "$target_dir" ]; then
      mkdir -p "$target_dir"
      echo "Created directory for symlink target: $target_dir"
  fi

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    backup_name="${target}.bak_$(date +%F-%T)"
    echo "Backing up existing file/directory: $target to $backup_name"
    mv "$target" "$backup_name"
  fi

  if [ -L "$target" ]; then
    echo "Removing existing symlink at $target"
    rm "$target"
  fi

  if [ -d "$source" ]; then
    ln -sfn "$source" "$target"
    echo "Linked directory: $source -> $target"
  else
    ln -sf "$source" "$target"
    echo "Linked file: $source -> $target"
  fi
done

echo "Setup complete!"
echo "---------------------------------------------------------------------"
echo "IMPORTANT REMINDERS:"
echo "1. Ensure your '$DOTFILES_DIR/.zshrc' contains initialization lines for:"
echo "   - Oh My Posh: eval \"\$(oh-my-posh init zsh --config '$config_folder/ohmyposh/catppuccin.omp.json')\""
echo "   - Zoxide:     eval \"\$(zoxide init zsh)\""
echo "   - fzf:        The fzf install script might have added lines. Verify they are in your source .zshrc."
echo "2. If 'fd-find' was installed, a symlink from 'fd' to 'fdfind' might have been created."
echo "   Verify 'fd' command works. If not, you might need to create the symlink manually."
echo "3. C/C++ build tools (build-essential, gdb, clang) should now be installed."
echo "4. Node.js 20.x and npm should now be installed from NodeSource if they weren't already."
echo "5. Restart your shell or source your .zshrc for changes to take effect."
echo "6. For tmux setup, run tmux server, inside run 'tmux source .config/tmux/tmux.conf'"
echo "7. Do <prefix> + I to install tpm and other tmux plugins"
echo "---------------------------------------------------------------------"
