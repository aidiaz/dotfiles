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

  local pkgs_to_install_apt=()

  # Git
  if ! command_exists git; then
    echo "git not found. Adding to apt installation list."
    pkgs_to_install_apt+=("git")
  else
    echo "git is already installed."
  fi

  # Curl - needed for NodeSource and other installers
  if ! command_exists curl; then
    echo "curl not found. Adding to apt installation list."
    pkgs_to_install_apt+=("curl")
  else
    echo "curl is already installed."
  fi

  # OpenSSH Server
  if ! command_exists sshd; then
    echo "openssh-server (sshd) not found. Adding to apt installation list."
    pkgs_to_install_apt+=("openssh-server")
  else
    echo "openssh-server (sshd) appears to be installed."
  fi

  # Neovim (nvim)
  if ! command_exists nvim; then
    echo "Neovim (nvim) not found. Adding to apt installation list."
    pkgs_to_install_apt+=("neovim")
  else
    echo "Neovim (nvim) is already installed."
  fi

  # fd (fd-find)
  if ! command_exists fd; then
    echo "fd (fd-find) not found. Adding 'fd-find' to apt installation list."
    pkgs_to_install_apt+=("fd-find")
  else
    echo "fd (fd-find) is already installed."
  fi

  # tmux
  if ! command_exists tmux; then
    echo "tmux not found. Adding 'tmux' to apt installation list."
    pkgs_to_install_apt+=("tmux")
  else
    echo "tmux is already installed"
  fi

  # python-venv
  if ! command_exists python3.12-venv; then
    echo "python3.12-venv not found. Adding 'python3.12-venv' to apt installation list."
    pkgs_to_install_apt+=("python3.12-venv")
  else
    echo "python3.12-venv is already installed"
  fi

  # C/C++ Compilation Tools
  if ! dpkg -s build-essential >/dev/null 2>&1; then
    echo "build-essential not found. Adding to apt installation list."
    pkgs_to_install_apt+=("build-essential")
  else
    echo "build-essential is already installed."
  fi

  if ! command_exists gdb; then
    echo "gdb (GNU Debugger) not found. Adding to apt installation list."
    pkgs_to_install_apt+=("gdb")
  else
    echo "gdb is already installed."
  fi

  if ! command_exists clang; then
    echo "clang not found. Adding to apt installation list."
    pkgs_to_install_apt+=("clang")
  else
    echo "clang is already installed."
  fi

  # Node.js 20.x specific installation via NodeSource
  local install_node_from_nodesource=false
  local node_already_v20=false

  if command_exists node; then
    current_node_version=$(node -v)
    if [[ "$current_node_version" == v20.* ]]; then
      echo "Node.js version 20.x ($current_node_version) is already installed."
      node_already_v20=true
      if ! command_exists npm; then
        echo "Node.js 20.x is installed, but npm is missing. Adding 'npm' to apt installation list (should be bundled with NodeSource's nodejs)."
        # This is a fallback; NodeSource's nodejs package usually includes npm.
        pkgs_to_install_apt+=("npm")
      else
        echo "npm is also installed ($(npm -v))."
      fi
    else
      echo "Node.js is installed ($current_node_version) but is not version 20.x. Will upgrade/reinstall using NodeSource."
      install_node_from_nodesource=true
    fi
  else
    echo "Node.js not found. Will install version 20.x using NodeSource."
    install_node_from_nodesource=true
  fi

  if [[ "$install_node_from_nodesource" == "true" ]]; then
    # Ensure curl is available before running NodeSource script.
    # If 'curl' was added to pkgs_to_install_apt earlier, it won't be installed until the main apt command.
    # So, we need to install curl now if it's not present.
    if ! command_exists curl; then
      echo "curl is required to setup NodeSource repository. Installing curl first..."
      sudo apt update # Update before this specific install
      sudo apt install -y curl
      if ! command_exists curl; then
        echo "ERROR: Failed to install curl. Cannot setup NodeSource repository for Node.js 20."
        exit 1 # Exit if curl installation fails
      fi
    fi
    echo "Setting up NodeSource repository for Node.js 20.x..."
    # The NodeSource script handles adding the GPG key and source list.
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    # NodeSource script usually runs 'apt-get update' or advises to.
    # We will run 'sudo apt update' before the main install loop anyway.
    pkgs_to_install_apt+=("nodejs") # This will now pull Node.js 20.x and npm from NodeSource
  fi

  # Attempt to install/update all collected packages using apt
  if command_exists apt; then
    # Remove duplicates from the list
    local unique_pkgs_to_install_apt
    unique_pkgs_to_install_apt=($(echo "${pkgs_to_install_apt[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    if [ ${#unique_pkgs_to_install_apt[@]} -gt 0 ]; then
      echo "Attempting to install/update system packages via apt: ${unique_pkgs_to_install_apt[*]}"
      sudo apt update # Crucial after adding new sources like NodeSource
      sudo apt install -y "${unique_pkgs_to_install_apt[@]}"

      # Create symlink for fd if fd-find was installed and fd command isn't available
      if command_exists fdfind && ! command_exists fd; then
        echo "Command 'fdfind' found but 'fd' is not. Creating symlink for fd."
        # Prefer /usr/local/bin for user-installed links if possible, or /usr/bin
        local fd_link_path="/usr/local/bin/fd"
        if [ ! -w /usr/local/bin ] && [ -w /usr/bin ]; then # If /usr/local/bin not writable, try /usr/bin
            fd_link_path="/usr/bin/fd"
        fi
        echo "Attempting to create symlink at $fd_link_path."
        sudo ln -sf "$(command -v fdfind)" "$fd_link_path"
        if command_exists fd; then
            echo "Symlink created: $fd_link_path -> $(command -v fdfind)"
        else
            echo "Failed to create symlink for fd or it's not in PATH immediately. Please check manually."
        fi
      fi
    else
      echo "All required system packages appear to be already installed or up-to-date."
    fi
  else
    if [ ${#pkgs_to_install_apt[@]} -gt 0 ]; then # Check original list
      echo "apt package manager not found, but some system packages were requested. Please install manually: ${pkgs_to_install_apt[*]}"
    fi
  fi

  # --- Oh My Posh (via curl) ---
  if ! command_exists oh-my-posh; then
    echo "Installing Oh My Posh using curl..."
    if command_exists curl; then # curl should be installed by now if it was needed
      local arch
      case $(uname -m) in
        "x86_64") arch="amd64" ;;
        "arm64" | "aarch64") arch="arm64" ;;
        *) echo "Unsupported architecture for Oh My Posh automatic install: $(uname -m)"; exit 1 ;;
      esac
      sudo curl -L "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-${arch}" -o /usr/local/bin/oh-my-posh
      sudo chmod +x /usr/local/bin/oh-my-posh
      echo "Oh My Posh installed to /usr/local/bin/oh-my-posh"
      echo "IMPORTANT: Add 'eval \"\$(oh-my-posh init zsh)\"' to your $HOME/dotfiles/.zshrc"
    else
      echo "curl is required to install Oh My Posh automatically but was not found/installed. Please install curl first."
    fi
  else
    echo "Oh My Posh is already installed."
  fi

  # --- Zoxide (via curl) ---
  if ! command_exists zoxide; then
    echo "Installing Zoxide using curl..."
    if command_exists curl; then
      curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
      echo "Zoxide installed."
      echo "IMPORTANT: The Zoxide installer might have updated your shell config. Otherwise, add 'eval \"\$(zoxide init zsh)\"' to your $HOME/dotfiles/.zshrc."
    else
      echo "curl is required to install Zoxide automatically but was not found/installed. Please install curl first."
    fi
  else
    echo "Zoxide is already installed."
  fi

  # --- fzf (fuzzy finder - via git clone and install script) ---
  if ! command_exists fzf; then
    echo "Installing fzf..."
    if command_exists git; then # git should be installed by now if it was needed
      if [ ! -d "$HOME/.fzf" ]; then
        mkdir "$HOME/.fzf"
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        # "$HOME/.fzf/install" --all
        echo "fzf installed."
        echo "IMPORTANT: fzf's install script likely updated your active shell config. Since you symlink .zshrc, ensure the necessary fzf lines are in $HOME/dotfiles/.zshrc."
      else
        echo "$HOME/.fzf directory already exists. Ensuring fzf is set up..."
        # "$HOME/.fzf/install" --all
      fi
    else
      echo "git is required to install fzf using the standard method but was not found/installed. Please install git first."
    fi
  else
    echo "fzf is already installed."
  fi

  # --- fzf (fuzzy finder - via git clone and install script) ---
  if command_exists tmux; then
    echo "Installing tpm..."
    if command_exists git; then # git should be installed by now if it was needed
      if [ ! -d "$HOME/dotfiles/tmux/plugins/" ]; then
          git clone https://github.com/tmux-plugins/tpm "$HOME/dotfiles/tmux/plugins/tpm/"
          # tmux
          # tmux source "$HOME/dotfiles/tmux/tmux.conf"
        echo "tpm cloned!"
        echo "IMPORTANT: To install tpm and the plugins in the config do <prefix> + I"
      else
        echo "$HOME/dotfiles/tmux/plugins/ directory already exists. Ensuring tmux-plugins is set up..."
        # tmux
        # tmux source "$HOME/dotfiles/tmux/tmux.conf"
      fi
    else
      echo "git is required to install tmux-plugins using the standard method but was not found/installed. Please install git first."
    fi
  else
    echo "tmux is already installed."
  fi
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
