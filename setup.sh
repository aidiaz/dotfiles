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
  # Note: 'sshd' is the daemon for openssh-server. 'ssh' command is from openssh-client.
  if ! command_exists sshd; then
    echo "openssh-server (sshd) not found. Adding to apt installation list."
    pkgs_to_install_apt+=("openssh-server")
  else
    echo "openssh-server (sshd) appears to be installed."
  fi

  # Attempt to install packages using apt
  if command_exists apt; then
    if [ ${#pkgs_to_install_apt[@]} -gt 0 ]; then
      echo "Attempting to install system packages via apt: ${pkgs_to_install_apt[*]}"
      sudo apt update
      sudo apt install -y "${pkgs_to_install_apt[@]}"
    else
      echo "Required system packages (git, curl, openssh-server) appear to be already installed or not requested for apt installation."
    fi
  else
    if [ ${#pkgs_to_install_apt[@]} -gt 0 ]; then
      echo "apt package manager not found, but some system packages were requested. Please install manually: ${pkgs_to_install_apt[*]}"
    fi
  fi

  # --- Oh My Posh (via curl) ---
  if ! command_exists oh-my-posh; then
    echo "Installing Oh My Posh using curl..."
    if command_exists curl; then
      # Determine architecture for Oh My Posh download
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
  # fzf's primary installation method involves git cloning.
  if ! command_exists fzf; then
    echo "Installing fzf..."
    if command_exists git; then
      if [ ! -d "$HOME/.fzf" ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --all # Use --all for non-interactive setup (key-bindings, completion)
        echo "fzf installed."
        echo "IMPORTANT: fzf's install script likely updated your active shell config. Since you symlink .zshrc, ensure the necessary fzf lines are in $HOME/dotfiles/.zshrc."
      else
        echo "$HOME/.fzf directory already exists. Ensuring fzf is set up..."
        # Re-running install can be useful if shell configs were missed or need refresh
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

# Define the source directory for your dotfiles
DOTFILES_DIR="$HOME/dotfiles" # Assuming your dotfiles repo is cloned to $HOME/dotfiles

# Define target directories
config_folder="$HOME/.config"
ssh_folder="$HOME/.ssh"

# --- Configuration Directory Setup ---
echo "Setting up $config_folder..."
mkdir -p "$config_folder" # Ensure base .config directory exists

# Specific subdirectories that will contain symlinked files or are symlinks themselves
# Ensure parent directories for these are created before symlinking
config_targets_to_ensure_parents_for=(
    "$config_folder/tmux/tmux.conf"
    "$config_folder/ohmyposh/catppuccin.omp.json"
    "$config_folder/nvim" # nvim itself is a directory symlink
)

for target_path in "${config_targets_to_ensure_parents_for[@]}"; do
  mkdir -p "$(dirname "$target_path")"
done


# --- SSH Directory Setup ---
echo "Setting up $ssh_folder..."
if [ ! -d "$ssh_folder" ]; then
  mkdir -p "$ssh_folder"
  chmod 700 "$ssh_folder" # SSH directory requires strict permissions
  echo "Created $ssh_folder with 700 permissions."
else
  echo "$ssh_folder already exists. Verifying permissions..."
  chmod 700 "$ssh_folder" # Ensure correct permissions
fi

# --- Symlinking ---
echo "Creating symlinks..."

# Define files and directories to symlink as an associative array
# Format: "source_in_dotfiles_repo"="$HOME/target_location"
declare -A symlinks
symlinks=(
  ["$DOTFILES_DIR/.zshrc"]="$HOME/.zshrc"
  ["$DOTFILES_DIR/nvim"]="$config_folder/nvim" # nvim config is a directory
  ["$DOTFILES_DIR/.ssh/config"]="$ssh_folder/config"
  ["$DOTFILES_DIR/.gitconfig"]="$HOME/.gitconfig"
  ["$DOTFILES_DIR/tmux/tmux.conf"]="$config_folder/tmux/tmux.conf"
  ["$DOTFILES_DIR/ohmyposh/catppuccin.omp.json"]="$config_folder/ohmyposh/catppuccin.omp.json"
)

for source in "${(@k)symlinks}"; do
  target="${symlinks[$source]}"
  target_dir=$(dirname "$target") # Parent directory of the target symlink

  # Ensure the immediate parent directory for the symlink itself exists
  # This was partially covered above, but this is more direct for each link.
  if [ ! -d "$target_dir" ]; then
      mkdir -p "$target_dir"
      echo "Created directory for symlink target: $target_dir"
  fi

  # If target exists and is not a symlink, back it up
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    backup_name="${target}.bak_$(date +%F-%T)"
    echo "Backing up existing file/directory: $target to $backup_name"
    mv "$target" "$backup_name"
  fi

  # Remove existing symlink before creating a new one to avoid issues
  if [ -L "$target" ]; then
    echo "Removing existing symlink at $target"
    rm "$target"
  fi
  
  # Create the symlink
  # -n (--no-dereference) is important for directory symlinks if the target symlink itself exists
  # -f (--force) forces the link (e.g. overwrites if target is a file, but we backed up above)
  # -s for symbolic
  if [ -d "$source" ]; then # Check if source is a directory
    ln -sfn "$source" "$target"
    echo "Linked directory: $source -> $target"
  else # Source is a file
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
echo "                 Typically, this involves sourcing a file like '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh'."
echo "2. Restart your shell or source your .zshrc for changes to take effect."
echo "---------------------------------------------------------------------"
