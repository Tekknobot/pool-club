extends RefCounted
class_name PoolPhysics

const W := 900.0
const H := 450.0
const R := 12.0
const FRICTION := 345.0
const RAIL_BOUNCE := 0.85
const BALL_BOUNCE := 0.94
const REST_EPS := 8.0
const POCKET_CATCH := 26.0
const POCKETS: Array[Vector2] = [Vector2(0,0),Vector2(450,-6),Vector2(900,0),Vector2(0,450),Vector2(450,456),Vector2(900,450)]

static func is_still(balls:Array) -> bool:
	for ball in balls:
		if not bool(ball["pocketed"]) and (ball["vel"] as Vector2).length_squared() > REST_EPS * REST_EPS:
			return false
	return true

static func advance(balls:Array, dt:float) -> Dictionary:
	var pocketed: Array[int] = []
	var first_hit := -1
	var contacts := 0
	for b in balls:
		if bool(b["pocketed"]):
			continue
		var v:Vector2 = b["vel"]
		if v.length_squared() <= REST_EPS * REST_EPS:
			b["vel"] = Vector2.ZERO
			continue
		b["pos"] = (b["pos"] as Vector2) + v * dt
		var new_speed := maxf(0, v.length() - FRICTION * dt)
		b["vel"] = v.normalized() * new_speed if new_speed > REST_EPS else Vector2.ZERO
		if _pocket(b):
			pocketed.append(int(b["id"]))
	for b in balls:
		if bool(b["pocketed"]):
			continue
		if _rail(b):
			contacts += 1
		if _pocket(b):
			pocketed.append(int(b["id"]))
	for i in range(balls.size()):
		var a:Dictionary = balls[i]
		if bool(a["pocketed"]):
			continue
		for j in range(i + 1, balls.size()):
			var b:Dictionary = balls[j]
			if bool(b["pocketed"]):
				continue
			var d:Vector2 = b["pos"] - a["pos"]
			var dist2 := d.length_squared()
			if dist2 >= 4.0 * R * R:
				continue
			var dist := maxf(sqrt(dist2), 0.0001)
			var n := d / dist if dist > .0001 else Vector2.RIGHT
			var overlap := 2.0 * R - dist
			a["pos"] = (a["pos"] as Vector2) - n * (overlap * 0.5 + .01)
			b["pos"] = (b["pos"] as Vector2) + n * (overlap * 0.5 + .01)
			var av:Vector2 = a["vel"]
			var bv:Vector2 = b["vel"]
			var approach := (bv - av).dot(n)
			if approach < 0.0:
				var impulse := -(1.0 + BALL_BOUNCE) * approach * .5
				a["vel"] = av - n * impulse
				b["vel"] = bv + n * impulse
				if absf(approach) > 35:
					contacts += 1
				if first_hit == -1:
					if int(a["id"]) == 0:
						first_hit = int(b["id"])
					elif int(b["id"]) == 0:
						first_hit = int(a["id"])
	return {"pocketed":pocketed,"first_hit":first_hit,"contacts":contacts}

static func _pocket(b:Dictionary) -> bool:
	var p:Vector2 = b["pos"]
	for c in POCKETS:
		if p.distance_squared_to(c) < POCKET_CATCH * POCKET_CATCH:
			b["pocketed"] = true
			b["vel"] = Vector2.ZERO
			return true
	return false

static func _rail(b:Dictionary) -> bool:
	var p:Vector2 = b["pos"]
	var v:Vector2 = b["vel"]
	var impact := false
	# Rail mouth openings only at pocket positions.
	var corner_top := p.y < 27.0
	var corner_bottom := p.y > H - 27.0
	var mid_top := p.y < R + 2.0 and absf(p.x - W * .5) < 27.0
	var mid_bottom := p.y > H - R - 2.0 and absf(p.x - W * .5) < 27.0
	if p.x < R and not (corner_top or corner_bottom):
		p.x = R
		v.x = absf(v.x) * RAIL_BOUNCE
		impact = true
	elif p.x > W - R and not (corner_top or corner_bottom):
		p.x = W - R
		v.x = -absf(v.x) * RAIL_BOUNCE
		impact = true
	if p.y < R and not (mid_top or (p.x < 29 or p.x > W - 29)):
		p.y = R
		v.y = absf(v.y) * RAIL_BOUNCE
		impact = true
	elif p.y > H - R and not (mid_bottom or (p.x < 29 or p.x > W - 29)):
		p.y = H - R
		v.y = -absf(v.y) * RAIL_BOUNCE
		impact = true
	# Guard against escaping through a pocket-mouth corner without falling.
	if p.x < -POCKET_CATCH:
		p.x = R
		v.x = absf(v.x) * RAIL_BOUNCE
	elif p.x > W + POCKET_CATCH:
		p.x = W - R
		v.x = -absf(v.x) * RAIL_BOUNCE
	if p.y < -POCKET_CATCH:
		p.y = R
		v.y = absf(v.y) * RAIL_BOUNCE
	elif p.y > H + POCKET_CATCH:
		p.y = H - R
		v.y = -absf(v.y) * RAIL_BOUNCE
	b["pos"] = p
	b["vel"] = v
	return impact

static func clear_position(balls:Array, point:Vector2, ignore_id:int = 0) -> bool:
	if point.x < R + 4 or point.x > W - R - 4 or point.y < R + 4 or point.y > H - R - 4:
		return false
	for ball in balls:
		if int(ball["id"]) == ignore_id or bool(ball["pocketed"]):
			continue
		if point.distance_squared_to(ball["pos"]) < (R * 2.1) * (R * 2.1):
			return false
	return true

static func find_open(balls:Array, prefer:Vector2) -> Vector2:
	if clear_position(balls,prefer):
		return prefer
	for radius in range(16,360,16):
		for angle in range(20):
			var candidate := prefer + Vector2.RIGHT.rotated(TAU * float(angle) / 20.0) * radius
			if clear_position(balls,candidate):
				return candidate
	return Vector2(225,225)
