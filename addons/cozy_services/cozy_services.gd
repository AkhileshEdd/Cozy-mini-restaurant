@tool
extends EditorPlugin
## Adds the CozyServices Android plugin (ads, consent, billing) to Android
## Gradle builds. Build the .aar first with `./gradlew copyAarToAddon` in
## android_plugin/ (CI does this); without it the game still exports and
## simply runs without ads or the store.

var _export: CozyServicesExport


func _enter_tree() -> void:
	_export = CozyServicesExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class CozyServicesExport extends EditorExportPlugin:
	const AAR := "cozy_services/bin/cozy-services-release.aar"
	## Keep in sync with android_plugin/build.gradle.kts.
	const DEPENDENCIES := [
		"com.google.android.gms:play-services-ads:24.4.0",
		"com.google.android.ump:user-messaging-platform:3.2.0",
		"com.android.billingclient:billing:8.0.0",
	]
	## Google's sample AdMob app id, always used for debug builds.
	const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"

	func _get_name() -> String:
		return "CozyServices"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _has_aar() -> bool:
		return FileAccess.file_exists("res://addons/" + AAR)

	func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
		if not _supports_platform(get_export_platform()):
			return
		if not _has_aar():
			push_warning("CozyServices: %s is missing, exporting without ads and purchases. Run ./gradlew copyAarToAddon in android_plugin/." % AAR)
		elif not is_debug and _app_id(false) == TEST_APP_ID:
			push_warning("CozyServices: release build uses Google's test AdMob ids. Set cozy_services/admob/* in Project Settings before publishing.")

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR]) if _has_aar() else PackedStringArray()

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(DEPENDENCIES) if _has_aar() else PackedStringArray()

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, debug: bool) -> String:
		if not _has_aar():
			return ""
		return "\t\t<meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"%s\" />\n" % _app_id(debug)

	func _app_id(debug: bool) -> String:
		if debug:
			return TEST_APP_ID
		return str(ProjectSettings.get_setting("cozy_services/admob/android_app_id", TEST_APP_ID))
