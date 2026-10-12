extends Control

# Pool Club is a companion to Carrom. The colors, component spacing,
# shot rhythm and visual construction intentionally form a shared collection.
const PHYSICS := preload("res://scripts/pool_physics.gd")
const BOARD_SCRIPT := preload("res://scripts/pool_board.gd")
const BG := Color("#102320")
const PANEL := Color("#19322e")
const PANEL_ALT := Color("#213c36")
const TEXT := Color("#f7f0d9")
const MUTED := Color("#a7bbb1")
const MINT := Color("#7bdac2")
const GOLD := Color("#e8bf7e")
const INK := Color("#0b211e")
const MIN_SHOT_SPEED := 280.0
const MAX_SHOT_SPEED := 1425.0
const SETTINGS_PATH := "user://pool_club_settings.cfg"

var board: PoolBoard
var balls: Array = []
var cue_ball: Dictionary = {}
var phase := "aim"
var player_turn := 0
var group_for: Array[String] = ["", ""]
var winner := -1
var current_shot_pots: Array[int] = []
var first_contact := -1
var shot_time := 0.0
var charge_time := 0.0
var charge_power := 0.20
var aim_direction := Vector2.RIGHT
var cpu_time := 0.0
var cpu_queued: Dictionary = {}
var cpu_skill := 1
var status_head := "YOUR BREAK"
var status_text := "Move the mouse to aim. Hold left mouse to power up, then release."
var board_style_index := 0

var title_label: Label
var board_caption: Label
var tip_label: Label
var side_panel: PanelContainer
var round_label: Label
var board_style_label: Label
var prev_style_button: Button
var next_style_button: Button
var player_card_title: Label
var cpu_card_title: Label
var player_card_score: Label
var cpu_card_score: Label
var player_card_info: Label
var cpu_card_info: Label
var eight_text: Label
var turn_head: Label
var turn_desc: Label
var power_label: Label
var power_meter: ProgressBar
var cpu_selector: OptionButton
var rules_overlay: PanelContainer
var sound_shoot: AudioStreamPlayer
var sound_pocket: AudioStreamPlayer
var sound_click: AudioStreamPlayer
var stats_text: Label
var allow_eight_this_shot := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_load_style()
	board = BOARD_SCRIPT.new()
	add_child(board)
	board.set_style(board_style_index)
	_build_ui()
	_build_audio()
	_refresh_board_style()
	_new_game()
	_layout()
	queue_redraw()

func _notification(what:int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout()
		queue_redraw()

func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), BG, true)
	for n in range(int(sz.y / 30.0) + 2):
		var yy := float(n) * 30.0
		draw_line(Vector2(0,yy),Vector2(sz.x,yy),Color(1,1,1,.018),1.0)
	for n in range(int(sz.x / 30.0) + 2):
		var xx := float(n) * 30.0
		draw_line(Vector2(xx,0),Vector2(xx,sz.y),Color(1,1,1,.018),1.0)

func _build_audio() -> void:
	sound_shoot = AudioStreamPlayer.new()
	sound_shoot.stream = load("res://audio/strike.wav")
	sound_shoot.volume_db = -8.0
	add_child(sound_shoot)
	sound_pocket = AudioStreamPlayer.new()
	sound_pocket.stream = load("res://audio/pocket.wav")
	sound_pocket.volume_db = -6.0
	add_child(sound_pocket)
	sound_click = AudioStreamPlayer.new()
	sound_click.stream = load("res://audio/tick.wav")
	sound_click.volume_db = -13.0
	add_child(sound_click)

func _style(bg:Color, border:Color = Color.TRANSPARENT, radius:int = 12) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(1 if border.a > 0 else 0)
	st.set_corner_radius_all(radius)
	st.content_margin_left = 15.0
	st.content_margin_right = 15.0
	st.content_margin_top = 12.0
	st.content_margin_bottom = 12.0
	return st

func _label(parent:Node, value:String, font_size:int, color:Color, wrap_text:bool = false) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_color_override("font_color",color)
	l.add_theme_font_size_override("font_size",font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap_text else TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _make_button(parent:Node, title:String, highlight:bool = false) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size.y = 42.0
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size",14)
	b.add_theme_color_override("font_color",INK if highlight else TEXT)
	b.add_theme_color_override("font_hover_color",INK if highlight else TEXT)
	b.add_theme_color_override("font_pressed_color",INK if highlight else TEXT)
	b.add_theme_stylebox_override("normal",_style(MINT if highlight else PANEL_ALT,Color.TRANSPARENT,9))
	b.add_theme_stylebox_override("hover",_style(Color("#9aebd8") if highlight else Color("#38594d"),Color.TRANSPARENT,9))
	b.add_theme_stylebox_override("pressed",_style(Color("#58bba4") if highlight else Color("#102722"),Color.TRANSPARENT,9))
	b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	parent.add_child(b)
	return b

func _gap(parent:Node, pixels:float) -> void:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size.y = pixels
	parent.add_child(c)

func _score_card(parent:Node, heading:String, accent:Color) -> Array[Label]:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",_style(PANEL_ALT,Color.TRANSPARENT,12))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",3)
	card.add_child(stack)
	var head := _label(stack,heading,12,accent)
	var big := _label(stack,"0",36,TEXT)
	var note := _label(stack,"0 / 7 pocketed",12,MUTED)
	return [head,big,note]

func _build_ui() -> void:
	title_label = _label(self,"POOL CLUB",29,TEXT)
	board_caption = _label(self,"CLASSIC POOL HALL  /  SINGLE PLAYER",12,MUTED)
	tip_label = _label(self,"MOUSE   AIM  /  HOLD TO POWER  /  RELEASE  /  RIGHT CLICK CANCEL",12,MUTED,true)
	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel",_style(PANEL,Color("#3c5b51"),16))
	add_child(side_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",13)
	margin.add_theme_constant_override("margin_right",13)
	margin.add_theme_constant_override("margin_top",11)
	margin.add_theme_constant_override("margin_bottom",11)
	side_panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	scroll.add_child(content)
	_label(content,"THE MATCH",11,MINT)
	round_label = _label(content,"EIGHT BALL   /   PLAYER VS CPU",14,TEXT)
	_label(content,"TABLE APPEARANCE",11,MINT)
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation",7)
	content.add_child(style_row)
	prev_style_button = _make_button(style_row,"PREV")
	prev_style_button.custom_minimum_size.x = 58
	prev_style_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prev_style_button.pressed.connect(func() -> void: _cycle_style(-1))
	board_style_label = _label(style_row,"01 / 08\nCLASSIC POOL HALL",12,TEXT,true)
	board_style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_style_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board_style_label.custom_minimum_size.y = 45
	next_style_button = _make_button(style_row,"NEXT",true)
	next_style_button.custom_minimum_size.x = 58
	next_style_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	next_style_button.pressed.connect(func() -> void: _cycle_style(1))
	var scores := HBoxContainer.new()
	scores.add_theme_constant_override("separation",10)
	content.add_child(scores)
	var you := _score_card(scores,"YOU   /   OPEN",Color("#f8efda"))
	player_card_title = you[0]
	player_card_score = you[1]
	player_card_info = you[2]
	var cpu := _score_card(scores,"CPU   /   OPEN",GOLD)
	cpu_card_title = cpu[0]
	cpu_card_score = cpu[1]
	cpu_card_info = cpu[2]
	var eight_card := PanelContainer.new()
	eight_card.add_theme_stylebox_override("panel",_style(PANEL_ALT))
	content.add_child(eight_card)
	var eight_row := HBoxContainer.new()
	eight_row.add_theme_constant_override("separation",13)
	eight_card.add_child(eight_row)
	var eight_dot := _label(eight_row,"8",20,GOLD)
	eight_dot.custom_minimum_size.x = 22
	eight_dot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	eight_text = _label(eight_row,"EIGHT BALL  /  ON THE TABLE",13,TEXT)
	var turn_card := PanelContainer.new()
	turn_card.add_theme_stylebox_override("panel",_style(Color("#25483f"),Color("#3e6759")))
	content.add_child(turn_card)
	var turn_stack := VBoxContainer.new()
	turn_stack.add_theme_constant_override("separation",6)
	turn_card.add_child(turn_stack)
	turn_head = _label(turn_stack,"YOUR BREAK",18,MINT)
	turn_desc = _label(turn_stack,"Point anywhere on the table to aim.",14,TEXT,true)
	turn_desc.custom_minimum_size.y = 64
	var power_box := VBoxContainer.new()
	power_box.add_theme_constant_override("separation",5)
	content.add_child(power_box)
	power_label = _label(power_box,"SHOT POWER   HOLD MOUSE TO CHARGE",12,MUTED)
	power_meter = ProgressBar.new()
	power_meter.show_percentage = false
	power_meter.min_value = 0
	power_meter.max_value = 100
	power_meter.custom_minimum_size.y = 11
	power_meter.add_theme_stylebox_override("background",_style(Color("#0e2623"),Color.TRANSPARENT,6))
	power_meter.add_theme_stylebox_override("fill",_style(MINT,Color.TRANSPARENT,6))
	power_box.add_child(power_meter)
	stats_text = _label(content,"8 BALL   /   FIRST TO CLEAR YOUR GROUP",11,MUTED)
	var divider := HSeparator.new()
	divider.add_theme_color_override("color",Color("#537167"))
	content.add_child(divider)
	_label(content,"CPU OPPONENT",11,MINT)
	cpu_selector = OptionButton.new()
	cpu_selector.custom_minimum_size.y = 38
	cpu_selector.add_item("Casual",0)
	cpu_selector.add_item("Standard",1)
	cpu_selector.add_item("Expert",2)
	cpu_selector.select(1)
	cpu_selector.add_theme_font_size_override("font_size",14)
	cpu_selector.add_theme_color_override("font_color",TEXT)
	cpu_selector.add_theme_stylebox_override("normal",_style(PANEL_ALT,Color("#537167"),8))
	cpu_selector.add_theme_stylebox_override("hover",_style(Color("#38594d"),Color("#537167"),8))
	cpu_selector.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	cpu_selector.item_selected.connect(func(index:int) -> void:
		cpu_skill = index
		sound_click.play()
	)
	content.add_child(cpu_selector)
	_label(content,"HOW TO PLAY",11,MINT)
	_label(content,"1  Point the cursor to aim your cue ball.\n2  Hold left mouse to build shot power.\n3  Release to shoot. Right click cancels.\n4  Pocket your color, then finish the 8 ball.",13,TEXT,true)
	_gap(content,5)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",10)
	content.add_child(buttons)
	var rules_button := _make_button(buttons,"RULES")
	rules_button.pressed.connect(_open_rules)
	var new_button := _make_button(buttons,"NEW MATCH")
	new_button.pressed.connect(func() -> void:
		_new_game()
		sound_click.play()
	)
	_build_rules_overlay()

func _build_rules_overlay() -> void:
	rules_overlay = PanelContainer.new()
	rules_overlay.add_theme_stylebox_override("panel",_style(PANEL,Color("#658b7d"),16))
	rules_overlay.visible = false
	rules_overlay.z_index = 40
	add_child(rules_overlay)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",12)
	margin.add_theme_constant_override("margin_right",12)
	margin.add_theme_constant_override("margin_top",12)
	margin.add_theme_constant_override("margin_bottom",12)
	rules_overlay.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",12)
	scroll.add_child(stack)
	_label(stack,"POOL CLUB  /  HOW TO PLAY",24,MINT)
	_label(stack,"EIGHT BALL\n\nTake turns sinking balls. When you legally sink your first ball, you claim its group: solids or stripes. Keep shooting when you sink one of your own group. Sink the 8 ball after clearing all seven of your group to win. Sink it early, or scratch on the 8, and you lose.\n\nFOULS\n\nMissing all balls, scratching the cue ball, or contacting your opponent's group first is a foul. Your opponent receives ball in hand. While the table is open you cannot contact the 8 ball first.\n\nAIM AND POWER\n\nPoint the mouse at the shot you want. Hold left mouse to charge. Release to strike. Right click cancels a charge. After an opponent foul, click to place the cue ball anywhere legal.\n\nPool Club uses approachable simplified rules, not an official tournament rulebook. There is no shot calling or rail-contact requirement.",14,TEXT,true)
	var close := _make_button(stack,"RETURN TO TABLE",true)
	close.pressed.connect(func() -> void: rules_overlay.visible = false)

func _layout() -> void:
	if board == null or side_panel == null:
		return
	var sz := size
	var side_w := clampf(sz.x * .315,358.0,468.0)
	var side_x := sz.x - side_w - 24.0
	var board_w := side_x - 20.0
	var board_scale := clampf(minf((board_w - 66.0)/ 992.0,(sz.y - 176.0)/ 542.0),.42,1.22)
	board.scale = Vector2.ONE * board_scale
	board.position = Vector2(board_w * .5 - PoolBoard.W * .5 * board_scale, sz.y * .51 - PoolBoard.H * .5 * board_scale)
	side_panel.position = Vector2(side_x,22.0)
	side_panel.size = Vector2(side_w,sz.y - 44.0)
	title_label.position = Vector2(32,11)
	title_label.size = Vector2(board_w - 54,42)
	board_caption.position = Vector2(34,53)
	board_caption.size = Vector2(board_w - 54,20)
	tip_label.position = Vector2(35,sz.y - 43)
	tip_label.size = Vector2(board_w - 52,30)
	var dialog := Vector2(minf(640,sz.x - 80),minf(690,sz.y - 70))
	rules_overlay.position = (sz - dialog) * .5
	rules_overlay.size = dialog

func _load_style() -> void:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH) and cfg.load(SETTINGS_PATH) == OK:
		board_style_index = clampi(int(cfg.get_value("appearance","table_style",0)),0,PoolBoard.STYLE_NAMES.size()-1)

func _cycle_style(delta:int) -> void:
	board_style_index = posmod(board_style_index + delta,PoolBoard.STYLE_NAMES.size())
	board.set_style(board_style_index)
	_refresh_board_style()
	var cfg := ConfigFile.new()
	cfg.set_value("appearance","table_style",board_style_index)
	cfg.save(SETTINGS_PATH)
	sound_click.play()

func _refresh_board_style() -> void:
	board_style_label.text = "%02d / 08\n%s" % [board_style_index+1,PoolBoard.STYLE_NAMES[board_style_index]]
	board_caption.text = "STYLE %02d / 08  /  %s" % [board_style_index+1,PoolBoard.STYLE_NAMES[board_style_index]]

func _new_game() -> void:
	balls.clear()
	group_for = ["",""]
	player_turn = 0
	phase = "aim"
	winner = -1
	charge_power = .2
	charge_time = 0
	cpu_time = 0
	current_shot_pots.clear()
	first_contact = -1
	shot_time = 0
	cue_ball = _new_ball(0,Vector2(218,PoolBoard.H*.5))
	balls.append(cue_ball)
	# Real equilateral triangle spacing with the black ball inside the rack.
	var rack: Array = [[1],[9,2],[10,8,3],[11,4,12,5],[13,6,14,7,15]]
	for row in range(rack.size()):
		for index in range(rack[row].size()):
			var n:int = rack[row][index]
			var p := Vector2(655.0 + row * 21.1,PoolBoard.H * .5 + (float(index) - float(row)*.5)*24.25)
			balls.append(_new_ball(n,p))
	board.balls = balls
	board.cue_position = cue_ball["pos"]
	board.aim_direction = Vector2.RIGHT
	board.show_aim = true
	board.charging = false
	board.show_cpu_target = false
	_set_status("YOUR BREAK","Point to aim. Hold LEFT MOUSE to charge, then release to shoot.")
	_refresh_ui()
	board.queue_redraw()

func _new_ball(number:int, pos:Vector2) -> Dictionary:
	var kind := "solid" if number <= 7 else "stripe"
	if number == 0:
		kind = "cue"
	elif number == 8:
		kind = "eight"
	var palette := [Color("#faf4e2"),Color("#e7bc40"),Color("#3b69ad"),Color("#c7493f"),Color("#755292"),Color("#d47f38"),Color("#3a8b70"),Color("#a43f45"),Color("#232c2e")]
	var col:Color = palette[0]
	if number == 8:
		col = palette[8]
	elif number > 0:
		col = palette[number if number < 8 else number - 8]
	return {"id":number,"kind":kind,"pos":pos,"vel":Vector2.ZERO,"pocketed":false,"color":col}

func _screen_to_board() -> Vector2:
	return board.to_local(get_global_mouse_position())

func _unhandled_input(event:InputEvent) -> void:
	if rules_overlay.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			rules_overlay.visible = false
		return
	if player_turn != 0 or phase not in ["aim","charging","placement"]:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := _screen_to_board()
		if event.pressed:
			if phase == "placement":
				if PHYSICS.clear_position(balls,point,0):
					cue_ball["pos"] = point
					cue_ball["pocketed"] = false
					phase = "aim"
					board.show_aim = true
					board.cue_position = point
					_set_status("AIM YOUR SHOT","Cue ball placed. Point to aim, hold LEFT MOUSE to charge, release to shoot.")
					sound_click.play()
					_refresh_ui()
				else:
					_set_status("POSITION BLOCKED","Click an open space on the felt to place the cue ball.")
			elif phase == "aim" and Rect2(0,0,PoolBoard.W,PoolBoard.H).has_point(point):
				phase = "charging"
				charge_time = 0
				charge_power = .20
				board.charging = true
				_refresh_ui()
		elif phase == "charging":
			_shoot(aim_direction,charge_power)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if phase == "charging":
			phase = "aim"
			board.charging = false
			_set_status("AIM YOUR SHOT","Hold left mouse to charge. Right click cancels a shot.")
			_refresh_ui()

func _process(delta:float) -> void:
	if rules_overlay.visible:
		return
	if phase in ["aim","charging"]:
		var point := _screen_to_board()
		var diff:Vector2 = point - (cue_ball["pos"] as Vector2)
		if diff.length() > 19.0:
			aim_direction = diff.normalized()
			board.aim_direction = aim_direction
		board.cue_position = cue_ball["pos"]
		if phase == "charging":
			charge_time = minf(charge_time + delta,1.5)
			charge_power = .20 + .80 * charge_time / 1.5
			power_meter.value = charge_power * 100
			power_label.text = "SHOT POWER   %d%%" % int(round(charge_power * 100))
		board.aim_power = charge_power
		board.queue_redraw()
	elif phase == "placement":
		var mouse := _screen_to_board()
		if PHYSICS.clear_position(balls,mouse,0):
			cue_ball["pos"] = mouse
			board.cue_position = mouse
			board.queue_redraw()
	elif phase == "cpu_think":
		cpu_time -= delta
		if cpu_time <= 0:
			cpu_queued = _choose_cpu_shot()
			board.aim_direction = cpu_queued["dir"]
			board.aim_power = inverse_lerp(MIN_SHOT_SPEED,MAX_SHOT_SPEED,cpu_queued["speed"])
			board.cue_position = cue_ball["pos"]
			board.show_aim = true
			board.show_cpu_target = true
			board.cpu_target = cpu_queued["target"]
			board.queue_redraw()
			phase = "cpu_aim"
			cpu_time = .70
			_set_status("CPU AIMING","The computer has chosen its shot.")
			_refresh_ui()
	elif phase == "cpu_aim":
		cpu_time -= delta
		if cpu_time <= 0:
			_shoot(cpu_queued["dir"],inverse_lerp(MIN_SHOT_SPEED,MAX_SHOT_SPEED,cpu_queued["speed"]))

func _shoot(direction:Vector2, power:float) -> void:
	if direction.length_squared() < .5:
		return
	phase = "moving"
	cue_ball["vel"] = direction.normalized() * lerpf(MIN_SHOT_SPEED,MAX_SHOT_SPEED,clampf(power,0,1))
	cue_ball["pocketed"] = false
	shot_time = 0
	current_shot_pots.clear()
	first_contact = -1
	allow_eight_this_shot = group_for[player_turn] != "" and _group_cleared(group_for[player_turn])
	board.show_aim = false
	board.show_cpu_target = false
	board.charging = false
	sound_shoot.play()
	_set_status("BALLS IN MOTION","Wait for the table to settle. Pocket your own group to keep shooting.")
	_refresh_ui()
	board.queue_redraw()

func _physics_process(delta:float) -> void:
	if rules_overlay.visible or phase != "moving":
		return
	shot_time += delta
	var pocket_sound := false
	var collision_sound := false
	for substep in range(4):
		var result: Dictionary = PHYSICS.advance(balls,delta*.25)
		for id in result["pocketed"]:
			current_shot_pots.append(int(id))
			pocket_sound = true
		if first_contact == -1 and int(result["first_hit"]) > 0:
			first_contact = int(result["first_hit"])
		if int(result["contacts"]) > 0:
			collision_sound = true
	if pocket_sound and not sound_pocket.playing:
		sound_pocket.play()
	elif collision_sound and not sound_click.playing:
		sound_click.play()
	board.queue_redraw()
	if (shot_time > .28 and PHYSICS.is_still(balls)) or shot_time >= 15:
		for b in balls:
			b["vel"] = Vector2.ZERO
		_resolve_shot()

func _resolve_shot() -> void:
	var shooter := player_turn
	var next_turn := 1 - shooter
	var own_group := group_for[shooter]
	var scratch := current_shot_pots.has(0)
	var foul := scratch or first_contact < 1
	var foul_reason := "CUE BALL SCRATCH" if scratch else "NO OBJECT BALL HIT"
	if first_contact == 8 and (own_group == "" or not _group_cleared(own_group)):
		foul = true
		foul_reason = "EARLY 8 BALL CONTACT"
	elif first_contact > 0 and own_group != "" and not _group_cleared(own_group):
		if _ball_kind(first_contact) != own_group:
			foul = true
			foul_reason = "WRONG BALL FIRST"
	elif first_contact > 0 and own_group != "" and _group_cleared(own_group) and first_contact != 8:
		foul = true
		foul_reason = "YOU MUST HIT THE 8"

	if current_shot_pots.has(8):
		var legal := allow_eight_this_shot and not foul
		winner = shooter if legal else next_turn
		phase = "game_over"
		_set_status("YOU WIN" if winner == 0 else "CPU WINS","Eight ball sunk. Press NEW MATCH to play again.")
		_refresh_ui()
		board.queue_redraw()
		return

	if not foul and group_for[0] == "":
		for id in current_shot_pots:
			var kind := _ball_kind(id)
			if kind in ["solid","stripe"]:
				group_for[shooter] = kind
				group_for[next_turn] = "stripe" if kind == "solid" else "solid"
				break
	own_group = group_for[shooter]
	var keep_turn := not foul and own_group != "" and _shot_potted(own_group)
	if keep_turn:
		player_turn = shooter
	else:
		player_turn = next_turn
	var ball_in_hand := foul
	if ball_in_hand:
		cue_ball["pocketed"] = false
		cue_ball["vel"] = Vector2.ZERO
		cue_ball["pos"] = PHYSICS.find_open(balls,Vector2(220,PoolBoard.H*.5))
	elif bool(cue_ball["pocketed"]):
		cue_ball["pocketed"] = false
		cue_ball["vel"] = Vector2.ZERO
		cue_ball["pos"] = PHYSICS.find_open(balls,Vector2(220,PoolBoard.H*.5))

	charge_power = .2
	charge_time = 0
	board.charging = false
	board.show_cpu_target = false
	board.cue_position = cue_ball["pos"]
	if player_turn == 0:
		if ball_in_hand:
			phase = "placement"
			board.show_aim = false
			_set_status("BALL IN HAND","Opponent foul. Click an open spot on the felt to place your cue ball.")
		elif keep_turn:
			phase = "aim"
			board.show_aim = true
			_set_status("STAY AT THE TABLE","Good pot. You have another shot.")
		else:
			phase = "aim"
			board.show_aim = true
			_set_status("YOUR TURN","Point your cursor to aim. Hold left mouse to charge, release to shoot.")
	else:
		phase = "cpu_think"
		cpu_time = 1.05
		board.show_aim = false
		if foul:
			_set_status("CPU BALL IN HAND", "Foul: %s. CPU is preparing its next shot." % foul_reason)
		elif keep_turn:
			_set_status("CPU CONTINUES","The CPU potted its group and keeps the table.")
		else:
			_set_status("CPU TURN","The computer is reading the table.")
	_refresh_ui()
	board.queue_redraw()

func _shot_potted(kind:String) -> bool:
	for id in current_shot_pots:
		if _ball_kind(id) == kind:
			return true
	return false

func _ball_kind(number:int) -> String:
	if number == 0:
		return "cue"
	if number == 8:
		return "eight"
	return "solid" if number < 8 else "stripe"

func _group_cleared(kind:String) -> bool:
	for b in balls:
		if not bool(b["pocketed"]) and b["kind"] == kind:
			return false
	return true

func _group_pocketed(kind:String) -> int:
	var count := 0
	for b in balls:
		if bool(b["pocketed"]) and b["kind"] == kind:
			count += 1
	return count

func _set_status(heading:String, desc:String) -> void:
	status_head = heading
	status_text = desc
	if turn_head != null:
		turn_head.text = heading
		turn_desc.text = desc

func _refresh_ui() -> void:
	var p_kind := group_for[0]
	var c_kind := group_for[1]
	player_card_title.text = "YOU   /   %s" % (p_kind.to_upper() if p_kind != "" else "OPEN")
	cpu_card_title.text = "CPU   /   %s" % (c_kind.to_upper() if c_kind != "" else "OPEN")
	var you_pot := _group_pocketed(p_kind) if p_kind != "" else 0
	var cpu_pot := _group_pocketed(c_kind) if c_kind != "" else 0
	player_card_score.text = str(you_pot)
	cpu_card_score.text = str(cpu_pot)
	player_card_info.text = "%d / 7 pocketed" % you_pot
	cpu_card_info.text = "%d / 7 pocketed" % cpu_pot
	eight_text.text = "EIGHT BALL  /  POCKETED" if _eight_is_pocketed() else "EIGHT BALL  /  ON THE TABLE"
	turn_head.text = status_head
	turn_desc.text = status_text
	round_label.text = "EIGHT BALL   /   PLAYER VS CPU"
	if phase != "charging":
		power_label.text = "SHOT POWER   HOLD MOUSE TO CHARGE"
		power_meter.value = 0
	if p_kind == "":
		stats_text.text = "OPEN TABLE  /  FIRST LEGAL POT CLAIMS A GROUP"
	elif _group_cleared(p_kind):
		stats_text.text = "YOU ARE ON THE 8 BALL"
	else:
		stats_text.text = "CLEAR YOUR %s THEN POCKET THE 8" % p_kind.to_upper()

func _eight_is_pocketed() -> bool:
	for b in balls:
		if int(b["id"]) == 8:
			return bool(b["pocketed"])
	return false

func _open_rules() -> void:
	rules_overlay.visible = true
	sound_click.play()

func _choose_cpu_shot() -> Dictionary:
	var kind := group_for[1]
	var options: Array = []
	for b in balls:
		if bool(b["pocketed"]) or int(b["id"]) == 0:
			continue
		if b["kind"] == "eight":
			if kind != "" and _group_cleared(kind):
				options.append(b)
		elif kind == "" or b["kind"] == kind:
			options.append(b)
	var best: Dictionary = {}
	var best_score := INF
	var cue_pos: Vector2 = cue_ball["pos"]
	for target in options:
		var target_pos:Vector2 = target["pos"]
		for pocket in PHYSICS.POCKETS:
			var path:Vector2 = pocket - target_pos
			if path.length() < 17:
				continue
			var ghost := target_pos - path.normalized() * PoolBoard.R * 2.0
			if ghost.x < 10 or ghost.x > PoolBoard.W-10 or ghost.y < 10 or ghost.y > PoolBoard.H-10:
				continue
			var shot_vec := ghost - cue_pos
			if shot_vec.length() < 12:
				continue
			var target_clear := _line_clear(target_pos,pocket,int(target["id"]),0,PoolBoard.R * 1.55)
			var cue_clear := _line_clear(cue_pos,ghost,0,int(target["id"]),PoolBoard.R * 1.85)
			if not target_clear or not cue_clear:
				continue
			var cut_angle := absf(shot_vec.normalized().dot(path.normalized()))
			var score := shot_vec.length() * .48 + path.length() * .78 + (1.0 - cut_angle) * 360
			if score < best_score:
				best_score = score
				best = {"dir":shot_vec.normalized(),"speed":clampf(390.0 + shot_vec.length() * .75 + path.length()*.43,490.0,1320.0),"target":target_pos}
	if best.is_empty():
		var nearest:Dictionary = {}
		var min_distance := INF
		for target in options:
			var d := cue_pos.distance_to(target["pos"])
			if d < min_distance:
				min_distance = d
				nearest = target
		if nearest.is_empty():
			return {"dir":Vector2.RIGHT,"speed":600.0,"target":cue_pos + Vector2.RIGHT * 120}
		best = {"dir":(nearest["pos"] - cue_pos).normalized(),"speed":clampf(380+min_distance * .9,450,1050),"target":nearest["pos"]}
	var error := .060 if cpu_skill == 0 else .025 if cpu_skill == 1 else .007
	best["dir"] = (best["dir"] as Vector2).rotated(randf_range(-error,error))
	best["speed"] = clampf(float(best["speed"]) * randf_range(1.0-error*.8,1.0+error*.8),MIN_SHOT_SPEED,MAX_SHOT_SPEED)
	return best

func _line_clear(a:Vector2,b:Vector2,ignore_a:int,ignore_b:int,clearance:float) -> bool:
	var span := b-a
	if span.length_squared() < 1.0:
		return false
	var len := span.length()
	var direction := span / len
	for other in balls:
		if bool(other["pocketed"]) or int(other["id"]) in [ignore_a,ignore_b]:
			continue
		var projection := ((other["pos"] as Vector2) - a).dot(direction)
		if projection <= 2.0 or projection >= len:
			continue
		var closest := a + direction * projection
		if closest.distance_to(other["pos"]) < clearance:
			return false
	return true
