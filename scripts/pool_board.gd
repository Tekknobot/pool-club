extends Node2D
class_name PoolBoard

# Identical visual vocabulary to Carrom: layered wood, soft ornament,
# subtle grain, fine outlines, mint shot planning and flat lit tokens.
const BALL_SHADER := preload("res://shaders/billiard_ball.gdshader")
const BALL_TEXTURE_SIZE := 64
const W := 900.0
const H := 450.0
const R := 12.0
const POCKET_RADIUS := 27.0
const STYLE_NAMES := [
	"CLASSIC POOL HALL", "DARK ROSEWOOD", "IVORY & WALNUT", "MODERN MINIMAL",
	"VINTAGE HERITAGE", "BLACK & GOLD", "COASTAL TEAK", "ARCADE NEON"
]
const SKINS := [
	{"outer":"#3c281c","rim":"#946035","trim":"#dfb77b","inner":"#34251c","rail":"#74472a","cushion":"#173e31","felt":"#17694f","felt2":"#166049","mark":"#e5c58f","pocket":"#111b1b","grain":"#e4b17a"},
	{"outer":"#281615","rim":"#69332b","trim":"#d3a877","inner":"#2d1a1a","rail":"#794238","cushion":"#3c2c2a","felt":"#447266","felt2":"#3a685f","mark":"#e3c48b","pocket":"#10171a","grain":"#b8796b"},
	{"outer":"#30251c","rim":"#805530","trim":"#ecd6a2","inner":"#614529","rail":"#d5bd92","cushion":"#435343","felt":"#758e72","felt2":"#70896e","mark":"#efe5bd","pocket":"#191a19","grain":"#9c7644"},
	{"outer":"#192a30","rim":"#425a60","trim":"#a4bbb7","inner":"#27373e","rail":"#495e61","cushion":"#184956","felt":"#3a7f81","felt2":"#347579","mark":"#b7d9d2","pocket":"#0f1c24","grain":"#789fa2"},
	{"outer":"#4a2b19","rim":"#a4733e","trim":"#dec08b","inner":"#5b321b","rail":"#af8250","cushion":"#3f4930","felt":"#567a4a","felt2":"#4e7144","mark":"#e6c58b","pocket":"#1a2116","grain":"#efc187"},
	{"outer":"#121418","rim":"#363330","trim":"#c6a464","inner":"#181b20","rail":"#282e34","cushion":"#383523","felt":"#323c39","felt2":"#303735","mark":"#dbbc7b","pocket":"#050a0c","grain":"#7c704d"},
	{"outer":"#2c3830","rim":"#7a6245","trim":"#e0c293","inner":"#3b4d46","rail":"#a58457","cushion":"#26544c","felt":"#44867b","felt2":"#3e7a71","mark":"#e6e0b5","pocket":"#142321","grain":"#ded0a8"},
	{"outer":"#090d21","rim":"#27254d","trim":"#ac5bba","inner":"#131630","rail":"#323259","cushion":"#193e4c","felt":"#182e42","felt2":"#17283d","mark":"#7ce9dc","pocket":"#040918","grain":"#5066a0"}
]
var style_index := 0
var balls: Array = []
var show_aim := false
var aim_direction := Vector2.RIGHT
var aim_power := 0.2
var charging := false
var show_cpu_target := false
var cpu_target := Vector2.ZERO
var cue_position := Vector2(220, 225)
var ghost_position := Vector2(-1000,-1000)
var _ball_sprite_texture: Texture2D
var _ball_sprites: Dictionary = {}

func _ready() -> void:
	# Procedural white source image; the shader supplies the ball's entire appearance.
	var image := Image.create_empty(BALL_TEXTURE_SIZE, BALL_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_ball_sprite_texture = ImageTexture.create_from_image(image)
	sync_ball_visuals()

func sync_ball_visuals() -> void:
	if _ball_sprite_texture == null:
		return
	for ball in balls:
		var number: int = int(ball["id"])
		if not _ball_sprites.has(number):
			var sprite := Sprite2D.new()
			sprite.name = "BilliardBall%02d" % number
			sprite.texture = _ball_sprite_texture
			sprite.centered = true
			sprite.scale = Vector2.ONE * ((R * 2.0) / float(BALL_TEXTURE_SIZE))
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.z_index = 1
			var material := ShaderMaterial.new()
			material.shader = BALL_SHADER
			sprite.material = material
			add_child(sprite)
			_ball_sprites[number] = sprite
		var ball_sprite: Sprite2D = _ball_sprites[number]
		ball_sprite.visible = not bool(ball["pocketed"])
		if not ball_sprite.visible:
			continue
		ball_sprite.position = ball["pos"]
		var material: ShaderMaterial = ball_sprite.material as ShaderMaterial
		var kind: String = ball["kind"]
		var kind_index := 0
		if kind == "stripe":
			kind_index = 1
		elif kind == "cue":
			kind_index = 2
		elif kind == "eight":
			kind_index = 3
		var spin: Quaternion = ball["roll"]
		material.set_shader_parameter("ball_kind", kind_index)
		material.set_shader_parameter("ball_color", ball["color"])
		material.set_shader_parameter("ball_spin", Vector4(spin.x, spin.y, spin.z, spin.w))


func set_style(index:int) -> void:
	style_index = posmod(index, STYLE_NAMES.size())
	queue_redraw()

func _c(key: String) -> Color:
	return Color(str(SKINS[style_index][key]))

func _draw() -> void:
	_draw_table()
	_draw_ball_shadows()
	_draw_aim()

func _draw_table() -> void:
	var outer := _c("outer")
	var rim := _c("rim")
	var trim := _c("trim")
	var inner := _c("inner")
	var rail := _c("rail")
	var cushion := _c("cushion")
	var felt := _c("felt")
	# Painted, inset wood frame. Same stepped-edge language as Carrom.
	draw_rect(Rect2(-46, -46, 992, 542), outer, true)
	draw_rect(Rect2(-41, -41, 982, 532), rim, true)
	draw_rect(Rect2(-35, -35, 970, 520), trim, true)
	draw_rect(Rect2(-31, -31, 962, 512), inner, true)
	draw_rect(Rect2(-26, -26, 952, 502), rail, true)
	draw_rect(Rect2(-13, -13, 926, 476), cushion, true)
	draw_rect(Rect2(0, 0, W, H), felt, true)
	# Fine wood joinery and softly directional grain, with no textures to load.
	for i in range(4):
		var f := float(i) * 3.0
		draw_rect(Rect2(-40 + f, -40 + f, 980 - f * 2, 530 - f * 2), Color(trim, 0.64 if i == 0 else 0.23), false, 1.0, true)
	for i in range(40):
		var y := -40.0 + float((i * 17) % 18)
		var x := float((i * 53) % 865)
		draw_line(Vector2(x, y), Vector2(minf(x + 62.0, W), y + 0.8), Color(_c("grain"), 0.14), 1.0, true)
		var bottom := H + 22.0 + float((i * 19) % 15)
		draw_line(Vector2(x, bottom), Vector2(minf(x + 65.0, W), bottom + 0.4), Color(_c("grain"), 0.12), 1.0, true)
	# Soft, deterministic felt weave / tiny ambient variation.
	draw_rect(Rect2(1, 1, W - 2.0, H * 0.47), Color(_c("felt2"), 0.28), true)
	for n in range(68):
		var yy := float((n * 97 + 31) % 440) + 5.0
		draw_line(Vector2(8, yy), Vector2(W - 8, yy + sin(float(n) * 3.71) * 0.7), Color(1, 1, 1, 0.011), 1.0, true)
	# Cushion edge with a light inner lip.
	draw_line(Vector2(35, 0), Vector2(W - 35, 0), Color(0, 0, 0, .25), 3, true)
	draw_line(Vector2(35, H), Vector2(W - 35, H), Color(0, 0, 0, .28), 3, true)
	draw_line(Vector2(0, 36), Vector2(0, H - 36), Color(0, 0, 0, .27), 3, true)
	draw_line(Vector2(W, 36), Vector2(W, H - 36), Color(0, 0, 0, .27), 3, true)
	# Six leather-rimmed pockets, centre mouths interrupt top and bottom.
	for pocket in pocket_points():
		draw_circle(pocket, 34.0, Color(_c("inner"), 0.95), true, -1, true)
		draw_circle(pocket, 28.6, trim, true, -1, true)
		draw_circle(pocket, 25.8, Color("#44342a"), true, -1, true)
		draw_circle(pocket, 23.0, _c("pocket"), true, -1, true)
		draw_circle(pocket + Vector2(-3.0,-2.0), 17.0, Color(0,0,0,.15), true, -1, true)
	# Mother-of-pearl diamond sights and paired brass corner bolts.
	for x in [90.0, 180.0, 315.0, 585.0, 720.0, 810.0]:
		_diamond(Vector2(x, -31.0), trim, 4.5)
		_diamond(Vector2(x, H + 31.0), trim, 4.5)
	for y in [H * 0.25, H * 0.5, H * 0.75]:
		_diamond(Vector2(-31.0, y), trim, 4.3)
		_diamond(Vector2(W + 31.0, y), trim, 4.3)
	for x in [-34.0, W + 34.0]:
		for y in [62.0,H - 62.0]:
			draw_circle(Vector2(x,y), 2.8, trim, true, -1, true)
	# Discrete head spot and foot spot, like engraved Carrom board marks.
	draw_circle(Vector2(W * 0.25, H * 0.5), 3.0, Color(_c("mark"), .35), true, -1, true)
	draw_circle(Vector2(W * 0.74, H * 0.5), 3.0, Color(_c("mark"), .35), true, -1, true)

func pocket_points() -> Array[Vector2]:
	return [Vector2(0, 0), Vector2(W * 0.5, -6), Vector2(W, 0), Vector2(0, H), Vector2(W * .5, H + 6), Vector2(W, H)]

func _diamond(pos:Vector2, color:Color, radius:float) -> void:
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0,-radius),pos + Vector2(radius,0),pos + Vector2(0,radius),pos + Vector2(-radius,0)]), color)

func _draw_ball_shadows() -> void:
	# Contact shadows are drawn *beneath* the rolling shader sprites.
	# Their direction stays fixed while each sphere rotates independently.
	for ball in balls:
		if bool(ball["pocketed"]):
			continue
		var pos: Vector2 = ball["pos"]
		var speed: Vector2 = ball["vel"]
		if speed.length_squared() > 240.0 * 240.0:
			var backwards: Vector2 = -speed.normalized()
			var trail_length := minf(speed.length() / 250.0, 6.0)
			draw_line(pos + Vector2(1.4, 3.1) + backwards * trail_length, pos + Vector2(1.4, 3.1), Color(0.03, 0.08, 0.05, 0.085), 7.0, true)
		draw_circle(pos + Vector2(1.5, 3.3), R + 3.2, Color(0.01, 0.025, 0.02, 0.045), true, -1, true)
		draw_circle(pos + Vector2(1.2, 2.7), R + 1.4, Color(0.01, 0.025, 0.02, 0.10), true, -1, true)
		draw_circle(pos + Vector2(0.8, 2.0), R - 1.4, Color(0, 0, 0, 0.085), true, -1, true)

func _draw_aim() -> void:
	if not show_aim:
		return
	var dir := aim_direction.normalized()
	if dir.length_squared() < .5:
		return
	var start := cue_position
	var tint := Color("#79f2f1") if style_index == 7 else Color("#60cbb4")
	# A restrained hand-drawn cue sits behind the white ball.
	var back := -dir
	var cue_tip := start + back * 20.0
	var cue_tail := start + back * (143.0 + (aim_power * 30.0 if charging else 0.0))
	draw_line(cue_tip,cue_tail,Color("#352719"),6.0,true)
	draw_line(cue_tip,cue_tail,Color("#e0b97d"),3.4,true)
	draw_line(cue_tip,cue_tip + back * 5.0,Color("#6ac3c4"),4.2,true)
	var cast_len := 130.0 + aim_power * 245.0
	for i in range(int(cast_len / 15.0)):
		var a := start + dir * (26.0 + float(i) * 15.0)
		if a.distance_to(start) > cast_len:
			break
		draw_line(a,a + dir * 8.0,Color(tint,.86),2.5,true)
	draw_arc(start,26,0,TAU,50,Color(tint,.5),1.6,true)
	var tip := start + dir * cast_len
	var side := dir.orthogonal() * 7.0
	draw_colored_polygon(PackedVector2Array([tip + dir * 12.0,tip - dir * 7.0 + side,tip - dir * 7.0 - side]),tint)
	if charging:
		draw_arc(start,26,-PI/2.0,-PI/2.0 + TAU * aim_power,60,tint,5.0,true)
	if show_cpu_target:
		draw_arc(cpu_target,23,0,TAU,48,Color(tint,.48),1.5,true)
