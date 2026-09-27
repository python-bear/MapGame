extends Node
## Adaptive music (autoloaded as `Music`).
##
## Each level has a "set" of up to three stems in assets/music/, looping in sync:
##   <set>_calm.ogg     always playing (quietly)
##   <set>_tension.ogg  fades in as danger rises
##   <set>_danger.ogg   fades in when the player is in real trouble
##
## Levels call Music.play_set("level2") once, then Music.set_danger(0..1)
## whenever they like (every frame is fine). Sound effects: Music.sfx("bell").
## Regenerate or add sets with tools/gen_music.py.

const LAYERS := ["calm", "tension", "danger"]

## Overall loudness of each set's calm layer — the early dream is faint.
const SET_GAIN := {"menu": 0.55, "level1": 0.5, "level2": 0.8, "level3": 0.45}

var music_volume := 0.8
var sfx_volume := 0.9

var _players := {}          # layer -> AudioStreamPlayer (current set)
var _set := ""
var _danger := 0.0
var _target := 0.0
var _fade_in := 0.0         # 0..1 while a new set fades up
var _sfx_cache := {}
var _sfx_pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	var cfg := ConfigFile.new()
	if cfg.load(Game.SETTINGS_PATH) == OK:
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)


## Switch to another set, crossfading. Calling it with the current set does nothing.
func play_set(set_name: String, fade := 2.0) -> void:
	if set_name == _set:
		return
	var old := _players
	_players = {}
	_set = set_name
	_danger = 0.0
	_target = 0.0
	_fade_in = 0.0
	for layer in LAYERS:
		var path := "res://assets/music/%s_%s.ogg" % [set_name, layer]
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStreamOggVorbis
		stream.loop = true
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = -80.0
		add_child(p)
		_players[layer] = p
	for p: AudioStreamPlayer in _players.values():
		p.play()   # all at once so the stems stay in sync
	for p: AudioStreamPlayer in old.values():
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade)
		tw.tween_callback(p.queue_free)
	var tw := create_tween()
	tw.tween_property(self, "_fade_in", 1.0, fade)


func stop(fade := 2.0) -> void:
	for p: AudioStreamPlayer in _players.values():
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade)
		tw.tween_callback(p.queue_free)
	_players = {}
	_set = ""


## 0 = calm, ~0.4 = uneasy, ~0.75 = hunted, 1 = it has you.
func set_danger(d: float) -> void:
	_target = clampf(d, 0.0, 1.0)


func _process(delta: float) -> void:
	# rise quickly, settle slowly
	var rate := 1.6 if _target > _danger else 0.35
	_danger = move_toward(_danger, _target, rate * delta)
	var base: float = SET_GAIN.get(_set, 0.7) * music_volume * _fade_in
	var gains := {
		"calm": 1.0 - 0.45 * smoothstep(0.6, 1.0, _danger),
		"tension": smoothstep(0.12, 0.5, _danger) * 1.1,
		"danger": smoothstep(0.55, 0.9, _danger) * 1.2,
	}
	for layer in _players:
		var g: float = gains[layer] * base
		var p: AudioStreamPlayer = _players[layer]
		p.volume_db = linear_to_db(maxf(g, 0.0001))


func sfx(name: String, volume := 1.0, pitch := 1.0) -> void:
	if not _sfx_cache.has(name):
		var path := "res://assets/sfx/%s.ogg" % name
		_sfx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _sfx_cache[name]
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_db = linear_to_db(maxf(volume * sfx_volume, 0.0001))
			p.play()
			return


func set_music_volume(v: float) -> void:
	music_volume = v
	_save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Game.SETTINGS_PATH)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(Game.SETTINGS_PATH)
