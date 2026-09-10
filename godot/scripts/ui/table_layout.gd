class_name TableLayout
extends RefCounted
## Where the table's panels go, and how big the things you touch are.
##
## The screen is authored in design pixels and the whole design is letterboxed
## into the window, so a design pixel is worth `window height / design height`
## real pixels. A phone gives that fraction a small numerator: at 1280x720 on a
## 390 px tall screen every control shrinks to 54% and the buttons land near
## 21 px, well under the 44 px a finger needs.
##
## So the design height itself shrinks on short screens (see `design_height`).
## Fewer design pixels for the same content means each one is worth more real
## pixels, and the layout switches to `compact`, which spends that smaller
## budget on bigger controls and a narrower side panel instead of on whitespace.
##
## Everything here is pure arithmetic on a viewport size so it can be tested
## without a window; TableScreen just applies the result.

## Design heights. WIDE is the size the table was drawn at and must not move —
## every desktop window keeps rendering exactly as before.
const WIDE_HEIGHT := 720.0
const COMPACT_HEIGHT := 420.0

## Real window height below which we switch to the compact design height. A
## laptop at 768 px stays wide; a phone in landscape (~390 px) goes compact.
const SMALL_WINDOW_HEIGHT := 600.0

## Design width below which the panels reflow. With a compact design height a
## 16:9 window lands near 750 design px wide, well under this.
const COMPACT_MAX_WIDTH := 1100.0

## The touch target we aim for on small screens.
const MIN_TOUCH_PX := 44.0


## Design height to render at for a given real window height. Returning a
## smaller number makes every design pixel worth more real pixels.
static func design_height(window_height: float) -> float:
	if window_height <= 0.0:
		return WIDE_HEIGHT
	if window_height < SMALL_WINDOW_HEIGHT:
		return COMPACT_HEIGHT
	return WIDE_HEIGHT


## How many real pixels one design pixel is worth, given the chosen design height.
static func scale_for(window_height: float) -> float:
	var dh := design_height(window_height)
	if dh <= 0.0:
		return 1.0
	return window_height / dh


## Width alone is not enough: the wide layout also needs the full design height.
## A short, very wide window (1600x500, which maps to a 1344x420 viewport) would
## otherwise pick wide and compute a felt with negative height.
static func is_compact(viewport: Vector2) -> bool:
	return viewport.x < COMPACT_MAX_WIDTH or viewport.y < WIDE_HEIGHT


## Full layout for a viewport measured in design pixels.
static func compute(viewport: Vector2) -> Dictionary:
	return _compact(viewport) if is_compact(viewport) else _wide(viewport)


static func _wide(v: Vector2) -> Dictionary:
	var w := v.x
	var h := v.y
	var m := 16.0
	var side_w := 316.0
	var gap := 12.0
	var table_w := w - m * 2.0 - side_w - gap
	var player_h := 256.0
	var player_y := h - 10.0 - player_h
	var felt_y := 196.0
	var felt_h := player_y - 8.0 - felt_y
	return {
		"compact": false,
		"top": Rect2(m, 8.0, w - m * 2.0, 40.0),
		"dealer": Rect2(m, 56.0, table_w, 132.0),
		"felt": Rect2(m, felt_y, table_w, felt_h),
		"side": Rect2(w - m - side_w, 56.0, side_w, h - 66.0),
		"player": Rect2(m, player_y, table_w, player_h),
		"timer": Vector2(m + table_w - 14.0 - 60.0, felt_y + 14.0),
		"timer_size": 56.0,
		"card": Vector2(78.0, 110.0),
		"small_card": Vector2(50.0, 70.0),
		"rank_card": Vector2(90.0, 128.0),
		"portrait": Vector2(96.0, 106.0),
		"item_min": Vector2(210.0, 44.0),
		"hand_gap": 10.0,
		"hand_top": 16.0,
		"action_font": 17,
		"action_pad": 10,
		"small_font": 12,
		"small_pad": 5,
		"panel_margin": 12,
		"row_separation": 6,
		"log_visible": true,
		"dealer_name_font": 22,
		"actions_horizontal": false,
		"margin": 16.0,
		"side_width": side_w,
	}


static func _compact(v: Vector2) -> Dictionary:
	## Compact does not place panels by hand. At this design height the content
	## barely fits, and a fixed band that is one label too short would silently
	## overlap the next panel — a Control cannot shrink below its content. So the
	## panels go into containers (see TableScreen._set_mode) and this only says
	## how big the pieces are. Sizes are chosen so the things you touch clear
	## MIN_TOUCH_PX once the design height is applied.
	var side_w := clampf(v.x * 0.24, 150.0, 240.0)
	return {
		"compact": true,
		"margin": 8.0,
		"side_width": side_w,
		"timer_size": 44.0,
		"card": Vector2(58.0, 80.0),
		"small_card": Vector2(34.0, 47.0),
		"rank_card": Vector2(44.0, 62.0),
		"portrait": Vector2(58.0, 64.0),
		"item_min": Vector2(96.0, 48.0),
		"hand_gap": 8.0,
		"hand_top": 6.0,
		"action_font": 15,
		"action_pad": 13,
		"actions_horizontal": true,
		"small_font": 13,
		"small_pad": 14,
		"panel_margin": 8,
		"row_separation": 4,
		"log_visible": false,
		"dealer_name_font": 17,
	}

