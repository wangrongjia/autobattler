class_name TapTapComplianceGate
extends CanvasLayer

const LOGIN_SUCCESS := 500
const EXITED := 1000
const SWITCH_ACCOUNT := 1001
const PERIOD_RESTRICT := 1030
const DURATION_LIMIT := 1050
const AGE_LIMIT := 1100
const INVALID_CLIENT_OR_NETWORK_ERROR := 1200
const REAL_NAME_STOP := 9002
const PRIVACY_CONSENT_VERSION := 1
const PRIVACY_CONFIG_PATH := "user://privacy_consent.cfg"
const TAPSDK_PRIVACY_URL := "https://developer.taptap.cn/docs/sdk/start/agreement/"
const PRIVACY_POLICY_TEXT := """
[center][font_size=28][b]《战三国·弈定九州》隐私政策摘要[/b][/font_size][/center]

[b]运营者[/b]：王荣佳（品牌名称：序言工作室）
[b]联系方式[/b]：2738890457@qq.com

[b]一、游戏本地数据[/b]
游戏会在设备本地保存进度、设置、阵容、天赋和符文等数据。运营者不建设账号服务器，不会把这些本地存档上传到运营者服务器。

[b]二、TapSDK 处理的信息[/b]
为提供 TapTap 登录、实名认证与未成年人防沉迷服务，本游戏接入易玩（上海）网络科技有限公司提供的 TapSDK。只有在您点击“同意并继续”之后，游戏才会初始化 TapSDK。

TapSDK 在实现上述功能时可能处理：Android ID、广告标识符（GAID）、设备型号、系统版本、CPU 与内存信息、网络类型及网络状态、TapTap 用户标识（OpenID）、登录授权结果和实名认证/防沉迷状态。相关信息仅用于 TapTap 登录、身份认证、防沉迷、服务安全、兼容性判断与故障排查，不用于本游戏的广告投放或个性化画像。

[b]三、第三方 SDK[/b]
名称：TapSDK（TapTap 登录、合规认证）
提供方：易玩（上海）网络科技有限公司
使用目的：TapTap 账号授权登录、实名认证、未成年人防沉迷
隐私规则：[url=%s]TapSDK 隐私政策[/url]

[b]四、您的选择和权利[/b]
您可以选择“不同意并退出”，此时 TapSDK 不会由游戏初始化，且游戏不会进入。已经同意的用户可通过 Android 系统清除本应用存储数据或卸载游戏撤回本地授权；也可以通过上述邮箱联系我们处理访问、更正、删除或撤回授权等请求。撤回不会影响撤回前基于同意已经进行的处理。

[b]五、未成年人保护[/b]
未成年人应在监护人指导下阅读本说明。游戏会通过 TapSDK 合规认证执行实名认证、可玩时段和时长限制。

[b]六、政策更新[/b]
如信息处理方式发生重大变化，我们会更新本政策并重新征得您的同意。
""" % TAPSDK_PRIVACY_URL

var _plugin: Object
var _title_label: Label
var _status_label: Label
var _action_button: Button
var _policy_button: Button
var _decline_button: Button
var _privacy_dialog: AcceptDialog
var _action := ""
var _waiting_for_privacy := false


func _ready() -> void:
	layer = 1000
	_build_blocking_ui()
	if _has_privacy_consent():
		_start_sdk()
	else:
		_show_privacy_consent()


func _build_blocking_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.055, 0.98)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820.0, 430.0)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)

	_title_label = Label.new()
	_title_label.text = "登录与实名认证"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	content.add_child(_title_label)

	_status_label = Label.new()
	_status_label.text = "正在初始化 TapTap 服务……"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(730.0, 170.0)
	_status_label.add_theme_font_size_override("font_size", 23)
	content.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	content.add_child(buttons)

	_policy_button = Button.new()
	_policy_button.visible = false
	_policy_button.text = "查看完整隐私政策"
	_policy_button.custom_minimum_size = Vector2(220.0, 62.0)
	_policy_button.add_theme_font_size_override("font_size", 20)
	_policy_button.pressed.connect(_show_privacy_policy)
	buttons.add_child(_policy_button)

	_decline_button = Button.new()
	_decline_button.visible = false
	_decline_button.text = "不同意并退出"
	_decline_button.custom_minimum_size = Vector2(200.0, 62.0)
	_decline_button.add_theme_font_size_override("font_size", 20)
	_decline_button.pressed.connect(_on_privacy_declined)
	buttons.add_child(_decline_button)

	_action_button = Button.new()
	_action_button.visible = false
	_action_button.custom_minimum_size = Vector2(220.0, 62.0)
	_action_button.add_theme_font_size_override("font_size", 22)
	_action_button.pressed.connect(_on_action_pressed)
	buttons.add_child(_action_button)


func _has_privacy_consent() -> bool:
	var config := ConfigFile.new()
	if config.load(PRIVACY_CONFIG_PATH) != OK:
		return false
	return bool(config.get_value("privacy", "accepted", false)) \
		and int(config.get_value("privacy", "version", 0)) == PRIVACY_CONSENT_VERSION


func _save_privacy_consent() -> bool:
	var config := ConfigFile.new()
	config.set_value("privacy", "accepted", true)
	config.set_value("privacy", "version", PRIVACY_CONSENT_VERSION)
	config.set_value("privacy", "accepted_at", Time.get_datetime_string_from_system(false, true))
	return config.save(PRIVACY_CONFIG_PATH) == OK


func _show_privacy_consent() -> void:
	_waiting_for_privacy = true
	_title_label.text = "隐私保护提示"
	_status_label.text = (
		"开始游戏前，请阅读并同意《隐私政策》。\n\n"
		+ "为提供 TapTap 登录、实名认证与防沉迷服务，同意后将初始化 TapSDK。"
		+ "TapSDK 可能处理 Android ID、GAID、设备与系统信息、网络状态、TapTap 用户标识及认证结果。\n\n"
		+ "点击“同意并继续”前，本游戏不会初始化 TapSDK；若不同意，请退出游戏。"
	)
	_policy_button.visible = true
	_decline_button.visible = true
	_action = "privacy_consent"
	_action_button.visible = true
	_action_button.text = "同意并继续"


func _show_privacy_policy() -> void:
	if _privacy_dialog == null:
		_privacy_dialog = AcceptDialog.new()
		_privacy_dialog.title = "隐私政策与个人信息处理说明"
		_privacy_dialog.unresizable = false
		var policy_text := RichTextLabel.new()
		policy_text.bbcode_enabled = true
		policy_text.fit_content = false
		policy_text.custom_minimum_size = Vector2(820.0, 500.0)
		policy_text.text = PRIVACY_POLICY_TEXT
		policy_text.meta_clicked.connect(_on_privacy_link_clicked)
		_privacy_dialog.add_child(policy_text)
		add_child(_privacy_dialog)
		_privacy_dialog.get_ok_button().text = "我已阅读"
	_privacy_dialog.popup_centered(Vector2i(900, 620))


func _on_privacy_link_clicked(meta: Variant) -> void:
	var url := str(meta)
	if url.begins_with("https://developer.taptap.cn/"):
		OS.shell_open(url)


func _on_privacy_declined() -> void:
	get_tree().quit()


func _start_sdk() -> void:
	if OS.get_name() != "Android":
		queue_free()
		return

	if not Engine.has_singleton("TapTapCompliance"):
		_set_state("TapTap 原生插件未加载，当前版本不能进入游戏。", "退出游戏", "quit")
		return

	var client_id := str(ProjectSettings.get_setting("taptap/client_id", "")).strip_edges()
	var client_token := str(ProjectSettings.get_setting("taptap/client_token", "")).strip_edges()
	var enable_log := bool(ProjectSettings.get_setting("taptap/enable_log", false))
	var local_config := ConfigFile.new()
	if local_config.load("res://taptap.local.cfg") == OK:
		client_id = str(local_config.get_value("taptap", "client_id", client_id)).strip_edges()
		client_token = str(local_config.get_value("taptap", "client_token", client_token)).strip_edges()
		enable_log = bool(local_config.get_value("taptap", "enable_log", enable_log))
	if client_id.is_empty() or client_token.is_empty():
		_set_state("TapTap Client ID 或 Client Token 尚未配置。", "退出游戏", "quit")
		return

	_plugin = Engine.get_singleton("TapTapCompliance")
	_plugin.initialized.connect(_on_sdk_initialized)
	_plugin.login_result.connect(_on_login_result)
	_plugin.compliance_result.connect(_on_compliance_result)
	_plugin.initialize(
		client_id,
		client_token,
		enable_log,
		true
	)


func _on_sdk_initialized(success: bool, message: String) -> void:
	if not success:
		_set_state("TapTap 初始化失败：%s" % _safe_message(message), "重试", "initialize")
		return
	_set_state("正在登录 TapTap……")
	_plugin.loginAndStartCompliance()


func _on_login_result(success: bool, _open_id: String, message: String) -> void:
	if success:
		_set_state("登录成功，正在进行实名认证和防沉迷检查……")
	else:
		_set_state("TapTap 登录未完成：%s" % _safe_message(message), "重新登录", "login")


func _on_compliance_result(code: int, message: String) -> void:
	match code:
		LOGIN_SUCCESS:
			queue_free()
		EXITED:
			_set_state("实名认证已退出，请重新登录后继续。", "重新登录", "login")
		SWITCH_ACCOUNT:
			_plugin.logout()
			_set_state("账号已退出，请使用其他 TapTap 账号登录。", "切换账号", "login")
		PERIOD_RESTRICT:
			_set_state("当前时段不可进行游戏。", "退出游戏", "quit")
		DURATION_LIMIT:
			_set_state("今日可玩时长已用完。", "退出游戏", "quit")
		AGE_LIMIT:
			_set_state("当前账号不满足游戏适龄要求。", "退出游戏", "quit")
		INVALID_CLIENT_OR_NETWORK_ERROR:
			_set_state("认证请求失败，请检查网络后重试。%s" % _optional_detail(message), "重试认证", "compliance")
		REAL_NAME_STOP:
			_set_state("实名认证尚未完成。", "继续认证", "compliance")
		_:
			_set_state("认证未通过（代码 %d）。%s" % [code, _optional_detail(message)], "重试认证", "compliance")


func _set_state(message: String, button_text := "", action := "") -> void:
	_waiting_for_privacy = false
	_title_label.text = "登录与实名认证"
	_status_label.text = message
	_action = action
	_policy_button.visible = false
	_decline_button.visible = false
	_action_button.visible = not button_text.is_empty()
	_action_button.text = button_text


func _on_action_pressed() -> void:
	match _action:
		"privacy_consent":
			_action_button.disabled = true
			if not _save_privacy_consent():
				_action_button.disabled = false
				_status_label.text = "无法保存隐私授权状态，请检查设备存储后重试。"
				return
			_action_button.disabled = false
			_set_state("正在初始化 TapTap 服务……")
			_start_sdk()
		"initialize":
			_action_button.visible = false
			_set_state("正在重新初始化 TapTap 服务……")
			_start_sdk()
		"login":
			_action_button.visible = false
			_set_state("正在登录 TapTap……")
			_plugin.loginAndStartCompliance()
		"compliance":
			_action_button.visible = false
			_set_state("正在重新进行实名认证和防沉迷检查……")
			_plugin.startCompliance()
		"quit":
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for_privacy and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _safe_message(message: String) -> String:
	return "请重试或检查网络。" if message.strip_edges().is_empty() else message


func _optional_detail(message: String) -> String:
	return "" if message.strip_edges().is_empty() else "\n%s" % message
