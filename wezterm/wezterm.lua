local wezterm = require 'wezterm'
return {
	adjust_window_size_when_changing_font_size = false,
	color_scheme = 'Darkside',
	enable_tab_bar = true,
	font_size = 12.0,
	font = wezterm.font('JetBrains Mono'),
	window_background_opacity = 0.95,
	window_decorations = 'RESIZE',
	keys = {
		{
			key = 'q',
			mods = 'CTRL',
			action = wezterm.action.ToggleFullScreen,
		},
		{
			key = '\'',
			mods = 'CTRL',
			action = wezterm.action.ClearScrollback 'ScrollbackAndViewport',
		},
	},
	mouse_bindings = {
	  {
	    event = { Up = { streak = 1, button = 'Left' } },
	    mods = 'CTRL',
	    action = wezterm.action.OpenLinkAtMouseCursor,
	  },
	  {
	    event = { Down = { streak = 1, button = 'Right' } },
	    mods = 'NONE',
	    action = wezterm.action.PasteFrom 'Clipboard',
	  },
	},
}
