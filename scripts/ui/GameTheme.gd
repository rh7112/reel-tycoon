class_name GameTheme
extends RefCounted

## Builds the game's shared Theme in code rather than as a hand-authored
## .tres -- Theme resources have a lot of exact-string property-name
## surface area (e.g. "Button/styles/normal") that's easy to get subtly
## wrong with no engine here to catch it; constructing it via Theme's
## own typed API is safer. Applied once, at the FishingScene root
## (FishingHUD._ready), so every Control -- including everything the
## menu tabs build dynamically in code -- inherits it automatically.
## This is *the* fix for "the menu's transparency makes it hard to
## read": that was the default Panel style with no explicit override,
## not a deliberate choice.

const BG_PANEL: Color = Color(0.13, 0.17, 0.22, 0.98)
const ACCENT: Color = Color(0.88, 0.66, 0.29, 1.0)
const ACCENT_DIM: Color = Color(0.55, 0.42, 0.22, 1.0)
const BUTTON_NORMAL: Color = Color(0.17, 0.31, 0.35, 1.0)
const BUTTON_HOVER: Color = Color(0.23, 0.41, 0.46, 1.0)
const BUTTON_DISABLED: Color = Color(0.26, 0.28, 0.31, 1.0)
const TEXT_MAIN: Color = Color(0.95, 0.93, 0.87, 1.0)
const TEXT_DIM: Color = Color(0.68, 0.72, 0.75, 1.0)
const TEXT_ON_ACCENT: Color = Color(0.15, 0.1, 0.02, 1.0)

static func build() -> Theme:
	var theme := Theme.new()

	theme.set_color("font_color", "Label", TEXT_MAIN)
	theme.set_font_size("font_size", "Label", 22)

	theme.set_stylebox("normal", "Button", _button_style(BUTTON_NORMAL, ACCENT_DIM))
	theme.set_stylebox("hover", "Button", _button_style(BUTTON_HOVER, ACCENT))
	theme.set_stylebox("pressed", "Button", _button_style(ACCENT, ACCENT))
	theme.set_stylebox("disabled", "Button", _button_style(BUTTON_DISABLED, Color(0.35, 0.36, 0.38, 1.0)))
	theme.set_stylebox("focus", "Button", _button_style(BUTTON_HOVER, ACCENT))
	theme.set_color("font_color", "Button", TEXT_MAIN)
	theme.set_color("font_color_hover", "Button", TEXT_MAIN)
	theme.set_color("font_color_pressed", "Button", TEXT_ON_ACCENT)
	theme.set_color("font_color_disabled", "Button", TEXT_DIM)
	theme.set_font_size("font_size", "Button", 22)

	theme.set_stylebox("panel", "Panel", _panel_style())

	var separator := StyleBoxFlat.new()
	separator.bg_color = ACCENT_DIM
	separator.content_margin_top = 1.0
	separator.content_margin_bottom = 1.0
	theme.set_stylebox("separator", "HSeparator", separator)

	return theme

static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_PANEL
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = ACCENT
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_size = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	return style
