# tools/build_office_blockout.gd — JIOH-43: generates the grey-box office.
#
#   godot --headless --path . --script res://tools/build_office_blockout.gd
#
# Writes scenes/office/office_blockout.tscn from the floor plan below. The
# plan is rasterised on the 0.25 m grid; walls are generated wherever a room
# meets nothing or a different room, except across doorways. Run it again
# after editing the plan. Once dressing starts, edit the scene by hand instead
# and stop regenerating it.
#
# Coordinates are metres: x east, z south. Route targets (at 1.6 m/s):
# desk to hatch under 5 s, desk to file store 8-10 s, desk to print room
# 12-15 s, desk to kitchen 20 s or more.
extends SceneTree

const OUT := "res://scenes/office/office_blockout.tscn"
const PS1 := preload("res://shaders/ps1_standard.gdshader")
const REFUSE := preload("res://scripts/interaction/refuse_interactable.gd")
const GRID := 0.25
const HEIGHT := 2.4
const WALL := 0.25
const HATCH_SILL := 0.95
const HATCH_HEAD := 2.0

# Spaces as [x0, z0, x1, z1]. Rooms named in the JIOH-43 contract become
# children of Office; "Corridor" is circulation and has no room node.
const ROOMS := {
	"Hatch": [2.0, 0.0, 6.0, 8.0],           # public lobby the trades wait in
	"Reception": [6.0, 0.0, 16.0, 8.0],      # the office: both desks, the hatch
	"Stairwell": [12.0, -4.0, 16.0, 0.0],
	"FileStore": [18.0, 0.0, 24.0, 5.5],
	"PrintRoom": [26.0, 0.0, 32.0, 5.5],
	"KeyCabinet": [18.0, 7.5, 20.0, 9.0],    # an alcove off the corridor
	"Kitchen": [20.0, 20.0, 30.0, 25.0],
	"YardDoor": [34.0, 5.5, 36.0, 7.5],      # staff entrance vestibule
	"Corridor": [16.0, 5.5, 34.0, 7.5],
	"CorridorSouth": [24.0, 7.5, 26.0, 20.0],
}

# Openings as [x0, z0, x1, z1] rectangles straddling a shared wall: every
# wall edge inside one is left open.
const DOORS := [
	[15.9, 6.0, 16.1, 7.0],    # Reception -> Corridor
	[13.5, -0.1, 14.5, 0.1],   # Reception -> Stairwell
	[19.5, 5.4, 20.5, 5.6],    # Corridor -> FileStore
	[27.0, 5.4, 28.0, 5.6],    # Corridor -> PrintRoom
	[18.0, 7.4, 20.0, 7.6],    # Corridor -> KeyCabinet (open alcove)
	[24.0, 7.4, 26.0, 7.6],    # Corridor -> CorridorSouth
	[24.5, 19.9, 25.5, 20.1],  # CorridorSouth -> Kitchen
	[33.9, 5.5, 34.1, 7.5],    # Corridor -> YardDoor (open)
]
# The reception hatch: wall below the sill and above the head, open between.
const HATCH := [5.9, 3.0, 6.1, 4.25]
# Exterior doors, drawn as closed door panels in the wall.
const EXTERIOR_DOORS := {
	"FrontDoor": [3.5, 7.9, 4.5, 8.1],
	"YardDoorPanel": [35.9, 6.0, 36.1, 7.0],
}

const PLAYER_DESK := Vector3(9.5, 0, 3.5)
const PLAYER_DESK_STAND := Vector3(10.25, 0, 3.6)
const JANICE_DESK := Vector3(7.0, 0, 5.5)
const JANICE_PEN := [6.0, 4.5, 8.25, 6.75]  # low partitions around her desk

const ROUTES := {
	"DeskToHatch": [Vector3(10.25, 0, 3.6), Vector3(10.25, 0, 2.4), Vector3(6.6, 0, 2.4), Vector3(6.6, 0, 3.6)],
	"DeskToFileStore": [Vector3(10.25, 0, 3.6), Vector3(11.0, 0, 6.5), Vector3(20.0, 0, 6.5), Vector3(20.0, 0, 3.5)],
	"DeskToPrintRoom": [Vector3(10.25, 0, 3.6), Vector3(11.0, 0, 6.5), Vector3(27.5, 0, 6.5), Vector3(27.5, 0, 3.5)],
	"DeskToKitchen": [Vector3(10.25, 0, 3.6), Vector3(11.0, 0, 6.5), Vector3(25.0, 0, 6.5), Vector3(25.0, 0, 22.5)],
	"YardToHatch": [Vector3(35.0, 0, 6.5), Vector3(11.0, 0, 6.5), Vector3(8.7, 0, 4.6), Vector3(8.7, 0, 3.6), Vector3(6.6, 0, 3.6)],
}

var _root: Node3D
var _cells := {}  # Vector2i -> space name


func _initialize() -> void:
	_rasterise()
	_root = Node3D.new()
	_root.name = "Office"
	var blockout := _add(_root, Node3D.new(), "Blockout")
	blockout.set_meta(&"delete_when_dressed", true)
	var collision := _add(_root, StaticBody3D.new(), "Collision") as StaticBody3D
	collision.collision_layer = 1
	collision.set_meta(&"surface", "vinyl")

	var floor_mat := _material(Color(0.42, 0.41, 0.38))
	var wall_mat := _material(Color(0.78, 0.76, 0.70))
	var ceiling_mat := _material(Color(0.62, 0.62, 0.60))
	var door_mat := _material(Color(0.36, 0.27, 0.18))
	var furniture_mat := _material(Color(0.55, 0.46, 0.34))

	for space in ROOMS:
		var r: Array = ROOMS[space]
		var size := Vector3(r[2] - r[0], 0.2, r[3] - r[1])
		var centre := Vector3((r[0] + r[2]) / 2.0, -0.1, (r[1] + r[3]) / 2.0)
		_box(blockout, "Floor_" + space, centre, size, floor_mat)
		_box(blockout, "Ceiling_" + space, centre + Vector3(0, HEIGHT + 0.2, 0), size, ceiling_mat)
		_collider(collision, centre, size)

	var n := 0
	for seg in _wall_segments():
		n += 1
		_wall(blockout, collision, "Wall_%d" % n, seg, 0.0, HEIGHT, wall_mat)
	for seg in _wall_segments(true):
		n += 1
		_wall(blockout, collision, "HatchSill_%d" % n, seg, 0.0, HATCH_SILL, wall_mat)
		_wall(blockout, null, "HatchHead_%d" % n, seg, HATCH_HEAD, HEIGHT, wall_mat)
	for door in EXTERIOR_DOORS:
		var d: Array = EXTERIOR_DOORS[door]
		var c := Vector3((d[0] + d[2]) / 2.0, 1.0, (d[1] + d[3]) / 2.0)
		_box(blockout, door, c, Vector3(maxf(d[2] - d[0], 0.3), 2.0, maxf(d[3] - d[1], 0.3)), door_mat)

	_build_rooms(blockout, collision, furniture_mat)
	_build_routes()
	_own(_root, _root)
	var packed := PackedScene.new()
	packed.pack(_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := ResourceSaver.save(packed, OUT)
	print("office blockout: %d wall runs, saved %s (%s)" % [n, OUT, error_string(err)])
	_root.free()
	quit(0 if err == OK else 1)


func _build_rooms(blockout: Node3D, collision: StaticBody3D, furniture_mat: Material) -> void:
	for space in ["Reception", "Hatch", "PlayerDesk", "JanicesDesk", "PrintRoom",
			"KeyCabinet", "FileStore", "Kitchen", "Stairwell", "YardDoor"]:
		var room := _add(_root, Node3D.new(), space) as Node3D
		var anchor := _add(room, Marker3D.new(), "Anchor") as Marker3D
		if ROOMS.has(space):
			var r: Array = ROOMS[space]
			room.position = Vector3((r[0] + r[2]) / 2.0, 0, (r[1] + r[3]) / 2.0)
		match space:
			"Hatch":
				room.position = Vector3(5.0, 0, 3.6)  # where a trade stands
				anchor.rotation.y = -PI / 2  # facing the office
				_box(blockout, "HatchCounter", Vector3(6.0, HATCH_SILL, 3.625), Vector3(0.7, 0.05, 1.25), furniture_mat)
			"PlayerDesk":
				room.position = PLAYER_DESK_STAND
				anchor.rotation.y = PI / 2  # facing west, at the hatch
				_desk(blockout, collision, "PlayerDeskTop", PLAYER_DESK, furniture_mat, Vector3(0.7, 0.75, 1.4))
			"JanicesDesk":
				room.position = JANICE_DESK
				var body := _add(room, StaticBody3D.new(), "Desk") as StaticBody3D
				body.collision_layer = 1
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(1.4, 0.75, 0.7)
				shape.shape = box
				shape.position = Vector3(0, 0.375, 0)
				_add(body, shape, "Shape")
				_box(blockout, "JanicesDeskTop", JANICE_DESK + Vector3(0, 0.375, 0), Vector3(1.4, 0.75, 0.7), furniture_mat)
				var refuse := REFUSE.new() as Interactable
				refuse.display_name = "Janice's desk"
				refuse.object_id = &"janices_desk"
				refuse.set("reason", "janices_desk_not_yours")
				var ishape := CollisionShape3D.new()
				var ibox := BoxShape3D.new()
				ibox.size = Vector3(1.5, 0.9, 0.8)
				ishape.shape = ibox
				ishape.position = Vector3(0, 0.45, 0)
				_add(room, refuse, "Interactable")
				_add(refuse, ishape, "Shape")
				var p: Array = JANICE_PEN
				var rail := 1.0
				_wall(blockout, collision, "JanicePenNorth", [Vector2(p[0], p[1]), Vector2(p[2], p[1])], 0.0, rail, furniture_mat)
				_wall(blockout, collision, "JanicePenEast", [Vector2(p[2], p[1]), Vector2(p[2], p[3])], 0.0, rail, furniture_mat)
				_wall(blockout, collision, "JanicePenSouth", [Vector2(p[0], p[3]), Vector2(p[2], p[3])], 0.0, rail, furniture_mat)
			"PrintRoom":
				_desk(blockout, collision, "PrinterBench", Vector3(29.0, 0, 0.6), furniture_mat)
			"FileStore":
				for i in 3:
					_box(blockout, "Shelf_%d" % i, Vector3(19.0 + i * 2.0, 1.0, 1.0), Vector3(1.2, 2.0, 0.5), furniture_mat)
					_collider(collision, Vector3(19.0 + i * 2.0, 1.0, 1.0), Vector3(1.2, 2.0, 0.5))
			"KeyCabinet":
				_box(blockout, "Cabinet", Vector3(19.0, 1.4, 8.85), Vector3(0.8, 0.8, 0.2), furniture_mat)
			"Kitchen":
				_desk(blockout, collision, "Worktop", Vector3(25.0, 0, 24.4), furniture_mat)


func _build_routes() -> void:
	var routes := _add(_root, Node3D.new(), "Routes")
	for route in ROUTES:
		var path := Path3D.new()
		path.curve = Curve3D.new()
		for p in ROUTES[route]:
			path.curve.add_point(p)
		_add(routes, path, route)


# --- Rasterising -------------------------------------------------------------

func _rasterise() -> void:
	for space in ROOMS:
		var r: Array = ROOMS[space]
		for gx in range(roundi(r[0] / GRID), roundi(r[2] / GRID)):
			for gz in range(roundi(r[1] / GRID), roundi(r[3] / GRID)):
				_cells[Vector2i(gx, gz)] = space


## Wall runs as [Vector2 a, Vector2 b] in metres, merged along each grid line.
## With hatch=true, returns only the hatch runs instead.
func _wall_segments(hatch := false) -> Array:
	var edges := {}  # canonical edge key -> true
	for cell in _cells:
		for dir in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var other: Vector2i = cell + dir
			if _cells.get(other, "") == _cells[cell] or _joined(_cells[cell], _cells.get(other, "")):
				continue
			var edge := _edge(cell, dir)
			var mid: Vector2 = (edge[0] + edge[1]) / 2.0
			if _inside_any(mid, DOORS):
				continue
			if _inside(mid, HATCH) != hatch:
				continue
			edges[edge] = true
	return _merge(edges.keys())


## Corridor pieces join without walls between them.
func _joined(a: String, b: String) -> bool:
	return a.begins_with("Corridor") and b.begins_with("Corridor")


func _edge(cell: Vector2i, dir: Vector2i) -> Array:
	var x := cell.x * GRID
	var z := cell.y * GRID
	match dir:
		Vector2i(1, 0): return [Vector2(x + GRID, z), Vector2(x + GRID, z + GRID)]
		Vector2i(-1, 0): return [Vector2(x, z), Vector2(x, z + GRID)]
		Vector2i(0, 1): return [Vector2(x, z + GRID), Vector2(x + GRID, z + GRID)]
	return [Vector2(x, z), Vector2(x + GRID, z)]


func _merge(edges: Array) -> Array:
	var vertical := {}
	var horizontal := {}
	for e in edges:
		if is_equal_approx(e[0].x, e[1].x):
			vertical.get_or_add(e[0].x, []).append(e[0].y)
		else:
			horizontal.get_or_add(e[0].y, []).append(e[0].x)
	var out := []
	for x in vertical:
		for run in _runs(vertical[x]):
			out.append([Vector2(x, run.x), Vector2(x, run.y)])
	for z in horizontal:
		for run in _runs(horizontal[z]):
			out.append([Vector2(run.x, z), Vector2(run.y, z)])
	return out


func _runs(starts: Array) -> Array[Vector2]:
	starts.sort()
	var out: Array[Vector2] = []
	var a: float = starts[0]
	var b: float = a + GRID
	for s in starts.slice(1):
		if is_equal_approx(s, b):
			b += GRID
		elif s > b:
			out.append(Vector2(a, b))
			a = s
			b = s + GRID
	out.append(Vector2(a, b))
	return out


func _inside(p: Vector2, r: Array) -> bool:
	return p.x >= r[0] and p.x <= r[2] and p.y >= r[1] and p.y <= r[3]


func _inside_any(p: Vector2, rects: Array) -> bool:
	for r in rects:
		if _inside(p, r):
			return true
	return false


# --- Node helpers --------------------------------------------------------------

func _wall(parent: Node, collision: StaticBody3D, name: String, seg: Array, y0: float, y1: float, mat: Material) -> void:
	var a: Vector2 = seg[0]
	var b: Vector2 = seg[1]
	var vertical := is_equal_approx(a.x, b.x)
	var length := (b - a).length() + WALL
	var size := Vector3(WALL, y1 - y0, length) if vertical else Vector3(length, y1 - y0, WALL)
	var centre := Vector3((a.x + b.x) / 2.0, (y0 + y1) / 2.0, (a.y + b.y) / 2.0)
	_box(parent, name, centre, size, mat)
	if collision:
		_collider(collision, centre, size)


func _desk(parent: Node, collision: StaticBody3D, name: String, at: Vector3, mat: Material,
		size := Vector3(1.4, 0.75, 0.7)) -> void:
	_box(parent, name, at + Vector3(0, 0.375, 0), size, mat)
	_collider(collision, at + Vector3(0, 0.375, 0), size)


func _box(parent: Node, name: String, centre: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.size = size
	box.position = centre
	box.material = mat
	_add(parent, box, name)
	return box


func _collider(body: StaticBody3D, centre: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	_add(body, shape, "Shape")


func _material(colour: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter(&"albedo", colour)
	return m


func _add(parent: Node, child: Node, name: String) -> Node:
	child.name = name
	parent.add_child(child, true)
	return child


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
