extends CanvasLayer

# ─────────────────────────────────────────
#  STEALTH DEBUG OVERLAY
#  Attach to the DebugOverlay CanvasLayer.
#  Reads all stealth system values live
#  and displays them in DebugLabel.
# ─────────────────────────────────────────

@onready var _label: Label = $DebugLabel

# Auto-found via groups in _ready()
var _stealth:   StealthComponent           = null
var _guard_awr: AwarenessComponent         = null
var _guard_asm: AlertStateMachineComponent = null
var _ceiling:   ThreatCeilingComponent     = null


# ─────────────────────────────────────────
#  GODOT CALLBACKS
# ─────────────────────────────────────────

func _ready() -> void:
	# Find player stealth component
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_stealth = players[0].get_node_or_null("Components/stealth_component")
		if _stealth == null:
			push_warning("DebugOverlay: stealth_component not found on player.")

	# Find first guard's components
	var guards := get_tree().get_nodes_in_group("guard")
	if guards.size() > 0:
		var guard := guards[0]
		_guard_awr = guard.get_node_or_null("awareness_component")
		_guard_asm = guard.get_node_or_null("alert_state_machine_component")
		if _guard_awr == null:
			push_warning("DebugOverlay: awareness_component not found on guard.")
		if _guard_asm == null:
			push_warning("DebugOverlay: alert_state_machine_component not found on guard.")

	# Find district ceiling
	var districts := get_tree().get_nodes_in_group("district")
	if districts.size() > 0:
		_ceiling = districts[0].get_node_or_null("threat_ceiling_component")
		if _ceiling == null:
			push_warning("DebugOverlay: threat_ceiling_component not found on district.")


func _process(_delta: float) -> void:
	if _label == null:
		return
	_label.text = _build_debug_text()


# ─────────────────────────────────────────
#  DEBUG TEXT BUILDER
# ─────────────────────────────────────────

func _build_debug_text() -> String:
	var lines: PackedStringArray = []

	lines.append("── STEALTH DEBUG ──────────────────")

	# ── Player stealth values ─────────────
	lines.append("")
	lines.append("[ PLAYER STEALTH VALUES ]")

	if _stealth != null:
		lines.append("  Light  raw:        %.2f" % _stealth.light_exposure)
		lines.append("  Sound  raw:        %.2f" % _stealth.sound_output)
		lines.append("  Motion raw:        %.2f" % _stealth.movement_speed)
		lines.append("  ───────────────────────")
		lines.append("  Light  effective:  %.2f" % _stealth.effective_light)
		lines.append("  Sound  effective:  %.2f" % _stealth.effective_sound)
		lines.append("  Motion effective:  %.2f" % _stealth.effective_motion)
		lines.append("  Active modifiers:  %d"   % _stealth._active_modifiers.size())
	else:
		lines.append("  ! stealth_component not found")
		lines.append("  ! Is player in the 'player' group?")

	# ── Guard awareness ───────────────────
	lines.append("")
	lines.append("[ GUARD AWARENESS ]")

	if _guard_awr != null:
		var pct     := _guard_awr.current_awareness * 100.0
		var thr_pct := _guard_awr.get_threshold() * 100.0
		var bar     := _awareness_bar(_guard_awr.current_awareness)

		lines.append("  %s  %.0f%%" % [bar, pct])
		lines.append("  Threshold:      %.2f  (%.0f%%)" % [_guard_awr.get_threshold(), thr_pct])
		lines.append("  Line of sight:  %s" % ("YES" if _guard_awr.has_line_of_sight else "NO"))
		lines.append("  In range:       %s" % ("YES" if _guard_awr.player_in_range else "NO"))
	else:
		lines.append("  ! awareness_component not found")
		lines.append("  ! Is guard in the 'guard' group?")

	# ── Alert state machine ───────────────
	lines.append("")
	lines.append("[ GUARD ALERT STATE ]")

	if _guard_asm != null:
		var state_idx:  int    = _guard_asm.current_state
		var state_name: String = AlertStateMachineComponent.AlertState.keys()[state_idx]
		var icon:       String = _state_icon(state_idx)

		lines.append("  State:          %s %s" % [icon, state_name])
		lines.append("  Stealth viable: %s" % ("YES" if _guard_asm.is_stealth_possible() else "NO"))
		lines.append("  Hunting:        %s" % ("YES" if _guard_asm.is_hunting() else "NO"))

		if _guard_asm._decay_active:
			lines.append("  Decay timer:    %.1f s remaining" % _guard_asm._decay_timer)
		else:
			lines.append("  Decay timer:    inactive")

		if _guard_asm.current_state == AlertStateMachineComponent.AlertState.FULL_ALERT:
			lines.append("  Full alert clr: %.1f / 30.0 s" % _guard_asm._full_alert_clear_timer)

		if _guard_asm.last_known_position != Vector3.ZERO:
			var lkp := _guard_asm.last_known_position.snapped(Vector3.ONE * 0.1)
			lines.append("  Last known pos: %s" % str(lkp))
		else:
			lines.append("  Last known pos: none")
	else:
		lines.append("  ! alert_state_machine_component not found")

	# ── Threat ceiling ────────────────────
	lines.append("")
	lines.append("[ THREAT CEILING ]")

	if _ceiling != null:
		var frozen_str := "YES — %.1f s left" % _ceiling._freeze_timer \
			if _ceiling.is_frozen() else "NO"
		lines.append("  District:   %s" % _ceiling.district_name)
		lines.append("  Frozen:     %s" % frozen_str)
		lines.append("  ───────────────────────")

		for tactic in ThreatCeilingComponent.TacticType.values():
			var tactic_name: String = ThreatCeilingComponent.TacticType.keys()[tactic]
			var count:       int    = _ceiling.get_count(tactic)
			var threshold:   int    = ThreatCeilingComponent.THRESHOLDS[tactic]
			var state_idx:   int    = _ceiling._adaptation_states[tactic]
			var state_str:   String = ThreatCeilingComponent.AdaptationState.keys()[state_idx]
			var timer:       float  = _ceiling.get_telegraph_remaining(tactic)
			var timer_str:   String = "  (%.0f s)" % timer if timer > 0.0 else ""

			lines.append("  %-20s %d / %d   [%s]%s" % [
				tactic_name, count, threshold, state_str, timer_str
			])
	else:
		lines.append("  ! threat_ceiling_component not found")
		lines.append("  ! Is district in the 'district' group?")

	# ── Controls ──────────────────────────
	lines.append("")
	lines.append("[ DEBUG CONTROLS ]")
	lines.append("  F1  Force body found on guard")
	lines.append("  F2  Register grapple tactic  (%d/3)" % \
		(_ceiling.get_count(ThreatCeilingComponent.TacticType.GRAPPLE_ENTRY) \
		if _ceiling else 0))
	lines.append("  F3  Register EMP tactic      (%d/2)" % \
		(_ceiling.get_count(ThreatCeilingComponent.TacticType.EMP_USE) \
		if _ceiling else 0))
	lines.append("  F4  Register aerial tactic   (%d/2)" % \
		(_ceiling.get_count(ThreatCeilingComponent.TacticType.AERIAL_TAKEDOWN) \
		if _ceiling else 0))
	lines.append("  F5  Neutralise tactician (freeze 90s)")
	lines.append("")
	lines.append("───────────────────────────────────")

	return "\n".join(lines)


# ─────────────────────────────────────────
#  TEST INPUT SHORTCUTS
# ─────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_page_up"):      # F1
		if _guard_asm != null:
			_guard_asm.report_body_found()
			print("[Debug] Body found triggered on guard")

	elif event.is_action_pressed("ui_page_down"):  # F2
		if _ceiling != null:
			_ceiling.register_tactic(ThreatCeilingComponent.TacticType.GRAPPLE_ENTRY)
			print("[Debug] Grapple tactic registered")

	elif event.is_action_pressed("ui_home"):       # F3
		if _ceiling != null:
			_ceiling.register_tactic(ThreatCeilingComponent.TacticType.EMP_USE)
			print("[Debug] EMP tactic registered")

	elif event.is_action_pressed("ui_end"):        # F4
		if _ceiling != null:
			_ceiling.register_tactic(ThreatCeilingComponent.TacticType.AERIAL_TAKEDOWN)
			print("[Debug] Aerial tactic registered")

	elif event.is_action_pressed("ui_select"):     # F5
		if _ceiling != null:
			_ceiling.neutralise_tactician()
			print("[Debug] Tactician neutralised — ceiling frozen 90s")


# ─────────────────────────────────────────
#  DISPLAY HELPERS
# ─────────────────────────────────────────

func _awareness_bar(value: float) -> String:
	var filled := int(value * 20.0)
	var empty  := 20 - filled
	return "[" + "█".repeat(filled) + "░".repeat(empty) + "]"


func _state_icon(state: AlertStateMachineComponent.AlertState) -> String:
	match state:
		AlertStateMachineComponent.AlertState.UNAWARE:
			return "●"
		AlertStateMachineComponent.AlertState.SUSPICIOUS:
			return "◐"
		AlertStateMachineComponent.AlertState.ALERTED:
			return "◕"
		AlertStateMachineComponent.AlertState.FULL_ALERT:
			return "◉"
		AlertStateMachineComponent.AlertState.WRAITH_PROTOCOL:
			return "✦"
	return "?"
