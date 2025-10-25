#!/usr/bin/env godot
## Sprite Sheet Processor - Automated AtlasTexture Generation
## Eliminates manual sprite sheet slicing and AtlasTexture creation
##
## Usage: godot --headless --script tools/sprite_processor.gd -- [options]
##
## Options:
##   --input <path>          Input sprite sheet image path
##   --grid <WxH>           Grid dimensions (e.g., "628x663")
##   --output <path>        Output SpriteFrames resource path
##   --animation <name>     Animation name (default: "default")
##   --fps <number>         Animation FPS (default: 10)
##   --validate             Validate existing manual AtlasTextures

extends SceneTree

class_name SpriteProcessor

var args := {}
var execution_results := {
	"start_time": "",
	"processed_frames": 0,
	"output_files": [],
	"errors": [],
	"success": false
}

func _init():
	print("🎨 Sprite Sheet Processor - Automated AtlasTexture Generation")
	print("===========================================================")
	execution_results.start_time = Time.get_datetime_string_from_system()

	call_deferred("main")

func main():
	parse_arguments()

	if args.has("validate"):
		validate_existing_atlases()
	elif args.has("input") and args.has("grid"):
		process_sprite_sheet()
	else:
		show_usage()

	quit()

func parse_arguments():
	"""Parse command line arguments"""
	var raw_args = OS.get_cmdline_args()
	var parsing_our_args = false

	for i in range(raw_args.size()):
		var arg = raw_args[i]

		# Start parsing after -- separator
		if arg == "--":
			parsing_our_args = true
			continue

		if not parsing_our_args:
			continue

		# Parse key-value arguments
		if arg.begins_with("--"):
			var key = arg.substr(2)

			if key == "validate":
				args[key] = true
			elif i + 1 < raw_args.size() and not raw_args[i + 1].begins_with("--"):
				args[key] = raw_args[i + 1]
			else:
				args[key] = true

func show_usage():
	"""Show usage information"""
	print("""
Usage: godot --headless --script tools/sprite_processor.gd -- [options]

Options:
  --input <path>          Input sprite sheet image path (required)
  --grid <WxH>           Grid dimensions, e.g., "628x663" (required)
  --output <path>        Output SpriteFrames resource path (optional)
  --animation <name>     Animation name (default: "default")
  --fps <number>         Animation FPS (default: 10)
  --validate             Validate existing manual AtlasTextures

Examples:
  # Process sprite sheet into SpriteFrames
  godot --headless --script tools/sprite_processor.gd -- \\
    --input "assets/sprites/player_sheet.png" \\
    --grid "628x663" \\
    --output "resources/PlayerAnimations.tres"

  # Validate existing manual AtlasTextures
  godot --headless --script tools/sprite_processor.gd -- --validate

Current Project Manual AtlasTextures:
  • PlayerSniper.tscn: 100+ manual AtlasTexture entries
  • Time to automate: ~2 hours → ~2 minutes
""")

func process_sprite_sheet():
	"""Main sprite sheet processing function"""
	var input_path = args.get("input", "")
	var grid_str = args.get("grid", "")
	var output_path = args.get("output", "")
	var animation_name = args.get("animation", "default")
	var fps = float(args.get("fps", "10"))

	print("📋 Processing Configuration:")
	print("  Input: %s" % input_path)
	print("  Grid: %s" % grid_str)
	print("  Output: %s" % output_path)
	print("  Animation: %s @ %d FPS" % [animation_name, fps])
	print("")

	# Validate input file
	if not FileAccess.file_exists(input_path):
		add_error("Input file not found: %s" % input_path)
		return

	# Parse grid dimensions
	var grid_parts = grid_str.split("x")
	if grid_parts.size() != 2:
		add_error("Invalid grid format. Use WxH (e.g., '628x663')")
		return

	var grid_width = grid_parts[0].to_int()
	var grid_height = grid_parts[1].to_int()

	if grid_width <= 0 or grid_height <= 0:
		add_error("Invalid grid dimensions: %dx%d" % [grid_width, grid_height])
		return

	# Load and validate image
	var image = Image.load_from_file(input_path)
	if not image:
		add_error("Failed to load image: %s" % input_path)
		return

	var image_width = image.get_width()
	var image_height = image.get_height()

	print("🖼️ Image Analysis:")
	print("  Dimensions: %dx%d" % [image_width, image_height])
	print("  Frame Size: %dx%d" % [grid_width, grid_height])

	# Calculate grid layout
	var cols = image_width / grid_width
	var rows = image_height / grid_height
	var total_frames = cols * rows

	print("  Grid Layout: %dx%d (%d frames)" % [cols, rows, total_frames])
	print("")

	# Create texture from image
	var texture = ImageTexture.new()
	texture.set_image(image)

	# Generate AtlasTextures
	print("🔧 Generating AtlasTextures...")
	var atlas_textures: Array[AtlasTexture] = []

	for row in range(rows):
		for col in range(cols):
			var x = col * grid_width
			var y = row * grid_height
			var region = Rect2(x, y, grid_width, grid_height)

			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region

			atlas_textures.append(atlas)
			execution_results.processed_frames += 1

			print("  Frame %d: Region(%d, %d, %d, %d)" % [
				atlas_textures.size(), x, y, grid_width, grid_height
			])

	print("✅ Generated %d AtlasTextures" % atlas_textures.size())
	print("")

	# Create SpriteFrames resource
	if output_path != "":
		create_sprite_frames(atlas_textures, output_path, animation_name, fps)

	# Generate code snippet for manual integration
	generate_code_snippet(atlas_textures, input_path)

	execution_results.success = true

func create_sprite_frames(atlas_textures: Array, output_path: String, animation_name: String, fps: float):
	"""Create and save SpriteFrames resource"""
	print("📦 Creating SpriteFrames Resource...")

	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, fps)

	for atlas in atlas_textures:
		sprite_frames.add_frame(animation_name, atlas)

	# Ensure output directory exists
	var output_dir = output_path.get_base_dir()
	if output_dir != "" and not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.open("res://").make_dir_recursive(output_dir)

	# Save resource
	var result = ResourceSaver.save(sprite_frames, output_path)
	if result == OK:
		print("✅ SpriteFrames saved: %s" % output_path)
		print("  Animation: '%s' with %d frames @ %d FPS" % [
			animation_name, atlas_textures.size(), fps
		])
		execution_results.output_files.append(output_path)
	else:
		add_error("Failed to save SpriteFrames: %s" % output_path)

func generate_code_snippet(atlas_textures: Array, input_path: String):
	"""Generate code snippet for manual integration"""
	print("📝 Generated Code Snippet:")
	print("   (Copy-paste ready for manual scene integration)")
	print("")
	print("# AtlasTexture Resources for %s" % input_path.get_file())
	print("# Generated by SpriteProcessor - %s" % Time.get_datetime_string_from_system())
	print("")

	for i in range(atlas_textures.size()):
		var atlas = atlas_textures[i]
		var region = atlas.region
		print('[sub_resource type="AtlasTexture" id="AtlasTexture_frame_%d"]' % i)
		print('atlas = ExtResource("texture_resource_id")')
		print('region = Rect2(%d, %d, %d, %d)' % [region.position.x, region.position.y, region.size.x, region.size.y])
		print("")

	print("# SpriteFrames usage:")
	print('var sprite_frames = preload("res://path/to/generated.tres")')
	print('$AnimatedSprite2D.sprite_frames = sprite_frames')
	print('$AnimatedSprite2D.play("%s")' % args.get("animation", "default"))

func validate_existing_atlases():
	"""Validate existing manual AtlasTexture definitions"""
	print("🔍 Validating Existing Manual AtlasTextures...")
	print("")

	var scene_files: Array[String] = []
	find_scene_files("res://", scene_files)

	var total_manual_atlases = 0
	var automation_candidates: Array[String] = []

	for scene_path in scene_files:
		var file = FileAccess.open(scene_path, FileAccess.READ)
		if not file:
			continue

		var content = file.get_as_text()
		file.close()

		var atlas_count = content.count('[sub_resource type="AtlasTexture"')
		if atlas_count > 5:  # Threshold for automation candidate
			total_manual_atlases += atlas_count
			automation_candidates.append({
				"path": scene_path,
				"count": atlas_count
			})
			print("📄 %s: %d manual AtlasTextures" % [scene_path.get_file(), atlas_count])

	print("")
	print("📊 Validation Summary:")
	print("  Total Manual AtlasTextures: %d" % total_manual_atlases)
	print("  Automation Candidates: %d files" % automation_candidates.size())

	if automation_candidates.size() > 0:
		print("")
		print("💡 Automation Opportunities:")
		for candidate in automation_candidates:
			var time_saved = candidate.count * 2  # ~2 minutes per manual AtlasTexture
			print("  %s: %d atlases → ~%d minutes saved" % [
				candidate.path.get_file(),
				candidate.count,
				time_saved
			])

		var total_time_saved = total_manual_atlases * 2
		print("")
		print("🚀 Total Automation Potential: ~%d minutes (%d hours) saved" % [
			total_time_saved,
			total_time_saved / 60
		])

func find_scene_files(path: String, result: Array):
	"""Recursively find .tscn files"""
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path.path_join(file_name)

		if dir.current_is_dir() and not file_name.begins_with("."):
			find_scene_files(full_path, result)
		elif file_name.ends_with(".tscn"):
			result.append(full_path)

		file_name = dir.get_next()

func add_error(message: String):
	"""Add error to results and print"""
	execution_results.errors.append(message)
	print("❌ ERROR: %s" % message)

func _finalize():
	"""Print execution summary"""
	print("")
	print("🏁 Execution Summary:")
	print("  Start Time: %s" % execution_results.start_time)
	print("  Processed Frames: %d" % execution_results.processed_frames)
	print("  Output Files: %d" % execution_results.output_files.size())
	print("  Errors: %d" % execution_results.errors.size())
	print("  Success: %s" % ("✅" if execution_results.success else "❌"))

	if execution_results.output_files.size() > 0:
		print("")
		print("📁 Generated Files:")
		for file in execution_results.output_files:
			print("  %s" % file)

	if execution_results.errors.size() > 0:
		print("")
		print("❌ Errors:")
		for error in execution_results.errors:
			print("  %s" % error)