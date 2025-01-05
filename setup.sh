#!/bin/zsh

# List of files to check

config_folder="$HOME/.config"

# Check if the folder exists
if [ ! -d "$config_folder" ]; then
  # If it doesn't exist, create the folder
  mkdir -p "$config_folder"
  mkdir -p "$config_folder/tmux"
  mkdir -p "$config_folder/ohmyposh"
  echo "Folder created: $config_folder"
else
  echo "Folder already exists: $config_folder, removing and recreating"
  rm -rf "$config_folder"
  mkdir -p "$config_folder"
  mkdir -p "$config_folder/tmux"
  mkdir -p "$config_folder/ohmyposh"
fi


files=("$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.config/tmux/tmux.conf" "$HOME/.config/ohmyposh/catppuccin.omp.json")

# Loop through each file
for file in "${files[@]}"; do
  # Check if the file exists
  if [ ! -f "$file" ]; then
    echo "$file doesn't exist, creating alias"
  else
    echo "File already exists: $file, removing for alias creation"
    rm "$file"
  fi
done

ln -s $HOME/dotfiles/.zshrc $HOME/.zshrc
# ln -s $HOME/dotfiles/.vimrc $HOME/.vimrc
ln -s $HOME/dotfiles/.gitconfig $HOME/.gitconfig
ln -s $HOME/dotfiles/tmux/tmux.conf $HOME/.config/tmux/tmux.conf
ln -s $HOME/dotfiles/ohmyposh/catppuccin.omp.json $HOME/.config/ohmyposh/catppuccin.omp.json
