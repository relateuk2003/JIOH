# tests/gpu/TypographyProbe.gd — JIOH-63 acceptance criteria on real pixels.
extends Probe

const STACK := preload("res://scenes/rendering/render_stack.tscn")
const BG := Color(0.95, 0.94, 0.89)
const INK := Color(0.13, 0.19, 0.52)


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 960)

	# The faces: bitmaps, whole-number scaling only, binary alpha.
	for f in JiohFonts.PATHS:
		var font := load(f) as FontFile
		check(font != null and font.fixed_size > 0 and font.fixed_size_scale_mode == TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY,
			"%s is a fixed-size bitmap face, integer scaling only" % f.get_file())
		var atlas := Image.load_from_file(ProjectSettings.globalize_path(f.get_basename() + ".png"))
		var alphas := {}
		for y in atlas.get_height():
			for x in atlas.get_width():
				alphas[roundi(atlas.get_pixel(x, y).a * 255)] = true
		check(alphas.keys().all(func(a): return a == 0 or a == 255), "%s atlas has no partial alpha" % f.get_file().get_basename())

	# A glyph's edge pixels are glyph or paper, nothing in between.
	var a := await _render(Vector2(10, 6), "Job sheet J2211 Room 2.04 Mon 05/10")
	var colours := _colours(a)
	check(colours.size() == 2, "only paper and ink colours in rendered body text (%d colours)" % colours.size())
	var big := await _render(Vector2(10, 6), "PERMIT TO WORK", JiohFonts.Face.DISPLAY)
	check(_colours(big).size() == 2, "the display face too")

	# Fractional placement rounds to the same glyph grid.
	var b := await _render(Vector2(10.4, 5.6), "Job sheet J2211 Room 2.04 Mon 05/10")
	check(a.get_data() == b.get_data(), "PixelText at (10.4, 5.6) draws exactly as at (10, 6)")
	var t := PixelText.new()
	t.pixel_scale = 2
	check(t.label_settings.font_size == 20, "scale is whole-number font size only")
	t.free()

	# In the shipped stack, subtitles live in the internal viewport.
	var stack: Control = STACK.instantiate()
	add_child(stack)
	await _frames(3)
	check(Subtitles.label != null and Subtitles.label.get_viewport() == stack.viewport,
		"spoken lines are drawn inside the 320x240 internal viewport")
	stack.queue_free()

	# Decals replace Label3D.
	var d := PixelDecal.make("SPARKS", Color(0.86, 0.83, 0.74), Color(0.48, 0.34, 0.2), 0.003)
	add_child(d)
	await _frames(3)
	var di := d.image()
	check(di.get_size() == Vector2i(ceili(JiohFonts.width_of("SPARKS", JiohFonts.Face.BODY)) + 2, 10) and _colours(di).size() == 2,
		"a painted label is a one-texel-per-pixel decal in two colours")

	# The page budget is a number.
	var std := TypographyStandard.shipped()
	check(std.lines_per_page() >= 7 and std.words_per_page > 0, "a clipboard page holds %d lines, %d words" % [std.lines_per_page(), std.words_per_page])
	finish()


func _render(at: Vector2, s: String, face := JiohFonts.Face.BODY) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(220, 30)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var t := PixelText.new()
	t.face = face
	t.ink = INK
	t.text = s
	vp.add_child(t)
	t.position = at
	await _frames(3)
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _colours(img: Image) -> Dictionary:
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			out[img.get_pixel(x, y).to_html()] = true
	return out


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
