extends Node2D
# ===========================
# メイン.
# ===========================

# ---------------------------------------
# preload.
# ---------------------------------------
const Point2 = preload("res://src/common/Point2.gd")
const PlayerObj = preload("res://src/player/Player.tscn")
const CrateObj = preload("res://src/crate/Crate.tscn")

# ---------------------------------------
# const.
# ---------------------------------------
const _DEBUG_UNDO_LOG = false # undoのログを表示するかどうか.

enum eState {
	MAIN, # メイン.
	STAGE_CLEAR, # ステージクリア.
}

# ---------------------------------------
# onready.
# ---------------------------------------
@onready var _player:Player = null
@onready var _ui_caption = $UILayer/Control/LabelCaption
@onready var _ui_step = $UILayer/Control/LabelStep
@onready var _ui_level = $UILayer/Control/LabelLevel
@onready var _ui_reset = $UILayer/Control/ResetButton
@onready var _ui_undo = $UILayer/Control/UndoButton
@onready var _ui_redo = $UILayer/Control/RedoButton
# キャンバスレイヤー.
@onready var _tile_layer = $TileLayer
@onready var _obj_layer = $ObjLayer
@onready var _crate_layer = $CrateLayer

@onready var _audio_steam_player = $AudioStreamPlayer2D
# ---------------------------------------
# vars.
# ---------------------------------------
var _timer = 0.0 # タイマー.
var _state = eState.MAIN # 状態.
var _tile_front:TileMap 

# ---------------------------------------
# private functions.
# ---------------------------------------
func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1480, 1000))
	Common.set_audio_stream_player(_audio_steam_player)

	# UIをいったん非表示にする.
	_ui_caption.visible = false
	_ui_step.visible = true
	_ui_undo.disabled = true
	_ui_redo.disabled = true

	# レベルを読み込む.
	var level_res = load("res://src/level/level_template.tscn")
	var level_obj = level_res.instantiate()
	_tile_layer.add_child(level_obj)
	# Frontのタイルマップを取得する.
	_tile_front = level_obj.get_node("./Front")
	
	# フィールドをセットアップする.
	_setup_level()

	# スタート地点が未設定の場合はランダムな位置にプレイヤーを出現させる.
	if _player == null:
		push_warning("プレイヤーの開始位置が設定されていません.")
		var p = Field.search_random_none()
		_create_player(p.x, p.y)
		
	# 共通モジュールをセットアップする.
	var layers = {
		"crate": _crate_layer,
	}
	Common.setup(_player, layers)

## タイル情報から生成されるオブジェクトをチェック＆生成.
func _create_obj(i:int, j:int, id:int) -> bool:
	match id:
		Field.eTile.START:
			# プレイヤー開始位置.
			_create_player(i, j)
			return true
		Field.eTile.CRATE1, Field.eTile.CRATE2, Field.eTile.CRATE3, Field.eTile.CRATE4:
			# 荷物.
			_create_crate(i, j, id)
			return true
	
	# 生成されていない.
	return false

## プレイヤーの生成.
func _create_player(i:int, j:int) -> void:
	_player = PlayerObj.instantiate()
	_player.set_pos(i, j, true)
	_obj_layer.add_child(_player)

## 荷物の生成.
func _create_crate(i:int, j:int, id:int) -> void:
	var crate = CrateObj.instantiate()
	# Spriteの更新があるので先に add_child() する.
	_crate_layer.add_child(crate)
	crate.setup(i, j, id)

## 更新.
func _process(delta:float) -> void:
	match _state:
		eState.MAIN:
			_update_main(delta)
		eState.STAGE_CLEAR:
			_update_stage_clear()
	
## 更新 > メイン.
func _update_main(delta:float) -> void:
	_timer += delta
	
	if Input.is_action_just_pressed("ui_reset"):
		# リセットボタン.
		var _ret = get_tree().change_scene("res://Main.tscn")
	
	# プレイヤーの更新.
	_player.proc(delta)
	
	# 荷物の更新.
	for crate in _crate_layer.get_children():
		crate.proc(delta)
	
	# UIの更新.
	_update_ui(delta)
	
	# ステージクリアしたかどうか.
	if Field.is_stage_clear():
		# ボアンを消す.
		_ui_redo.disabled = true
		_ui_undo.disabled = true
		_ui_reset.visible = false
		_state = eState.STAGE_CLEAR
		Common.play_sound("clear")

## 更新 > ステージクリア.
func _update_stage_clear() -> void:
	# キャプションを表示する.
	_ui_caption.visible = true
	_ui_caption.text = "STAGE CLEAR!"

	if Common.is_final_level():
		_ui_caption.text = "ALL LEVELS COMPLETED!"
	
	if Input.is_action_just_pressed("ui_accept"):
		# 次のステージに進む.
		Common.next_level()
		if Common.completed_all_level():
			# 全ステージクリアしたら最初から.
			Common.reset_level()
		var _ret = get_tree().change_scene_to_file("res://Main.tscn")

## 更新 > UI
func _update_ui(_delta:float) -> void:
	#_ui_step.visible = false
	var cnt_undo = Common.count_undo()
	if cnt_undo > 0:	
		_ui_undo.disabled = false
		#_ui_step.visible = true
		_ui_step.text = "歩数: %d"%cnt_undo
	else:
		_ui_undo.disabled = true
	
	if _DEBUG_UNDO_LOG:
		# 履歴をデバッグ用表示.
		for data in Common.get_undo_list():
			var d:Common.ReplayData = data
			var buf = "\n"
			var dir1 = Direction.to_name(d.player_dir)
			var dir2 = Direction.to_name(d.crate_dir)
			buf += "(%d %d)%s (%d %d)%s"%[d.player_pos.x, d.player_pos.y, dir1, d.crate_pos.x, d.crate_pos.y, dir2]
			_ui_step.text += buf
	
	if Common.count_redo() > 0:
		_ui_redo.disabled = false
	else:
		_ui_redo.disabled = true
		
## リセットボタンをクリック.
func _on_ResetButton_pressed() -> void:
	if _state == eState.MAIN:
		# ステージをやり直す.
		var _ret = get_tree().change_scene_to_file("res://Main.tscn")

## REDOボタンをクリック.
func _on_RedoButton_pressed():
	if _state == eState.MAIN:
		# redoを実行する.
		Common.redo()

## UNDOボタンをクリック.
func _on_undo_button_pressed():
	if _state == eState.MAIN:
		# undoを実行する.
		Common.undo()

func _clear_level_data():
	for y in range(Field.TILE_HEIGHT ):
		for x in range(Field.TILE_WIDTH):	
			_tile_front.set_cell(0, Vector2i(x, y), Field.eTile.NONE)

# フィールドをセットアップする.
func _setup_level():
	_clear_level_data()
	var level = Common.get_level()
	Field.setup(_tile_front)
	_ui_level.text = "ステージ: %d"%level

	var file_path = "res://level/%03d.json" % level
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_data = JSON.parse_string(file.get_as_text())
		file.close()

		var rows = json_data.get("rows", 0)
		var columns = json_data.get("columns", 0)
		var level_data = json_data.get("level", [])
		var x_offset = int((Field.TILE_WIDTH - columns) / 2)
		var y_offset = int((Field.TILE_HEIGHT - rows) / 2)
		
		for y in range(rows):
			for x in range(columns):
				var field_type = null
				match level_data[y][x]:
					"wall":
						field_type = Field.eTile.BLOCK
					"floor":
						field_type = Field.eTile.BLANK
					"goal":
						field_type = Field.eTile.POINT1
					"player":
						field_type = Field.eTile.START
					"box":
						field_type = Field.eTile.CRATE1
				_tile_front.set_cell(0, Vector2i(x + x_offset, y + y_offset), field_type, Vector2i(0, 0))
				if _create_obj(x + x_offset, y + y_offset, field_type):
					_tile_front.set_cell(0, Vector2i(x + x_offset, y + y_offset), Field.eTile.NONE)
