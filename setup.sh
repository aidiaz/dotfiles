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

  # Curl
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

  # C/C++ Compilation Tools
  if ! dpkg -s build-essential >/dev/null 2>&1; then # dpkg -s is a more reliable check for metapackages
    echo "build-essential not found. Adding to apt installation list."
    pkgs_to_install_apt+=("build-essential")
  else
    echo "build-essential is already installed."
  fi

  if ! command_exists gcc; then
    echo "gcc not found. Ensuring build-essential covers it or adding explicitly."
    # build-essential should pull this, but can be listed if strictness is needed
    # pkgs_to_install_apt+=("gcc") # Usually covered by build-essential
  else
    echo "gcc is already installed."
  fi

  if ! command_exists g++; then
    echo "g++ not found. Ensuring build-essential covers it or adding explicitly."
    # pkgs_to_install_apt+=("g++") # Usually covered by build-essential
  else
    echo "g++ is already installed."
  fi

  if ! command_exists make; then
    echo "make not found. Ensuring build-essential covers it or adding explicitly."
    # pkgs_to_install_apt+=("make") # Usually covered by build-essential
  else
    echo "make is already installed."
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


  # Attempt to install packages using apt
  if command_exists apt; then
    # Remove duplicates just in case, though shell array appends won't duplicate strings
    local unique_pkgs_to_install_apt
    unique_pkgs_to_install_apt=($(echo "${pkgs_to_install_apt[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    if [ ${#unique_pkgs_to_install_apt[@]} -gt 0 ]; then
      echo "Attempting to install system packages via apt: ${unique_pkgs_to_install_apt[*]}"
      sudo apt update
      sudo apt install -y "${unique_pkgs_to_install_apt[@]}"

      if command_exists fdfind && ! command_exists fd; then
        echo "Command 'fdfind' found but 'fd' is not. Creating symlink /usr/bin/fd -> fdfind."
        if [ -w /usr/bin ]; then
            ln -s "$(command -v fdfind)" /usr/bin/fd
        elif [ -w /usr/local/bin ]; then
            echo "Attempting to create symlink in /usr/local/bin as /usr/bin is not writable without sudo for link."
            sudo ln -s "$(command -v fdfind)" /usr/local/bin/fd
        else
            echo "Could not create symlink for fd automatically. You might need to do it manually: sudo ln -s \$(command -v fdfind) /usr/local/bin/fd"
        fi
      fi
    else
      echo "Required system packages appear to be already installed or not requested for apt installation."
    fi
  else
    if [ ${#pkgs_to_install_apt[@]} -gt 0 ]; then # Check original list as unique might be empty if all existed
      echo "apt package manager not found, but some system packages were requested. Please install manually: ${pkgs_to_install_apt[*]}"
    fi
  fi

  # --- Oh My Posh (via curl) ---
  if ! command_exists oh-my-posh; then
    echo "Installing Oh My Posh using curl..."
    if command_exists curl; then
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
      echo "curl is required to install Oh My Posh automatically. Please ensure curl is installed (e.g., via apt)."
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
      echo "curl is required to install Zoxide automatically. Please ensure curl is installed."
    fi
  else
    echo "Zoxide is already installed."
  fi

  # --- fzf (fuzzy finder - via git clone and install script) ---
  if ! command_exists fzf; then
    echo "Installing fzf..."
    if command_exists git; then
      if [ ! -d "$HOME/.fzf" ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --all
        echo "fzf installed."
        echo "IMPORTANT: fzf's install script likely updated your active shell config. Since you symlink .zshrc, ensure the necessary fzf lines are in $HOME/dotfiles/.zshrc."
      else
        echo "$HOME/.fzf directory already exists. Ensuring fzf is set up..."
        "$HOME/.fzf/install" --all
      fi
    else
      echo "git is required to install fzf using the standard method. Please ensure git is installed."
    fi
  else
    echo "fzf is already installed."
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
declare -A symlinks
symlinks=(
  ["$DOTFILES_DIR/.zshrc"]="$HOME/.zshrc"
  ["$DOTFILES_DIR/nvim"]="$config_folder/nvim"
  ["$DOTFILES_DIR/.ssh/config"]="$ssh_folder/config"
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
    backup_name="${target}.bak_$(date +%F-%T)" # Appended timestamp
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
echo "3. C/C++ build tools (build-essential, gcc, g++, make, gdb, clang) should now be installed if they weren't already."
echo "4. Restart your shell or source your .zshrc for changes to take effect."
echo "---------------------------------------------------------------------"
