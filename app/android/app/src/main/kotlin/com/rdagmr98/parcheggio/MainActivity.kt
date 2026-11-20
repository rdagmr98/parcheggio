package com.rdagmr98.parcheggio

import android.Manifest.permission.*
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "park").setMethodCallHandler { call, res ->
            when (call.method) {
                "get" -> res.success(Park.last(this))
                "here" -> Park.locate(this, 10_000) { res.success(it?.let(Park::json)) }
                "mark" -> Park.locate(this, 15_000) { res.success(it?.let { l -> Park.save(this, l) }) }
                "navigate" -> {
                    Park.last(this)?.let { JSONObject(it) }?.let { startActivity(Park.nav(it.getDouble("lat"), it.getDouble("lon"))) }
                    res.success(null)
                }
                "missing" -> res.success(missing())
                "fix" -> { fix(); res.success(null) }
                else -> res.notImplemented()
            }
        }
    }

    private fun has(p: String) = checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
    private fun battery() = getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)

    private fun missing() = buildList {
        if (!has(ACCESS_FINE_LOCATION)) add("posizione") else if (!has(ACCESS_BACKGROUND_LOCATION)) add("sempre")
        if (!has(BLUETOOTH_CONNECT)) add("bluetooth")
        if (!has(POST_NOTIFICATIONS)) add("notifiche")
        if (!battery()) add("batteria")
    }

    // Un passo alla volta: permessi di runtime, poi «Consenti sempre» (solo da impostazioni), poi batteria.
    private fun fix() {
        val ask = listOf(ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, BLUETOOTH_CONNECT, POST_NOTIFICATIONS).filterNot(::has)
        val pkg = Uri.fromParts("package", packageName, null)
        when {
            ask.isNotEmpty() -> requestPermissions(ask.toTypedArray(), 1)
            !has(ACCESS_BACKGROUND_LOCATION) -> startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
            !battery() -> startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg))
        }
    }
}
