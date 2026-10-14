extends Node
## Ads and the one-time "Remove ads" purchase. Autoloaded as `Monetization`.
##
## Backends:
## - android: the CozyServices plugin (AdMob ads, Google consent, Play Billing).
## - mock: debug builds without the plugin (editor, desktop, tests). Fake ads
##   and a fake store so every flow can be tried; `instant` skips their UI.
## - none: release builds without the plugin (web, iOS): no ads, no store.
##
## Placements: an interstitial between days (never after "Remove ads") and
## two opt-in rewarded ads (double the day's coins, free coins in the shop).

## Ad readiness, price, consent or purchase state changed: refresh the UI.
signal status_changed
signal premium_changed
## A purchase or restore the player started has finished.
signal purchase_finished(ok: bool, message: String)
## A mock ad or store card was closed (true: watched / bought).
signal _mock_closed(result: bool)

enum Backend { NONE, MOCK, ANDROID }

const INTERSTITIAL := "interstitial"
const REWARDED := "rewarded"
## Google's sample ad units, always used by debug builds.
const TEST_UNITS := {
	INTERSTITIAL: "ca-app-pub-3940256099942544/1033173712",
	REWARDED: "ca-app-pub-3940256099942544/5224354917",
}
## Interstitials start on this day, come at most every DAYS_BETWEEN_ADS days
## and never within AD_COOLDOWN_MSEC of the last full-screen ad (or launch).
const FIRST_AD_DAY := 4
const DAYS_BETWEEN_ADS := 2
const AD_COOLDOWN_MSEC := 180000
## How long to wait for an ad to appear before giving up.
const SHOW_TIMEOUT_MSEC := 10000
const MOCK_PRICE := "$2.99"

var backend := Backend.NONE
## Mock backend: finish ads and purchases at once, without UI (tests).
var instant := false
## Formatted price of "Remove ads" ("" until the store answers).
var price := ""
var purchase_pending := false
## An ad (or the mock store) is on screen.
var busy := false

var _plugin: Object
var _product_id := "remove_ads"
var _privacy_required := false
var _last_ad_day := 0
var _last_fullscreen_msec := 0
var _ad_state := {}
var _user_purchase := false
var _mock_layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_product_id = str(ProjectSettings.get_setting("cozy_services/store/remove_ads_product_id", "remove_ads"))
	_last_fullscreen_msec = Time.get_ticks_msec()
	if Engine.has_singleton("CozyServices"):
		backend = Backend.ANDROID
		_plugin = Engine.get_singleton("CozyServices")
		_connect_plugin()
		_plugin.startBilling(_product_id)
		_plugin.startAds(_unit(INTERSTITIAL), _unit(REWARDED), bool(ProjectSettings.get_setting("cozy_services/admob/child_directed", false)))
	elif OS.is_debug_build():
		backend = Backend.MOCK
		price = MOCK_PRICE


func _unit(kind: String) -> String:
	if OS.is_debug_build():
		return TEST_UNITS[kind]
	return str(ProjectSettings.get_setting("cozy_services/admob/android_%s_unit" % kind, TEST_UNITS[kind]))


func _connect_plugin() -> void:
	for pair in [
		["consent_finished", _on_consent_finished],
		["ad_loaded", _on_ad_loaded],
		["ad_load_failed", _on_ad_load_failed],
		["ad_shown", _on_ad_shown],
		["ad_closed", _finish_ad],
		["ad_show_failed", _on_ad_show_failed],
		["privacy_options_closed", _on_privacy_options_closed],
		["billing_ready", _on_billing_ready],
		["product_price", _on_product_price],
		["purchase_succeeded", _on_purchase_succeeded],
		["purchase_pending", _on_purchase_pending],
		["purchase_failed", _on_purchase_failed],
		["restore_finished", _on_restore_finished],
	]:
		_plugin.connect(pair[0], pair[1])


func _on_consent_finished(_can_request: bool, privacy_required: bool) -> void:
	_privacy_required = privacy_required
	status_changed.emit()


func _on_ad_loaded(_kind: String) -> void:
	status_changed.emit()


func _on_ad_load_failed(kind: String, message: String) -> void:
	print_verbose("Ad %s failed to load: %s" % [kind, message])


func _on_ad_shown(kind: String) -> void:
	if _ad_state.get("kind") == kind:
		_ad_state["shown"] = true


func _on_ad_show_failed(kind: String, message: String) -> void:
	push_warning("Ad %s failed to show: %s" % [kind, message])
	_finish_ad(kind, false)


func _on_privacy_options_closed(_error: String) -> void:
	_privacy_required = _plugin.isPrivacyOptionsRequired()
	status_changed.emit()


func _on_billing_ready(ok: bool, message: String) -> void:
	if not ok:
		push_warning("Billing unavailable: " + message)


func _on_product_price(id: String, formatted: String) -> void:
	if id == _product_id:
		price = formatted
		status_changed.emit()


func _on_purchase_succeeded(id: String, restored: bool) -> void:
	if id == _product_id:
		_grant(restored)


func _on_purchase_pending(id: String) -> void:
	if id != _product_id:
		return
	purchase_pending = true
	status_changed.emit()
	if _user_purchase:
		_user_purchase = false
		purchase_finished.emit(false, "Payment pending. Ads go away once it's done.")


func _on_purchase_failed(_id: String, message: String, _canceled: bool) -> void:
	_user_purchase = false
	purchase_finished.emit(false, message)


func _on_restore_finished(ok: bool, count: int) -> void:
	if not ok:
		purchase_finished.emit(false, "Google Play can't be reached right now.")
	elif count == 0:
		purchase_finished.emit(false, "No purchases to restore.")


# -- queries ---------------------------------------------------------------------

func has_ads() -> bool:
	return backend != Backend.NONE


func has_store() -> bool:
	return backend != Backend.NONE


func is_premium() -> bool:
	return GameState.premium


func price_text() -> String:
	return price if price != "" else "Buy"


func rewarded_ready() -> bool:
	if busy:
		return false
	match backend:
		Backend.MOCK:
			return true
		Backend.ANDROID:
			return _plugin.isAdReady(REWARDED)
	return false


func interstitial_due() -> bool:
	if GameState.premium or busy or backend == Backend.NONE:
		return false
	if GameState.day < FIRST_AD_DAY or GameState.day - _last_ad_day < DAYS_BETWEEN_ADS:
		return false
	if Time.get_ticks_msec() - _last_fullscreen_msec < AD_COOLDOWN_MSEC:
		return false
	return backend == Backend.MOCK or _plugin.isAdReady(INTERSTITIAL)


func privacy_options_required() -> bool:
	return backend == Backend.ANDROID and _privacy_required


# -- ads ---------------------------------------------------------------------------

## Shows an interstitial if one is due (await it before moving on).
func maybe_show_interstitial() -> void:
	if not interstitial_due():
		return
	_last_ad_day = GameState.day
	await _show(INTERSTITIAL)


## Shows a rewarded ad. Returns true when the player earned the reward.
func show_rewarded() -> bool:
	if not rewarded_ready():
		return false
	return await _show(REWARDED)


func _show(kind: String) -> bool:
	busy = true
	status_changed.emit()
	var rewarded := false
	if backend == Backend.MOCK:
		rewarded = await _mock_ad(kind)
	else:
		_ad_state = {"kind": kind, "shown": false, "done": false, "rewarded": false}
		_plugin.showAd(kind)
		var start := Time.get_ticks_msec()
		while not _ad_state["done"]:
			await get_tree().process_frame
			if not _ad_state["shown"] and Time.get_ticks_msec() - start > SHOW_TIMEOUT_MSEC:
				push_warning("Ad %s never showed" % kind)
				break
		rewarded = _ad_state["rewarded"]
		_ad_state = {}
	_last_fullscreen_msec = Time.get_ticks_msec()
	busy = false
	status_changed.emit()
	return rewarded and kind == REWARDED


func _finish_ad(kind: String, rewarded: bool) -> void:
	if _ad_state.get("kind") == kind:
		_ad_state["done"] = true
		_ad_state["rewarded"] = rewarded


# -- store -----------------------------------------------------------------------------

func buy_remove_ads() -> void:
	if GameState.premium or busy:
		return
	match backend:
		Backend.ANDROID:
			_user_purchase = true
			_plugin.purchase(_product_id)
		Backend.MOCK:
			busy = true
			var ok := true
			if not instant:
				ok = await _mock_store()
			busy = false
			if ok:
				_grant(false)
			else:
				purchase_finished.emit(false, "Purchase canceled.")


func restore_purchases() -> void:
	match backend:
		Backend.ANDROID:
			_plugin.restorePurchases()
		Backend.MOCK:
			purchase_finished.emit(false, "Test store: nothing to restore.")


func show_privacy_options() -> void:
	if backend == Backend.ANDROID:
		_plugin.showPrivacyOptions()


func _grant(restored: bool) -> void:
	purchase_pending = false
	_user_purchase = false
	if GameState.premium:
		status_changed.emit()
		return
	var gift := GameState.set_premium(true)
	premium_changed.emit()
	status_changed.emit()
	var thanks := "Purchase restored. Thank you!" if restored else "Thank you! Ads are gone for good."
	if gift > 0:
		thanks += " +%d coins" % gift
	purchase_finished.emit(true, thanks)


# -- mock UI ------------------------------------------------------------------------------

func _mock_ad(kind: String) -> bool:
	if instant:
		return kind == REWARDED
	var rewarded := kind == REWARDED
	var card := _mock_card("Test ad")
	var col: VBoxContainer = card.get_child(0)
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", CozyTheme.box(Color("fde6ea"), 26, 18))
	screen.custom_minimum_size = Vector2(480, 260)
	var count := _mock_label("3", 96)
	count.add_theme_color_override("font_color", CozyTheme.TOMATO)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screen.add_child(count)
	col.add_child(screen)
	var note := "Watch to the end for your reward." if rewarded else "A short break between days."
	col.add_child(_mock_label(note + " Android builds show a real Google ad here.", 22, "Body"))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	if rewarded:
		var skip := Button.new()
		skip.theme_type_variation = "SoftButton"
		skip.text = "Skip"
		skip.pressed.connect(func(): _mock_closed.emit(false))
		buttons.add_child(skip)
	var close := Button.new()
	close.text = "Collect reward" if rewarded else "Close"
	close.disabled = true
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func(): _mock_closed.emit(true))
	buttons.add_child(close)
	_mock_countdown(count, close)
	var result: bool = await _mock_closed
	_close_mock()
	return result and rewarded


func _mock_countdown(count: Label, close: Button) -> void:
	for i in [3, 2, 1]:
		if not is_instance_valid(count):
			return
		count.text = str(i)
		await get_tree().create_timer(1.0, true, false, true).timeout
	if is_instance_valid(close):
		count.text = "Done!"
		close.disabled = false


func _mock_store() -> bool:
	var card := _mock_card("Test store")
	var col: VBoxContainer = card.get_child(0)
	var row := PanelContainer.new()
	row.theme_type_variation = "Row"
	var h := HBoxContainer.new()
	row.add_child(h)
	var title := _mock_label("Remove ads", 30)
	title.custom_minimum_size = Vector2.ZERO
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h.add_child(title)
	var cost := _mock_label(MOCK_PRICE, 30)
	cost.custom_minimum_size = Vector2.ZERO
	cost.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(cost)
	col.add_child(row)
	col.add_child(_mock_label("Debug build: no money changes hands. Android builds open Google Play here.", 22, "Body"))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var cancel := Button.new()
	cancel.theme_type_variation = "SoftButton"
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): _mock_closed.emit(false))
	buttons.add_child(cancel)
	var buy := Button.new()
	buy.theme_type_variation = "BuyButton"
	buy.text = "Buy"
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(func(): _mock_closed.emit(true))
	buttons.add_child(buy)
	var result: bool = await _mock_closed
	_close_mock()
	return result


func _mock_card(heading: String) -> PanelContainer:
	_close_mock()
	_mock_layer = CanvasLayer.new()
	_mock_layer.layer = 50
	add_child(_mock_layer)
	var root := Control.new()
	root.theme = CozyTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mock_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.18, 0.13, 0.12, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	col.add_child(_mock_label(heading, 44))
	return card


func _mock_label(text: String, size: int, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	return l


func _close_mock() -> void:
	if _mock_layer:
		_mock_layer.queue_free()
		_mock_layer = null
