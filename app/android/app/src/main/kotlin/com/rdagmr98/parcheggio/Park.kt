package com.rdagmr98.parcheggio

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// Posizione dell'auto = posizione del telefono quando si stacca dal Bluetooth dell'MMI.
object Park {
    const val CAR = "Audi_MMI_5903"

    private fun prefs(c: Context) = c.getSharedPreferences("park", Context.MODE_PRIVATE)

    fun last(c: Context): String? = prefs(c).getString("p", null)

    fun json(l: Location): String = JSONObject()
        .put("lat", l.latitude).put("lon", l.longitude)
        .put("acc", l.accuracy.toInt()).put("time", System.currentTimeMillis()).toString()

    fun save(c: Context, l: Location): String = json(l).also { prefs(c).edit().putString("p", it).apply() }

    fun nav(lat: Double, lon: Double) = Intent(Intent.ACTION_VIEW,
        Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=walking"))
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    // Fix attuale entro timeoutMs, altrimenti l'ultima posizione nota più recente. done() è chiamata una volta sola.
    @SuppressLint("MissingPermission")
    fun locate(c: Context, timeoutMs: Long, done: (Location?) -> Unit) {
        val lm = c.getSystemService(LocationManager::class.java)
        val cancel = CancellationSignal()
        var sent = false
        fun finish(l: Location?) {
            if (sent) return
            sent = true
            cancel.cancel()
            done(l ?: listOf(LocationManager.FUSED_PROVIDER, LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }.maxByOrNull { it.time })
        }
        val provider = if (lm.hasProvider(LocationManager.FUSED_PROVIDER)) LocationManager.FUSED_PROVIDER else LocationManager.GPS_PROVIDER
        runCatching { lm.getCurrentLocation(provider, cancel, c.mainExecutor) { finish(it) } }.onFailure { finish(null) }
        Handler(Looper.getMainLooper()).postDelayed({ finish(null) }, timeoutMs)
    }

    fun notify(c: Context, l: Location) {
        val nm = c.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("park", "Auto parcheggiata", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), PendingIntent.FLAG_IMMUTABLE)
        val nav = PendingIntent.getActivity(c, 1, nav(l.latitude, l.longitude),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val ora = SimpleDateFormat("HH:mm", Locale.ITALY).format(Date())
        nm.notify(1, Notification.Builder(c, "park")
            .setSmallIcon(R.drawable.ic_park)
            .setColor(0xFFBB0A30.toInt())
            .setContentTitle("Auto parcheggiata")
            .setContentText("Alle $ora, precisione ${l.accuracy.toInt()} m")
            .setContentIntent(open).setAutoCancel(true)
            .addAction(Notification.Action.Builder(null, "Portami all'auto", nav).build())
            .build())
    }
}

class ParkReceiver : BroadcastReceiver() {
    @SuppressLint("MissingPermission")
    override fun onReceive(c: Context, i: Intent) {
        val d = i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java) ?: return
        if (runCatching { d.name }.getOrNull() != Park.CAR) return
        val r = goAsync() // broadcast di background: ~60 s di margine
        Park.locate(c, 20_000) { l ->
            // ponytail: sgancio Bluetooth in marcia scartato solo dalla velocità; se capita da fermi, rilevare il riaggancio entro 1-2 min
            if (l != null && !(l.hasSpeed() && l.speed > 4f)) {
                Park.save(c, l)
                Park.notify(c, l)
            }
            r.finish()
        }
    }
}
