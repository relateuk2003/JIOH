# tools/build_handover_note.gd — JIOH-57: bakes Janice's handwriting.
#
#   godot --headless --path . res://tools/build_handover_note.tscn
#
# Renders every page of resources/text/handover_note.tres side by side into
# resources/textures/props/note_handover_albedo.png and records the page
# count. Run it after any change to the note's text; HandoverNoteProbe fails
# if the texture and the text disagree.
extends Node

const NOTE := "res://resources/text/handover_note.tres"
const OUT := "res://resources/textures/props/note_handover_albedo.png"


func _ready() -> void:
	var note := load(NOTE) as HandwrittenText
	var pages := note.layout()
	var atlas := Image.create(HandwrittenText.PAGE.x * pages.size(), HandwrittenText.PAGE.y, false, Image.FORMAT_RGBA8)
	for i in pages.size():
		atlas.blit_rect(note.render(i), Rect2i(Vector2i.ZERO, HandwrittenText.PAGE), Vector2i(HandwrittenText.PAGE.x * i, 0))
		print("page %d: %d lines" % [i + 1, (pages[i] as Array).size()])
	atlas.save_png(ProjectSettings.globalize_path(OUT))
	note.page_count = pages.size()
	if FileAccess.file_exists(OUT + ".import") or ResourceLoader.exists(OUT):
		note.texture = load(OUT)
	ResourceSaver.save(note, NOTE)
	print("wrote %s (%d pages)" % [OUT, pages.size()])
	get_tree().quit()
