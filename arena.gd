extends Node3D

const NAMES := ["CARABINA", "PISTOLA", "ESCOPETA", "PRECISÃO"]
const CAPS := [30, 12, 6, 5]
const STOCK := [90, 48, 24, 25]
const DELAY := [0.105, 0.22, 0.78, 1.16]
const RELOAD := [1.55, 1.20, 0.62, 1.93]
const MUZZLE := [-0.69, -0.31, -0.75, -0.94]
var ammo: Array = CAPS.duplicate()
var reserve: Array = STOCK.duplicate()
var slot := 0
var requested := 0
var swap_left := 0.0
var reload_left := 0.0
var cooldown := 0.0
var aim := 0.0
var stride := 0.0
var kick := 0.0
var landing := 0.0
var flash_left := 0.0
var sway := Vector2.ZERO
var pitch := 0.0
var hp := 100.0
var wave := 0
var wave_wait := 0.0
var kills := 0
var enemies: Array[Dictionary] = []
var player := CharacterBody3D.new()
var capsule := CapsuleShape3D.new()
var collision := CollisionShape3D.new()
var camera := Camera3D.new()
var rig := Node3D.new()
var gun: Node3D
var left_hand: Node3D
var feed: Node3D
var flash := OmniLight3D.new()
var cross := Label.new()
var help := Label.new()
var sounds: Array[AudioStreamPlayer] = []
var world_mat: Dictionary = {}
var shot_pressed := false
var was_airborne := false
var first_motion := true
var jump_held := false
var sprint_pose := 0.0
var wall_pose := 0.0
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var right_hand: Node3D
var stance_bob := 0.0
var scope := ColorRect.new()
var scope_material := ShaderMaterial.new()
var bolt: Node3D
var bolt_clock := 0.0
const MAX_REINFORCEMENTS := 12
const MAX_ENEMY_TICKETS := 60
const SECTOR_RADIUS := 4.4
var sectors: Array[Dictionary] = []
var reinforcements := MAX_REINFORCEMENTS
var enemy_tickets := float(MAX_ENEMY_TICKETS)
var round_over := false
var hit_hud := Label.new()
var hit_clock := 0.0
var tactical_hud := Control.new()
var recoil_velocity := 0.0
var running_time := 0.0
var respawn_left := 0.0
var safe_time := 0.0
var damage_pulse := 0.0
var damage_screen := ColorRect.new()
var damage_material := ShaderMaterial.new()
var suppressed := [false,false,false,false]
var suppressor: Node3D
const SETTINGS := {
	"resolution": ["Escala de resolução", ["60%","75%","85%","100%"], 3],
	"fps": ["Limite de FPS", ["30","60","120","Sem limite"], 1],
	"vsync": ["Sincronização vertical", ["Desligada","Ligada"], 1],
	"fullscreen": ["Modo de tela", ["Janela","Tela cheia"], 0],
	"aa": ["Antisserrilhado MSAA", ["Desligado","2×","4×"], 0],
	"textures": ["Texturas de tecido", ["Simples","Camuflagem","Camuflagem filtrada"], 1],
	"details": ["Detalhes do cenário", ["Reduzidos","Completos"], 1],
	"particles": ["Partículas e impactos", ["Desligados","Baixos","Médios","Altos"], 2],
	"shadows": ["Sombras do sol", ["Desligadas","Curtas","Médias","Longas"], 2],
	"local_light": ["Luz do disparo", ["Desligada","Ligada"], 1],
	"lighting": ["Iluminação ambiente", ["Escura","Natural","Clara"], 1],
	"reflections": ["Reflexos do ambiente", ["Desligados","Céu","Céu e sonda local"], 0],
	"fog": ["Névoa à distância", ["Desligada","Suave","Densa"], 1],
	"post": ["Efeitos de tela ao tomar dano", ["Desligados","Reduzidos","Completos"], 2],
	"fov": ["Campo de visão vertical", ["65°","75°","85°","95°"], 1],
	"mouse": ["Sensibilidade do mouse", ["Muito baixa","Baixa","Padrão","Alta","Muito alta"], 2],
	"ads_mouse": ["Sensibilidade ao mirar", ["25%","40%","53%","70%","100%"], 2],
	"aim_mode": ["Botão direito para mirar", ["Segurar","Alternar"], 0],
	"crosshair": ["Retícula fora da mira", ["Desligada","Branca","Ciano","Verde"], 1],
	"motion": ["Balanço ao andar e correr", ["Desligado","Reduzido","Completo"], 2],
}
var settings: Dictionary = {}
var setting_controls: Dictionary = {}
var aim_toggled := false
var uniform_texture: Texture2D
var reflection_probe: ReflectionProbe
var map_details: Array[Node3D] = []
var graphics := PanelContainer.new()
var sun_light: DirectionalLight3D
var atmosphere_env: Environment

func mat(color: Color, metal := 0.0, rough := 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

func mesh(parent: Node3D, geometry: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = geometry
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = size
	return mesh(parent, geometry, material, at)

func tube(parent: Node3D, radius: float, length: float, at: Vector3, material: Material) -> MeshInstance3D:
	var geometry := CylinderMesh.new()
	geometry.top_radius = radius
	geometry.bottom_radius = radius
	geometry.height = length
	geometry.radial_segments = 16
	var instance := mesh(parent, geometry, material, at)
	instance.rotation.x = PI / 2.0
	return instance

func cover(at: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	box(body, size, Vector3.ZERO, material)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

func _ready() -> void:
	world_mat = {
		"concrete": mat(Color("#76766e")), "floor": mat(Color("#424849")),
		"tan": mat(Color("#8d7658")), "dark": mat(Color("#252b2d"), 0.25, 0.5),
		"steel": mat(Color("#677074"), 0.55, 0.46), "cloth": mat(Color("#555840")),
		"glove": mat(Color("#242623")), "brass": mat(Color("#af824b"), 0.5)
	}
	world_mat["uniform"] = uniform_material()
	uniform_texture = world_mat.uniform.albedo_texture
	var env := Environment.new()
	atmosphere_env = env
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("#55748d")
	atmosphere.sky_horizon_color = Color("#b6c4c9")
	atmosphere.ground_bottom_color = Color("#555650")
	atmosphere.ground_horizon_color = Color("#a1adaf")
	var sky_resource := Sky.new()
	sky_resource.sky_material = atmosphere
	env.sky = sky_resource
	env.background_mode = Environment.BG_SKY
	env.background_color = Color("#a2b6c2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d9e7ff")
	env.ambient_light_energy = 0.43
	env.fog_enabled = true
	env.fog_light_color = Color("#abbcc2")
	env.fog_density = 0.009
	var sky := WorldEnvironment.new()
	sky.environment = env
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_color = Color("#ffe3b9")
	sun.light_energy = 0.98
	sun.shadow_enabled = true
	add_child(sun)
	build_map()
	build_sectors()
	reflection_probe = ReflectionProbe.new()
	reflection_probe.size = Vector3(55,18,55)
	reflection_probe.position.y = 3.0
	reflection_probe.enable_shadows = false
	add_child(reflection_probe)
	add_child(player)
	player.collision_layer = 2
	player.collision_mask = 1
	collision.shape = capsule
	player.add_child(collision)
	set_height(1.78)
	player.add_child(camera)
	camera.current = true
	camera.near = 0.035
	camera.position.y = 1.62
	camera.add_child(rig)
	rig.add_child(flash)
	flash.omni_range = 3.0
	flash.light_color = Color("#ffb365")
	flash.visible = false
	build_sounds()
	build_hud()
	load_graphics()
	restart()

func uniform_material() -> StandardMaterial3D:
	var image := Image.create(256,256,false,Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 731
	noise.frequency = .067
	for y in range(256):
		for x in range(256):
			var pattern := noise.get_noise_2d(x,y)
			var c := Color("#666851")
			if pattern > .22:
				c = Color("#898367")
			elif pattern < -.19:
				c = Color("#393e34")
			var thread := .024 if (x+y)%3 == 0 else -.018
			image.set_pixel(x,y,c.lightened(thread) if thread > 0 else c.darkened(-thread))
	image.generate_mipmaps()
	var fabric := mat(Color.WHITE,0.0,.96)
	fabric.albedo_texture = ImageTexture.create_from_image(image)
	return fabric

func build_map() -> void:
	cover(Vector3(0,-0.25,0), Vector3(62,0.5,62), world_mat.floor)
	for side in [-1, 1]:
		cover(Vector3(side * 30,2,0), Vector3(1,4,61), world_mat.concrete)
		cover(Vector3(0,2,side * 30), Vector3(61,4,1), world_mat.concrete)
	for row in range(-2, 3):
		for side in [-1,1]:
			var p := Vector3(side * (6.5 + absf(row) * 2),1.45,row * 8.0)
			cover(p, Vector3(5.8,2.9,2.7), world_mat.tan if row % 2 == 0 else world_mat.dark)
			for rib in range(-5,6):
				for edge in [-1,1]:
					map_details.append(box(self,Vector3(0.06,2.75,0.08),p+Vector3(rib*.51,0,edge*1.37),world_mat.steel))
	for p in [Vector3(-3,0.58,-4),Vector3(4,0.58,-11),Vector3(2,0.58,8),Vector3(-5,0.58,14),Vector3(1,0.58,-21)]:
		cover(p,Vector3(2.8,1.16,.75),world_mat.concrete)
	for i in range(-14,15):
		box(self,Vector3(.10,.003,1.1),Vector3(0,.002,i*2),world_mat.tan)
	for side in [-1,1]:
		for i in range(12):
			box(self,Vector3(.06,.004,4.95),Vector3(side*3,.003,i*5-27.5),world_mat.steel)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(scope)
	scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope_shader := Shader.new()
	scope_shader.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float radius = length(p);
	float mask = smoothstep(0.356, 0.359, radius);
	float line = 1.0 - smoothstep(0.0006, 0.0017, min(abs(p.x),abs(p.y)));
	float fine = 1.0 - smoothstep(0.12, 0.27, radius);
	float ring = 1.0 - smoothstep(0.000, 0.003, abs(radius-0.351));
	COLOR = vec4(0.024,0.029,0.031,strength*max(mask,max(ring*.85,line*fine)));
}
"""
	scope_material.shader = scope_shader
	scope.material = scope_material
	layer.add_child(damage_screen)
	damage_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx := Shader.new()
	fx.code = """
shader_type canvas_item;
uniform sampler2D scene_color : hint_screen_texture, filter_linear_mipmap;
uniform float flash = 0.0;
uniform float critical = 0.0;
void fragment() {
	vec2 p = (SCREEN_UV-0.5)*2.0;
	float edge = smoothstep(0.27,1.18,length(p));
	float weight = clamp(critical*0.72+flash*0.46,0.0,1.0);
	vec3 base = textureLod(scene_color,SCREEN_UV,edge*weight*1.5).rgb;
	float gray = dot(base,vec3(.2126,.7152,.0722));
	base = mix(base,vec3(gray),critical*0.58);
	vec3 red = vec3(.34,.035,.030);
	COLOR = vec4(mix(base,red,edge*weight*.75),1.0);
}
"""
	damage_material.shader = fx
	damage_screen.material = damage_material
	damage_screen.hide()
	layer.add_child(tactical_hud)
	tactical_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tactical_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tactical_hud.draw.connect(draw_tactical_hud)
	for label in [cross,help,hit_hud]:
		layer.add_child(label)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
	hit_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hit_hud.position -= Vector2(9,16)
	hit_hud.add_theme_font_size_override("font_size",23)
	hit_hud.modulate.a = 0
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(8,14)
	cross.text = "+"
	cross.add_theme_font_size_override("font_size",20)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.position.y -= 65
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size",16)
	layer.add_child(graphics)
	graphics.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	graphics.offset_left = -278
	graphics.offset_top = -263
	graphics.offset_right = 278
	graphics.offset_bottom = 263
	var margin := MarginContainer.new()
	graphics.add_child(margin)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var title := Label.new()
	title.text = "VÍDEO, GRÁFICOS E MIRA"
	title.add_theme_font_size_override("font_size",21)
	content.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for key_name in SETTINGS:
		var entry: Array = SETTINGS[key_name]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = entry[0]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var control := OptionButton.new()
		control.custom_minimum_size.x = 155
		for option in entry[1]:
			control.add_item(option)
		control.item_selected.connect(change_setting.bind(key_name))
		row.add_child(control)
		rows.add_child(row)
		setting_controls[key_name] = control
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var restore := Button.new()
	restore.text = "Restaurar padrões"
	restore.pressed.connect(restore_settings)
	actions.add_child(restore)
	var resume := Button.new()
	resume.text = "Voltar"
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.pressed.connect(func(): graphics.hide())
	actions.add_child(resume)
	graphics.hide()

func quality(key_name: String) -> int:
	return int(settings.get(key_name,SETTINGS[key_name][2]))

func change_setting(index: int, key_name: String) -> void:
	settings[key_name] = clampi(index,0,SETTINGS[key_name][1].size()-1)
	if key_name == "aim_mode":
		aim_toggled = false
	apply_settings()
	save_settings()

func restore_settings() -> void:
	settings.clear()
	aim_toggled = false
	apply_settings()
	save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	for key_name in SETTINGS:
		config.set_value("settings",key_name,quality(key_name))
	config.save("user://settings.cfg")

func load_graphics() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	for key_name in SETTINGS:
		var entry: Array = SETTINGS[key_name]
		settings[key_name] = clampi(int(config.get_value("settings",key_name,entry[2])),0,entry[1].size()-1)
	apply_settings()

func apply_settings() -> void:
	for key_name in SETTINGS:
		setting_controls[key_name].select(quality(key_name))
	var shadows := quality("shadows")
	sun_light.shadow_enabled = shadows > 0
	sun_light.directional_shadow_max_distance = [20.0,24.0,43.0,75.0][shadows]
	atmosphere_env.fog_enabled = quality("fog") > 0
	atmosphere_env.fog_density = [.0,.009,.023][quality("fog")]
	atmosphere_env.ambient_light_energy = [.28,.43,.70][quality("lighting")]
	sun_light.light_energy = [.79,.98,1.22][quality("lighting")]
	var reflection_quality := quality("reflections")
	atmosphere_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if reflection_quality == 0 else Environment.REFLECTION_SOURCE_SKY
	reflection_probe.visible = reflection_quality == 2
	for name in ["steel","dark"]:
		world_mat[name].metallic_specular = 0.0 if reflection_quality == 0 else .60
	var textures := quality("textures")
	world_mat.uniform.albedo_texture = uniform_texture if textures > 0 else null
	world_mat.uniform.albedo_color = Color.WHITE if textures > 0 else Color("#666851")
	world_mat.uniform.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if textures == 2 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for detail in map_details:
		detail.visible = quality("details") > 0
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality("aa")]
	get_viewport().scaling_3d_scale = [.60,.75,.85,1.0][quality("resolution")]
	Engine.max_fps = [30,60,120,0][quality("fps")]
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if quality("vsync") > 0 else DisplayServer.VSYNC_DISABLED)
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if quality("fullscreen") > 0 else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	var cross_mode := quality("crosshair")
	cross.visible = cross_mode > 0
	cross.add_theme_color_override("font_color",[Color.WHITE,Color.WHITE,Color("#73dcff"),Color("#9bff82")][cross_mode])

func toggle_graphics() -> void:
	graphics.visible = not graphics.visible
	if graphics.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		shot_pressed = false

func build_sounds() -> void:
	# Bass frequency, tail duration, noise decay, and mechanical accent.
	var profiles := [
		Vector4(108,.20,48,.070), Vector4(184,.13,72,.041),
		Vector4(61,.38,21,.090), Vector4(76,.53,14,.37),
		Vector4(780,.12,85,.040), Vector4(520,.19,46,.082),
		Vector4(142,.16,60,.031), Vector4(205,.10,90,.020),
		Vector4(95,.23,43,.048), Vector4(114,.27,38,.081)
	]
	for i in range(profiles.size()):
		var profile: Vector4 = profiles[i]
		var sound := AudioStreamWAV.new()
		sound.format = AudioStreamWAV.FORMAT_16_BITS
		sound.mix_rate = 22050
		var frames := int(profile.y * sound.mix_rate)
		var data := PackedByteArray()
		data.resize(frames*2)
		var low := 0.0
		for frame in range(frames):
			var t := float(frame)/sound.mix_rate
			var noise := randf_range(-1,1)
			low = lerpf(low,noise,.14 if i == 2 else .31)
			var transient := noise*exp(-t*(145.0 if i == 1 else 93.0))*.56
			var body := (low*.54+sin(TAU*profile.x*t)*.38)*exp(-t*profile.z)
			var click := (noise*.42+sin(TAU*1320.0*t)*.31)*exp(-absf(t-profile.w)*215.0)
			var echo := low*exp(-maxf(0,t-.066)*24.0)*.16 if i == 3 and t > .066 else 0.0
			var sample := clampf(transient+body+click+echo,-.98,.98)
			data.encode_s16(frame*2,int(sample*32767*(.34 if i >= 6 else 1.0)))
		sound.data = data
		var voice := AudioStreamPlayer.new()
		voice.stream = sound
		voice.max_polyphony = 4
		add_child(voice)
		sounds.append(voice)

func play_sound(index: int) -> void:
	sounds[index].play()

func make_gun() -> void:
	if is_instance_valid(gun):
		rig.remove_child(gun)
		gun.queue_free()
	gun = Node3D.new()
	gun.scale = Vector3.ONE * .81
	rig.add_child(gun)
	var dark: Material = world_mat.dark
	var steel: Material = world_mat.steel
	var pistol := slot == 1
	var shotgun := slot == 2
	var sniper := slot == 3
	bolt = null
	box(gun,Vector3(.062,.069,.24 if pistol else .38),Vector3(0,0,-.04),dark)
	box(gun,Vector3(.049,.026,.24 if pistol else .29),Vector3(0,.028,-.075),steel)
	tube(gun,.014 if pistol else .019,.22 if pistol else .49,Vector3(0,.01,MUZZLE[slot]*.64),steel)
	tube(gun,.022,.048,Vector3(0,.01,MUZZLE[slot]+.022),dark)
	box(gun,Vector3(.049,.113,.063),Vector3(0,-.083,.046),dark).rotation.x = -.23
	if not pistol:
		box(gun,Vector3(.046,.049,.22),Vector3(0,-.016,.19),dark)
		box(gun,Vector3(.066,.064,.23),Vector3(0,-.012,-.32),dark)
		for i in range(8):
			box(gun,Vector3(.047,.008,.016),Vector3(0,.044,-.07-i*.039),steel)
		for i in range(6):
			for side in [-1,1]:
				box(gun,Vector3(.005,.018,.016),Vector3(side*.034,-.013,-.22-i*.035),steel)
	if sniper:
		box(gun,Vector3(.067,.059,.32),Vector3(0,-.023,.23),dark)
		box(gun,Vector3(.050,.055,.32),Vector3(0,-.025,-.33),dark)
		tube(gun,.017,.55,Vector3(0,.014,-.655),steel)
		for z in [-.16,-.31]:
			box(gun,Vector3(.035,.04,.032),Vector3(0,.059,z),steel)
		tube(gun,.024,.27,Vector3(0,.088,-.23),dark)
		tube(gun,.037,.086,Vector3(0,.088,-.361),dark)
		tube(gun,.030,.071,Vector3(0,.088,-.083),dark)
		tube(gun,.014,.028,Vector3(0,.118,-.22),steel).rotation.x = 0
		bolt = Node3D.new()
		gun.add_child(bolt)
		bolt.position = Vector3(.033,.008,.015)
		box(bolt,Vector3(.057,.012,.012),Vector3(.026,0,0),steel)
		rounded_limb(bolt,.012,.031,Vector3(.061,-.005,0),dark)
	if not pistol and not shotgun and not sniper:
		# Open reflex sight. The frame leaves the center ray unobstructed.
		var optic_z := -.17
		box(gun,Vector3(.052,.012,.084),Vector3(0,.049,optic_z),dark)
		for side in [-1,1]:
			box(gun,Vector3(.006,.049,.051),Vector3(side*.023,.075,optic_z),dark)
		box(gun,Vector3(.052,.006,.051),Vector3(0,.102,optic_z),dark)
		var dot := mat(Color("#ff623e"))
		dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box(gun,Vector3(.0027,.0027,.001),Vector3(0,.077,optic_z),dot)
	if shotgun:
		tube(gun,.018,.32,Vector3(0,-.032,-.43),dark)
	for side in [-1,1]:
		box(gun,Vector3(.009,.018,.021),Vector3(side*.016,.046,.055),steel)
	box(gun,Vector3(.011,.023,.012),Vector3(0,.046,MUZZLE[slot]+.048),steel)
	right_hand = make_hand(gun,Vector3(.019,-.082,.060),false)
	left_hand = make_hand(gun,Vector3.ZERO,true)
	left_arm = sleeve(gun)
	right_arm = sleeve(gun)
	feed = Node3D.new()
	gun.add_child(feed)
	if shotgun:
		tube(feed,.010,.048,Vector3.ZERO,world_mat.tan)
		tube(feed,.011,.013,Vector3(0,0,.023),world_mat.brass)
	else:
		box(feed,Vector3(.042,.118,.064),Vector3.ZERO,dark).rotation.x = -.10
		box(feed,Vector3(.047,.012,.069),Vector3(0,-.061,0),steel)
	for child in gun.find_children("*","MeshInstance3D",true,false):
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	suppressor = Node3D.new()
	gun.add_child(suppressor)
	suppressor.position = Vector3(0,.01,MUZZLE[slot]-.064)
	var can_length := .13 if pistol else .17
	tube(suppressor,.025 if pistol else .031,can_length,Vector3.ZERO,dark)
	tube(suppressor,.026 if pistol else .032,.009,Vector3(0,0,-can_length*.48),steel)
	for child in suppressor.get_children():
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	suppressor.visible = suppressed[slot]
	flash.position = Vector3(0,0,MUZZLE[slot]*.81)

func make_hand(parent: Node3D, at: Vector3, left: bool) -> Node3D:
	var hand := Node3D.new()
	parent.add_child(hand)
	hand.position = at
	var palm := SphereMesh.new()
	palm.radius = .035
	palm.height = .070
	mesh(hand,palm,world_mat.glove,Vector3.ZERO).scale = Vector3(.87,.78,1.23)
	for i in range(4):
		var digit := CapsuleMesh.new()
		digit.radius = .008
		digit.height = .039 - absf(i-1.5)*.004
		var finger := mesh(hand,digit,world_mat.glove,Vector3(i*.014-.021,.013,-.026))
		finger.rotation.x = -.95
	var thumb := CapsuleMesh.new()
	thumb.radius = .010
	thumb.height = .042
	mesh(hand,thumb,world_mat.glove,Vector3(.025 if left else -.025,.013,.010)).rotation.z = .65 if left else -.65
	return hand

func rounded_limb(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var geometry := CapsuleMesh.new()
	geometry.radius = radius
	geometry.height = height
	geometry.radial_segments = 16
	return mesh(parent,geometry,material,at)

func sleeve(parent: Node3D) -> MeshInstance3D:
	var geometry := CylinderMesh.new()
	geometry.top_radius = .036
	geometry.bottom_radius = .059
	geometry.height = 1
	geometry.radial_segments = 20
	return mesh(parent,geometry,world_mat.cloth,Vector3.ZERO)

func pose_sleeve(arm: MeshInstance3D, elbow: Vector3, wrist: Vector3) -> void:
	var axis := wrist-elbow
	arm.position = (elbow+wrist)*.5
	arm.quaternion = Quaternion(Vector3.UP,axis.normalized())
	arm.scale = Vector3(1,axis.length(),1)

func build_sectors() -> void:
	var disk := CylinderMesh.new()
	disk.top_radius = SECTOR_RADIUS
	disk.bottom_radius = SECTOR_RADIUS
	disk.height = .014
	var positions := [Vector3(0,0,4),Vector3(-3,0,-9),Vector3(3,0,-19)]
	for i in range(positions.size()):
		var center: Vector3 = positions[i]
		var flag := Label3D.new()
		flag.text = ["A","B","C"][i]
		flag.position = center+Vector3.UP*2.75
		flag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		flag.no_depth_test = true
		flag.font_size = 74
		add_child(flag)
		var tint := mat(Color("#f5bc75"))
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var ring := mesh(self,disk,tint,center+Vector3.UP*.013)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sectors.append({"name":flag.text,"center":center,"flag":flag,"tint":tint,"control":0.0,"owner":0,"contested":false})

func inside_sector(position: Vector3, center: Vector3) -> bool:
	return Vector2(position.x-center.x,position.z-center.z).length_squared() <= SECTOR_RADIUS*SECTOR_RADIUS

func update_sectors(dt: float) -> void:
	var friendly := 0
	for sector in sectors:
		var center: Vector3 = sector.center
		var present := inside_sector(player.position,center)
		var hostile := false
		for e in enemies:
			if inside_sector(e.body.position,center):
				hostile = true
				break
		sector.contested = present and hostile
		if present != hostile:
			sector.control = move_toward(sector.control,1.0 if present else -1.0,dt*.22)
			if sector.owner != 0 and sector.control*sector.owner <= 0:
				sector.owner = 0
			if absf(sector.control) >= 1.0:
				sector.owner = 1 if sector.control > 0 else -1
		friendly += int(sector.owner == 1)
	enemy_tickets = maxf(0.0,enemy_tickets-dt*(.55*friendly+(.60 if friendly >= 2 else 0.0)))
	if enemy_tickets <= 0:
		round_over = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		shot_pressed = false

func sector_color(owner: int) -> Color:
	return Color("#8bd3ff") if owner > 0 else (Color("#ff876c") if owner < 0 else Color("#d8e0e2"))

func show_sectors() -> void:
	for sector in sectors:
		var color := sector_color(sector.owner)
		sector.flag.modulate = color
		sector.tint.albedo_color = Color(color,.11)

func hud_text(at: Vector2, text: String, size: int, color := Color("#eff5f6")) -> void:
	var font := ThemeDB.fallback_font
	tactical_hud.draw_string(font,at+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0,0,.8))
	tactical_hud.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func draw_tactical_hud() -> void:
	var screen := tactical_hud.size
	if screen.x <= 0:
		return
	var panel := Color(.028,.044,.052,.79)
	var light := Color("#dce8ea")
	var blue := Color("#8bd3ff")
	var red := Color("#ff876c")
	var dim := Color(.62,.72,.74,.9)
	var map := Rect2(24,screen.y-202,176,176)
	tactical_hud.draw_rect(map,panel)
	tactical_hud.draw_rect(map,Color(.70,.82,.84,.30),false,1)
	for i in range(1,4):
		var n := i*44.0
		tactical_hud.draw_line(map.position+Vector2(n,0),map.position+Vector2(n,176),Color(.50,.66,.68,.16))
		tactical_hud.draw_line(map.position+Vector2(0,n),map.position+Vector2(176,n),Color(.50,.66,.68,.16))
	for row in range(-2,3):
		for side in [-1,1]:
			var block := Vector2(side*(6.5+absf(row)*2),row*8.0)
			tactical_hud.draw_rect(Rect2(map.get_center()+block*2.68-Vector2(7.8,3.6),Vector2(15.6,7.2)),Color(.56,.66,.65,.38))
	for sector in sectors:
		var point := map.get_center()+Vector2(sector.center.x,sector.center.z)*2.68
		tactical_hud.draw_circle(point,11,Color(sector_color(sector.owner),.17))
		hud_text(point+Vector2(-4,4),sector.name,11,sector_color(sector.owner))
	var point := map.get_center()+Vector2(player.position.x,player.position.z)*2.68
	var bearing := -player.rotation.y
	var direction := Vector2(sin(bearing),-cos(bearing))
	var right := direction.orthogonal()
	tactical_hud.draw_colored_polygon(PackedVector2Array([point+direction*7,point-direction*5+right*4,point-direction*5-right*4]),blue)
	hud_text(map.position+Vector2(8,-10),"CONQUISTA",13)
	hud_text(map.end+Vector2(10,-10),"ABATES %02d" % kills,13,dim)
	var center := screen.x*.5
	hud_text(Vector2(center-99,33),"%02d" % reinforcements,18,blue)
	hud_text(Vector2(center+76,33),"%02d" % ceili(enemy_tickets),18,red)
	for i in range(sectors.size()):
		var sector := sectors[i]
		var at := Vector2(center-33+i*33,25)
		var color := sector_color(sector.owner)
		tactical_hud.draw_rect(Rect2(at-Vector2(12,11),Vector2(24,23)),panel)
		tactical_hud.draw_rect(Rect2(at-Vector2(12,11),Vector2(24,23)),color,false)
		hud_text(at+Vector2(-5,5),sector.name,14,color)
		if inside_sector(player.position,sector.center):
			var progress := absf(sector.control)
			tactical_hud.draw_rect(Rect2(center-64,58,128,3),panel)
			tactical_hud.draw_rect(Rect2(center-64,58,128*progress,3),color)
			var status := "DISPUTADO" if sector.contested else ("DEFENDENDO" if sector.owner == 1 else "CAPTURANDO")
			hud_text(Vector2(center-50,53),status,12,color)
	var weapon := Vector2(screen.x-216,screen.y-27)
	hud_text(weapon+Vector2(0,-70),NAMES[slot]+("  ·  SILENCIADOR" if suppressed[slot] else ""),14,dim)
	hud_text(weapon+Vector2(0,-30),"%02d" % ammo[slot],37,light if ammo[slot] > 0 else red)
	hud_text(weapon+Vector2(64,-32),"/ %03d" % reserve[slot],18,dim)
	hud_text(weapon+Vector2(130,-32),"%03d" % ceili(hp),19,light)
	tactical_hud.draw_rect(Rect2(weapon+Vector2(126,-25),Vector2(66,3)),panel)
	tactical_hud.draw_rect(Rect2(weapon+Vector2(126,-25),Vector2(66*hp/100,3)),blue if hp > 30 else red)
	if reload_left > 0:
		hud_text(weapon,"RECARREGANDO",13,dim)

func restart() -> void:
	for e in enemies:
		e.body.queue_free()
	enemies.clear()
	reinforcements = MAX_REINFORCEMENTS
	enemy_tickets = float(MAX_ENEMY_TICKETS)
	round_over = false
	for sector in sectors:
		sector.control = 0.0
		sector.owner = 0
		sector.contested = false
	respawn()
	kills = 0
	wave = 0
	spawn_wave()

func respawn() -> void:
	player.position = Vector3(0,.04,13)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	pitch = 0.0
	camera.rotation = Vector3.ZERO
	hp = 100
	respawn_left = 0.0
	safe_time = 2.0
	damage_pulse = 0.0
	slot = 0
	requested = 0
	ammo = CAPS.duplicate()
	reserve = STOCK.duplicate()
	swap_left = 0
	reload_left = 0
	cooldown = 0
	kick = 0
	recoil_velocity = 0
	running_time = 0
	aim = 0
	sprint_pose = 0
	wall_pose = 0
	stance_bob = 0
	bolt_clock = 0
	scope_material.set_shader_parameter("strength",0.0)
	landing = 0
	sway = Vector2.ZERO
	jump_held = false
	was_airborne = false
	set_height(1.78)
	camera.position.y = 1.62
	make_gun()
	rig.position = Vector3(.225,-.225,-.55)
	rig.rotation = Vector3.ZERO
	update_weapon(0.0,0.0,false)
	hit_clock = 0
func spawn_wave() -> void:
	wave += 1
	wave_wait = 2.6
	hp = minf(100,hp+20)
	if wave > 1:
		for i in range(NAMES.size()):
			reserve[i] += CAPS[i]
	for i in range(mini(3+wave*2,16)):
		var body := CharacterBody3D.new()
		body.collision_layer = 4
		body.collision_mask = 1
		add_child(body)
		var p := Vector3(randf_range(-4,4),.05,-25+fmod(i*3.9,14))
		if player.position.distance_to(p) < 10:
			p.z = 25
		body.position = p
		var shape := CapsuleShape3D.new()
		shape.radius = .29
		shape.height = 1.8
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position.y = .9
		body.add_child(col)
		var uniform: Material = world_mat.uniform
		box(body,Vector3(.42,.52,.28),Vector3(0,1.18,0),uniform)
		box(body,Vector3(.40,.33,.30),Vector3(0,1.23,-.035),world_mat.cloth)
		for side in [-1,1]:
			box(body,Vector3(.055,.26,.022),Vector3(side*.121,1.34,-.182),world_mat.dark)
		for pouch in [-1,0,1]:
			box(body,Vector3(.091,.103,.052),Vector3(pouch*.102,1.17,-.199),world_mat.tan)
			box(body,Vector3(.091,.022,.057),Vector3(pouch*.102,1.211,-.201),world_mat.cloth)
		var head := SphereMesh.new()
		head.radius = .14
		head.height = .31
		mesh(body,head,mat(Color("#a78b72")),Vector3(0,1.62,0))
		mesh(body,head,uniform,Vector3(0,1.70,.024)).scale = Vector3(1.12,.67,1.12)
		rounded_limb(body,.124,.238,Vector3(0,1.572,-.014),world_mat.cloth).scale = Vector3(1,.52,1.04)
		box(body,Vector3(.196,.041,.026),Vector3(0,1.653,-.126),world_mat.dark)
		var legs: Array[Node3D] = []
		for side in [-1,1]:
			var leg := Node3D.new()
			body.add_child(leg)
			leg.position = Vector3(side*.112,.90,0)
			rounded_limb(leg,.087,.72,Vector3(0,-.36,0),uniform)
			rounded_limb(leg,.061,.15,Vector3(0,-.40,-.063),world_mat.dark).scale.z = .42
			box(leg,Vector3(.16,.13,.25),Vector3(0,-.81,-.042),world_mat.dark)
			legs.append(leg)
			rounded_limb(body,.068,.37,Vector3(side*.235,1.23,-.06),uniform).rotation.x = .40
			rounded_limb(body,.059,.29,Vector3(side*.203,1.14,-.245),uniform).rotation.x = 1.37
			rounded_limb(body,.042,.11,Vector3(side*.180,1.15,-.385),world_mat.glove).rotation.x = 1.37
			box(body,Vector3(.106,.118,.047),Vector3(side*.108,1.20,-.205),world_mat.cloth)
		box(body,Vector3(.06,.075,.51),Vector3(.19,1.18,-.29),world_mat.dark)
		enemies.append({"body":body,"legs":legs,"hp":100,"time":randf_range(.6,1.8),"step":0.0})

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		toggle_graphics()
		get_viewport().set_input_as_handled()
		return
	if graphics.visible:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			graphics.hide()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if hp <= 0 and not round_over:
					return
				if round_over:
					restart()
				elif hp <= 0:
					respawn()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				first_motion = true
				get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			shot_pressed = true
		if event.button_index == MOUSE_BUTTON_RIGHT and quality("aim_mode") == 1:
			aim_toggled = not aim_toggled
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_weapon(posmod(requested-1,NAMES.size()))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_weapon(posmod(requested+1,NAMES.size()))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			shot_pressed = false
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			match event.physical_keycode:
				KEY_1: select_weapon(0)
				KEY_2: select_weapon(1)
				KEY_3: select_weapon(2)
				KEY_4: select_weapon(3)
				KEY_R: begin_reload()
				KEY_T:
					if swap_left <= 0 and reload_left <= 0:
						suppressed[slot] = not suppressed[slot]
						suppressor.visible = suppressed[slot]
						play_sound(4)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if first_motion:
			first_motion = false
			return
		var movement: Vector2 = event.screen_relative
		if movement.length() > 250:
			return
		var mouse_scale: float = [.40,.68,1.0,1.35,1.85][quality("mouse")]
		var ads_scale: float = [.25,.40,.53,.70,1.0][quality("ads_mouse")]
		var sensitivity := .0021*mouse_scale*lerpf(1.0,ads_scale,aim)
		player.rotate_y(-movement.x*sensitivity)
		pitch = clampf(pitch-movement.y*sensitivity,-1.48,1.48)
		sway = (sway + movement*.0009).limit_length(.10)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		first_motion = true
		shot_pressed = false

func key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)

func set_height(height: float) -> void:
	capsule.height = height
	collision.position.y = height*.5

func can_stand() -> bool:
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP*1.04,player.global_position + Vector3.UP*1.80,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(dt: float) -> void:
	damage_pulse = move_toward(damage_pulse,0.0,dt*1.40)
	var post_strength: float = [0.0,.42,1.0][quality("post")]
	var critical := (1.0-smoothstep(0.0,38.0,hp))*post_strength
	damage_screen.visible = damage_pulse*post_strength > .01 or critical > .01
	damage_material.set_shader_parameter("flash",damage_pulse*post_strength)
	damage_material.set_shader_parameter("critical",critical)
	if hp <= 0 and not round_over and not graphics.visible and DisplayServer.window_is_focused():
		respawn_left = maxf(0.0,respawn_left-dt)
		if respawn_left <= 0.0:
			respawn()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			first_motion = true
	tactical_hud.queue_redraw()
	show_sectors()
	var active := not graphics.visible and not round_over and hp > 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	hit_clock = maxf(0,hit_clock-dt)
	hit_hud.modulate.a = minf(1.0,hit_clock*10.0) if active else 0.0
	help.visible = not active and not graphics.visible
	help.text = "WASD mover   •   Shift correr   •   Ctrl/C agachar   •   Espaço pular   •   RMB mirar   •   1–4 trocar   •   R recarregar   •   T silenciador   •   F10 gráficos"
	if not active:
		if round_over:
			help.text = "VITÓRIA   /   Clique para nova partida" if enemy_tickets <= 0 else "VOCÊ MORREU   /   DERROTA   /   Clique para nova partida"
		elif hp <= 0:
			help.text = "VOCÊ MORREU   /   Retorno em %d s" % ceili(respawn_left)
		else:
			help.text = "Capture e defenda A, B e C   /   Clique para jogar   /   Esc pausa\n" + help.text
		return
	safe_time = maxf(0.0,safe_time-dt)
	var crouch := key(KEY_CTRL) or key(KEY_C) or (capsule.height < 1.4 and not can_stand())
	var aim_input := aim_toggled if quality("aim_mode") == 1 else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var sight := aim_input and reload_left <= 0 and swap_left <= 0
	var direction := Vector3(float(key(KEY_D))-float(key(KEY_A)),0,float(key(KEY_S))-float(key(KEY_W))).normalized()
	var sprint := key(KEY_SHIFT) and direction.z < 0 and not (crouch or sight or reload_left > 0 or swap_left > 0)
	var pace := 2.2 if crouch else (2.9 if sight else (6.5 if sprint else 4.0))
	var target := player.basis * direction * pace
	var acceleration := 22.0 if player.is_on_floor() else 6.0
	player.velocity.x = move_toward(player.velocity.x,target.x,dt*acceleration)
	player.velocity.z = move_toward(player.velocity.z,target.z,dt*acceleration)
	player.velocity.y -= dt*18.0
	var jumping := key(KEY_SPACE)
	if player.is_on_floor() and jumping and not jump_held and not crouch:
		player.velocity.y = 5.3
	jump_held = jumping
	player.move_and_slide()
	set_height(1.14 if crouch else 1.78)
	if was_airborne and player.is_on_floor():
		landing = .060
	was_airborne = not player.is_on_floor()
	landing = move_toward(landing,0,dt*.38)
	var speed := Vector2(player.velocity.x,player.velocity.z).length()
	stride = fposmod(stride+dt*speed*2.8,TAU)
	aim = lerpf(aim,float(sight),1-exp(-dt*15))
	stance_bob = lerpf(stance_bob,minf(speed/5.0,1.0)*float(player.is_on_floor()),1-exp(-dt*12))
	var motion: float = [0.0,.46,1.0][quality("motion")]
	var bob := sin(stride)*stance_bob*motion
	var muzzle_ray := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*1.30,1)
	var wall := get_world_3d().direct_space_state.intersect_ray(muzzle_ray)
	var target_wall := 0.0
	if not wall.is_empty():
		target_wall = 1.0-smoothstep(.36,1.13,camera.global_position.distance_to(wall.position))
	wall_pose = lerpf(wall_pose,target_wall,1-exp(-dt*18))
	camera.position.y = lerpf(camera.position.y,(1.02 if crouch else 1.62)+bob*.018-landing,1-exp(-dt*15))
	camera.rotation.x = pitch
	var zoom := aim*(1.0-wall_pose)
	var base_fov: float = [65.0,75.0,85.0,95.0][quality("fov")]
	camera.fov = lerpf(base_fov,base_fov*.32 if slot == 3 else base_fov*.75,zoom)
	scope_material.set_shader_parameter("strength",smoothstep(.34,.93,zoom) if slot == 3 else 0.0)
	sway = sway.lerp(Vector2.ZERO,1-exp(-dt*13))
	update_weapon(dt,bob,sprint)
	update_enemies(dt)
	if hp > 0:
		update_sectors(dt)
	cross.modulate.a = 1.0-aim

func select_weapon(index: int) -> void:
	if index == requested:
		return
	requested = index
	reload_left = 0
	swap_left = .46

func begin_reload() -> void:
	if reload_left <= 0 and swap_left <= 0 and ammo[slot] < CAPS[slot] and reserve[slot] > 0:
		reload_left = RELOAD[slot]
		play_sound(4)

func update_weapon(dt: float, bob: float, sprint: bool) -> void:
	cooldown -= dt
	recoil_velocity += (-kick*285.0-recoil_velocity*27.0)*dt
	kick += recoil_velocity*dt
	flash_left -= dt
	flash.visible = flash_left > 0 and not suppressed[slot] and quality("local_light") > 0
	if swap_left > 0:
		var previous := swap_left
		swap_left = maxf(0,swap_left-dt)
		if previous > .23 and swap_left <= .23:
			slot = requested
			bolt_clock = 0
			make_gun()
			play_sound(4)
	if reload_left > 0:
		reload_left = maxf(0,reload_left-dt)
		if reload_left == 0:
			var amount := mini(1 if slot == 2 else CAPS[slot]-ammo[slot],reserve[slot])
			ammo[slot] += amount
			reserve[slot] -= amount
			play_sound(4)
			if slot == 2 and ammo[slot] < CAPS[slot] and reserve[slot] > 0:
				reload_left = RELOAD[slot]
	var firing := shot_pressed or (slot == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	shot_pressed = false
	if firing and cooldown <= 0 and swap_left <= 0 and not sprint:
		if slot == 2 and ammo[slot] > 0:
			reload_left = 0
		if reload_left <= 0:
			if ammo[slot] > 0:
				fire()
			else:
				begin_reload()
	var switch_progress := 1.0-swap_left/.46
	var lowering := smoothstep(0.0,.46,switch_progress)*(1.0-smoothstep(.54,1.0,switch_progress)) if swap_left > 0 else 0.0
	var reloading := reload_left > 0
	var progress: float = 1.0-reload_left/RELOAD[slot] if reloading else 0.0
	var reach := smoothstep(.02,.27,progress)*(1.0-smoothstep(.80,1.0,progress))
	var dip := smoothstep(.22,.49,progress)*(1.0-smoothstep(.62,.88,progress))
	sprint_pose = lerpf(sprint_pose,float(sprint),1-exp(-dt*12))
	running_time = fposmod(running_time+dt*11.5,TAU)
	var run_step: float = sin(running_time)*sprint_pose*[0.0,.46,1.0][quality("motion")]
	var focus := aim*(1.0-wall_pose)
	var sight_height := -.088 if slot == 3 else (-.077 if slot == 0 else -.052)
	var ready_pose := Vector3(lerpf(.225,0.0,focus),lerpf(-.225,sight_height*.81,focus),lerpf(-.55,-.60,focus))
	ready_pose += Vector3(
		(sway.x*.14+bob*.020)*(1.0-focus)+.075*sprint_pose+.019*run_step,
		(-sway.y*.16-absf(bob)*.013)*(1.0-focus)-.22*lowering-.077*reach-.11*sprint_pose-.14*wall_pose-landing*.32-.018*absf(run_step),
		kick+.12*wall_pose
	)
	rig.position = rig.position.lerp(ready_pose,1-exp(-dt*26))
	rig.rotation = Vector3(
		kick*.73-.62*lowering-.27*reach-.30*sprint_pose-.51*wall_pose+sway.y*(1.0-focus),
		-sway.x*(1.0-focus)+.19*sprint_pose-.28*wall_pose,
		.22*reach-.29*sprint_pose+.05*bob*(1.0-focus)+.037*run_step
	)
	gun.visible = not (slot == 3 and focus > .90)
	if is_instance_valid(bolt):
		var previous_bolt := bolt_clock
		bolt_clock = maxf(0.0,bolt_clock-dt)
		var cycle := sin(PI*bolt_clock/.78)
		bolt.position.z = .015+.11*cycle
		bolt.rotation.z = -.85*cycle
		right_hand.position = Vector3(.019,-.082,.060).lerp(bolt.position+Vector3(.051,-.021,.015),cycle*.94)
		right_hand.rotation.x = -.34*cycle
		if previous_bolt > .47 and bolt_clock <= .47:
			play_sound(5)
	var is_shell := slot == 2
	var seat := Vector3(0,-.079,.044 if slot == 1 else -.12)
	var shell_port := Vector3(-.025,-.067,-.12)
	if is_shell:
		var insertion := smoothstep(.40,.85,progress)
		feed.position = shell_port+Vector3(-.09,-.18,.14)*(1.0-insertion)
		feed.visible = reloading and progress > .12 and progress < .87
	else:
		feed.position = seat+Vector3(-.036,-.22,.083)*dip
		feed.rotation.x = -.22*dip
		feed.visible = true
	var grip := Vector3(-.024,-.033,-.015 if slot == 1 else -.325)
	left_hand.position = grip.lerp(feed.position+Vector3(-.022,-.012,.020),reach)
	left_hand.rotation = Vector3(.32-.56*reach,0,-.36*reach)
	pose_sleeve(left_arm,Vector3(-.24-.08*reach,-.30,.40),left_hand.position+Vector3(-.011,-.017,.027))
	pose_sleeve(right_arm,Vector3(.14,-.28,.40),right_hand.position+Vector3(.014,-.026,.027))

func fire() -> void:
	ammo[slot] -= 1
	cooldown = DELAY[slot]
	var impulse: float = [1.35,1.68,2.42,2.70][slot]
	kick = minf(kick+.010,.068)
	recoil_velocity = minf(recoil_velocity+impulse,3.2)
	flash_left = .042
	play_sound(slot+6 if suppressed[slot] else slot)
	if slot == 3:
		bolt_clock = .78
	var spread := .073 if slot == 2 else (lerpf(.018,0.0,aim) if slot == 3 else lerpf(.013,.003,aim))
	for pellet in range(8 if slot == 2 else 1):
		var local := Vector3(randf_range(-spread,spread),randf_range(-spread,spread),-1).normalized()
		var end := camera.global_position+camera.global_basis*local*120
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position,end,5)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			continue
		impact(hit.position,hit.normal)
		for i in range(enemies.size()-1,-1,-1):
			var e := enemies[i]
			if e.body != hit.collider:
				continue
			var damage: int = [34,42,18,85][slot]
			if suppressed[slot]:
				damage = roundi(damage*.78)
			var headshot: bool = hit.position.y-e.body.position.y >= 1.47
			e.hp -= 100 if headshot else damage
			hit_clock = .24 if e.hp <= 0 else .13
			hit_hud.text = "×"
			hit_hud.add_theme_color_override("font_color", Color("#ff7f64") if e.hp <= 0 else Color.WHITE)
			if e.hp <= 0:
				e.body.collision_layer = 0
				var body: CharacterBody3D = e.body
				var tween := create_tween()
				tween.tween_property(body,"rotation:x",1.46,.30)
				tween.tween_callback(body.queue_free).set_delay(1.0)
				enemies.remove_at(i)
				kills += 1
				enemy_tickets = maxf(0.0,enemy_tickets-1.0)
			break

func impact(at: Vector3, normal: Vector3) -> void:
	var count: int = [0,1,4,9][quality("particles")]
	if count == 0:
		return
	for i in range(count-1):
		var shard := box(self,Vector3(.020,.018,.036),at+normal*.04,world_mat.tan)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var scatter := normal*randf_range(.14,.46)+Vector3(randf_range(-.21,.21),randf_range(.05,.38),randf_range(-.21,.21))
		var flight := create_tween().set_parallel()
		flight.tween_property(shard,"position",shard.position+scatter,.20)
		flight.tween_property(shard,"scale",Vector3.ZERO,.25)
		flight.chain().tween_callback(shard.queue_free)
	var marker := box(self,Vector3(.036,.036,.036),at+normal*.022,world_mat.steel)
	var tween := create_tween()
	tween.tween_property(marker,"scale",Vector3.ZERO,.32)
	tween.tween_callback(marker.queue_free)

func update_enemies(dt: float) -> void:
	if enemies.is_empty():
		wave_wait -= dt
		if wave_wait <= 0:
			spawn_wave()
	for e in enemies:
		var body: CharacterBody3D = e.body
		var offset := player.position-body.position
		var flat := Vector3(offset.x,0,offset.z)
		var distance := flat.length()
		if distance > .05:
			body.rotation.y = atan2(-flat.x,-flat.z)
		var run := flat.normalized() * (2.3 if distance > 8 else 0.0)
		body.velocity = Vector3(run.x,body.velocity.y-dt*18,run.z)
		body.move_and_slide()
		e.step += body.get_real_velocity().length()*dt*5.8
		for i in range(2):
			e.legs[i].rotation.x = sin(e.step+i*PI)*.47 if run.length() > 0 else 0
		e.time -= dt
		if e.time <= 0 and distance < 24:
			e.time = randf_range(.8,1.9)
			var origin := body.global_position+Vector3.UP*1.45
			var ray := PhysicsRayQueryParameters3D.create(origin,camera.global_position,1)
			if safe_time <= 0 and get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				take_damage(randf_range(3,8))
				if hp <= 0:
					return

func take_damage(amount: float) -> void:
	if hp <= 0 or safe_time > 0.0:
		return
	hp = maxf(0,hp-amount)
	damage_pulse = minf(1.0,damage_pulse+.21+amount*.036)
	if hp <= 0:
		reinforcements -= 1
		respawn_left = 4.0
		round_over = reinforcements <= 0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		shot_pressed = false


