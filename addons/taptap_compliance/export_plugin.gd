@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = TapTapAndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class TapTapAndroidExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "TapTapCompliance"
	const TAPSDK_VERSION := "4.10.7"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_name() -> String:
		return PLUGIN_NAME

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var variant := "debug" if debug else "release"
		return PackedStringArray([
			"taptap_compliance/bin/taptap-compliance-%s.aar" % variant,
		])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"com.taptap.sdk:tap-core:%s" % TAPSDK_VERSION,
			"com.taptap.sdk:tap-login:%s" % TAPSDK_VERSION,
			"com.taptap.sdk:tap-compliance:%s" % TAPSDK_VERSION,
		])
