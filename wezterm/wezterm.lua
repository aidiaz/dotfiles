-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = "Catppuccin Mocha"
config.font_size = 14
config.font = wezterm.font("JetBrains Mono Regular")
config.enable_tab_bar = false
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.95
config.macos_window_background_blur = 10
-- and finally, return the configuration to wezterm
return config
