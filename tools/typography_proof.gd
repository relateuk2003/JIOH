# tools/typography_proof.gd — JIOH-63: where the faces are judged. Every face
# on a real in-world page at reading distance, drawn at internal resolution
# through the full PS1 stack and upscaled 4x. Run it windowed:
#
#   godot --path . res://tools/typography_proof.tscn [-- out.png]
#
# With a path it saves one frame there and quits.
extends Node3D

const SAMPLE := [
	[JiohFonts.Face.DISPLAY, "PERMIT"],
	[JiohFonts.Face.BODY, "Job no. J2211  Room 2.04"],
	[JiohFonts.Face.BODY, "Valid from 08/10/26 08:00"],
	[JiohFonts.Face.BODY, "abcdefghijklmnopqrs"],
	[JiohFonts.Face.BODY, "tuvwxyz ABCDEFGHIJK"],
	[JiohFonts.Face.TERMINAL, "> TUE 6 Kev Moyes"],
	[JiohFonts.Face.TERMINAL, "0123456789 !?&%"],
]


func _ready() -> void:
	var std := TypographyStandard.shipped()
	var page := PaperFace.new()
	page.size_m = Vector2(0.21, 0.1575)
	page.pixels = std.page_pixels
	page.painter = _paint
	page.rotation.x = deg_to_rad(60)
	add_child(page)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.16, 0.2)
	cam.fov = 60
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-1.0, 0.3, 0)
	add_child(light)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		for i in 8:
			await get_tree().process_frame
		get_tree().root.get_viewport().get_texture().get_image().save_png(args[0])
		get_tree().quit()


func _paint(c: FaceCanvas) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.95, 0.94, 0.89))
	var y := 2
	for row in SAMPLE:
		var f: JiohFonts.Face = row[0]
		c.text(Vector2(4, y + JiohFonts.NATIVE[f] - 3), row[1], JiohFonts.NATIVE[f], Color(0.16, 0.16, 0.16), -1.0,
			HORIZONTAL_ALIGNMENT_LEFT, f)
		y += JiohFonts.NATIVE[f] + 1
