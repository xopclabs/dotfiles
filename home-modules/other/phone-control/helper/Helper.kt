package dev.phonecontrol.debugginghelper

import android.Manifest.permission.*
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.database.ContentObserver
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.location.LocationManager
import android.net.*
import android.net.wifi.WifiManager
import android.os.*
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.*

private const val ADB_WIFI = "adb_wifi_enabled"
private const val AP_STATE = "android.net.wifi.WIFI_AP_STATE_CHANGED"
private val Context.preferences get() = getSharedPreferences("settings", Context.MODE_PRIVATE)
private val Context.automatic get() = preferences.getBoolean("automatic", false)
private val Context.networks get() = preferences.getStringSet("trusted_ssids", emptySet()) ?: emptySet()
private fun Context.granted(permission: String) =
    checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
private fun Context.startRecovery() = startForegroundService(Intent(this, RecoveryService::class.java))
private fun Context.adbEnabled() = Settings.Global.getInt(contentResolver, ADB_WIFI, 0) == 1
private fun Context.setAdb(enabled: Boolean) =
    check(Settings.Global.putInt(contentResolver, ADB_WIFI, if (enabled) 1 else 0)) { "Setting rejected" }

class MainActivity : Activity() {
    private lateinit var status: TextView
    private lateinit var detail: TextView
    private lateinit var result: TextView
    private lateinit var enable: Button
    private val handler = Handler(Looper.getMainLooper())
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun color(name: String) = getColor(resources.getIdentifier(name, "color", packageName))
    private fun rounded(fill: Int, radius: Int = 20, border: Boolean = false) = GradientDrawable().apply {
        setColor(fill)
        cornerRadius = dp(radius).toFloat()
        if (border) setStroke(dp(1), color("border"))
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            isVerticalScrollBarEnabled = false
            setBackgroundColor(color("background"))
            addView(layout)
        }
        setContentView(scroll)
        scroll.setOnApplyWindowInsetsListener { _, insets ->
            val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            layout.setPadding(dp(20) + bars.left, dp(24) + bars.top, dp(20) + bars.right, dp(24) + bars.bottom)
            insets
        }
        scroll.requestApplyInsets()
        fun space(parent: LinearLayout, height: Int = 12) = parent.addView(View(this),
            LinearLayout.LayoutParams(1, dp(height)))
        fun label(parent: LinearLayout, text: String, size: Float = 14f, strong: Boolean = false) = TextView(this).apply {
            this.text = text
            textSize = size
            setTextColor(color(if (strong) "ink" else "muted"))
            typeface = Typeface.create(if (strong) "sans-serif-medium" else "sans-serif", Typeface.NORMAL)
            setLineSpacing(dp(3).toFloat(), 1f)
            parent.addView(this)
        }
        fun card(title: String) = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(20))
            background = rounded(color("surface"))
            layout.addView(this, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(16) })
            label(this, title, 18f, true)
            space(this, 12)
        }
        fun button(parent: LinearLayout, text: String, primary: Boolean = false, action: () -> Unit) = Button(this).apply {
            this.text = text
            textSize = 14f
            isAllCaps = false
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            minHeight = dp(48)
            minimumHeight = dp(48)
            setPadding(dp(12), dp(8), dp(12), dp(8))
            val fill = color(if (primary) "accent" else "accent_surface")
            setTextColor(ColorStateList(arrayOf(intArrayOf(-android.R.attr.state_enabled), intArrayOf()),
                intArrayOf(color("muted"), color(if (primary) "surface" else "accent"))))
            background = RippleDrawable(ColorStateList.valueOf(color("border")), rounded(fill, 14), null)
            setOnClickListener { action() }
            parent.addView(this, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(10) })
        }
        fun toggle(parent: LinearLayout, text: String, key: String) = Switch(this).apply {
            this.text = text
            textSize = 15f
            setTextColor(color("ink"))
            isChecked = preferences.getBoolean(key, false)
            minHeight = dp(52)
            switchPadding = dp(12)
            parent.addView(this, LinearLayout.LayoutParams(-1, -2))
        }
        val header = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            layout.addView(this)
        }
        header.addView(ImageView(this).apply {
            setImageResource(resources.getIdentifier("ic_phone", "drawable", packageName))
            imageTintList = ColorStateList.valueOf(color("accent"))
            background = rounded(color("accent_surface"), 18)
            setPadding(dp(12), dp(12), dp(12), dp(12))
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(dp(56), dp(56)).apply { marginEnd = dp(16) })
        val heading = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; header.addView(this) }
        label(heading, "Phone Control", 27f, true)
        label(heading, "Ready when you need it", 14f)
        space(layout, 24)
        val connection = card("Wireless debugging")
        status = label(connection, "", 23f, true)
        detail = label(connection, "", 13f)
        space(connection, 8)
        label(connection, "Encrypted access for your paired PC. A setting being on doesn't confirm a PC connection.")
        result = label(connection, "").apply {
            setTextColor(color("accent"))
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        enable = button(connection, "Enable debugging", true) {
            handler.removeCallbacksAndMessages(null)
            result.text = try {
                setAdb(true)
                repeat(10) { handler.postDelayed({ refresh() }, it * 500L) }
                "Write accepted. Verify the PC reconnects."
            } catch (_: SecurityException) {
                "Permission denied. Grant WRITE_SECURE_SETTINGS from ADB first."
            } catch (e: RuntimeException) { "Write failed: ${e.javaClass.simpleName}" }
        }
        button(connection, "Refresh status") { refresh() }
        button(connection, "Developer settings") { open(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)) }
        val recovery = card("Automatic recovery")
        val auto = toggle(recovery, "Recover on trusted connections", "automatic")
        label(recovery, "Alerts only if debugging stays off on a trusted connection. Starts after the first unlock following a reboot.")
        space(recovery)
        label(recovery, "Trusted Wi-Fi", 14f, true)
        label(recovery, "One exact network name per line. Stored only on this phone.", 13f)
        val names = EditText(this).apply {
            hint = "Trusted SSIDs, one per line"
            minLines = 2
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            setText(networks.sorted().joinToString("\n"))
            setTextColor(color("ink"))
            setHintTextColor(color("muted"))
            textSize = 14f
            typeface = Typeface.MONOSPACE
            background = rounded(color("background"), 12, true)
            setPadding(dp(14), dp(12), dp(14), dp(12))
            recovery.addView(this, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(12); bottomMargin = dp(12) })
        }
        val hotspot = toggle(recovery, "Trust this phone's hotspot", "own_hotspot")
        label(recovery, "Experimental · Android may reject debugging in hotspot-only mode.", 13f)
        button(recovery, "Save settings", true) {
            save(names, hotspot, auto)
        }
        val setup = card("Permissions & privacy")
        label(setup, "Android needs location access to read Wi-Fi names in the background. " +
            "This app never reads coordinates and has no internet permission.")
        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = if (arrayOf(ACCESS_FINE_LOCATION, ACCESS_BACKGROUND_LOCATION,
                POST_NOTIFICATIONS).all { granted(it) }) View.GONE else View.VISIBLE
        }
        button(setup, "Manage permissions") {
            controls.visibility = if (controls.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        }
        button(setup, "Background notification settings") {
            open(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, "recovery"))
        }
        setup.addView(controls)
        button(controls, "Allow Wi-Fi detection & notifications") {
            requestPermissions(arrayOf(ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, POST_NOTIFICATIONS), 1)
        }
        button(controls, "Location → Allow all the time") {
            open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        }
        space(layout, 4)
        label(layout, "For reliable reconnection, use a stable per-network MAC on home Wi-Fi. " +
            "Trusted names are a convenience boundary, not proof of network identity.", 12f)
    }

    private fun save(names: EditText, hotspot: Switch, auto: Switch) {
        val trusted = names.text.toString().lineSequence().map { it.trim() }.filter { it.isNotEmpty() }.toSet()
        when {
            auto.isChecked && trusted.isEmpty() && !hotspot.isChecked ->
                result.text = "Add a trusted connection before enabling automatic recovery."
            auto.isChecked && !arrayOf(WRITE_SECURE_SETTINGS, ACCESS_FINE_LOCATION,
                ACCESS_BACKGROUND_LOCATION, POST_NOTIFICATIONS).all { granted(it) } ->
                result.text = "Grant the required permissions before enabling automatic recovery."
            else -> {
                preferences.edit().putStringSet("trusted_ssids", trusted)
                    .putBoolean("own_hotspot", hotspot.isChecked).putBoolean("automatic", auto.isChecked).apply()
                try {
                    if (auto.isChecked) startRecovery() else stopService(Intent(this, RecoveryService::class.java))
                    result.text = "Settings saved. Automatic recovery is ${if (auto.isChecked) "active" else "off"}."
                } catch (e: RuntimeException) {
                    preferences.edit().putBoolean("automatic", false).apply()
                    auto.isChecked = false
                    result.text = "Could not start recovery: ${e.javaClass.simpleName}"
                }
            }
        }
        refresh()
        Toast.makeText(this, result.text, Toast.LENGTH_LONG).show()
    }

    private fun open(intent: Intent) {
        try { startActivity(intent) }
        catch (_: RuntimeException) { result.text = "Could not open settings. Open them manually." }
    }

    private fun refresh() {
        val allowed = granted(WRITE_SECURE_SETTINGS)
        status.text = if (adbEnabled()) "Setting is on" else "Setting is off"
        status.setTextColor(color(if (adbEnabled()) "accent" else "muted"))
        detail.text = if (allowed) "ADB permission granted · ${if (automatic) "Auto recovery active" else "Manual recovery"}"
            else "One-time ADB permission required"
        enable.isEnabled = allowed
    }

    override fun onResume() { super.onResume(); refresh() }
    override fun onPause() { handler.removeCallbacksAndMessages(null); super.onPause() }
}

class RecoveryService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val notifications get() = getSystemService(NotificationManager::class.java)
    private val connectivity get() = getSystemService(ConnectivityManager::class.java)
    private var hotspot = false
    private var registered = false
    private var failedContext = ""
    private var lastProblem = ""
    private val settingObserver = object : ContentObserver(handler) {
        override fun onChange(selfChange: Boolean) {
            if (adbEnabled()) { lastProblem = ""; notifications.cancel(2) }
            else schedule()
        }
    }
    private val evaluate = object : Runnable {
        override fun run() { reconcile(); handler.postDelayed(this, 30_000) }
    }
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = schedule()
        override fun onLost(network: Network) = schedule()
        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = schedule()
    }
    private val wifiEvents = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == AP_STATE) hotspot = intent.getIntExtra("wifi_state", 11) == 13
            schedule()
        }
    }

    private fun schedule() { handler.removeCallbacks(evaluate); handler.postDelayed(evaluate, 2_000) }

    override fun onCreate() {
        super.onCreate()
        notifications.createNotificationChannel(NotificationChannel("recovery", "Background recovery service",
            NotificationManager.IMPORTANCE_MIN))
        notifications.createNotificationChannel(NotificationChannel("failures", "Wireless debugging needs attention",
            NotificationManager.IMPORTANCE_DEFAULT))
        // Mandatory foreground-service entry; users may hide this channel without blocking failure alerts.
        startForeground(1, notification("recovery", "Automatic recovery", "Watching trusted connections."))
        contentResolver.registerContentObserver(Settings.Global.getUriFor(ADB_WIFI), false, settingObserver)
        try {
            connectivity.registerNetworkCallback(NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build(), callback)
            registered = true
        } catch (_: RuntimeException) {
            android.util.Log.w("PhoneControl", "Wi-Fi callback unavailable; periodic checks remain active")
        }
        // These are protected system broadcasts; EXPORTED permits delivery from the Wi-Fi process.
        val filter = IntentFilter(AP_STATE).apply { addAction(WifiManager.NETWORK_STATE_CHANGED_ACTION) }
        registerReceiver(wifiEvents, filter, RECEIVER_EXPORTED)
        val sticky = registerReceiver(null, IntentFilter(AP_STATE))
        hotspot = sticky?.getIntExtra("wifi_state", 11) == 13
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!automatic) { stopSelf(); return START_NOT_STICKY }
        failedContext = ""
        schedule()
        return START_STICKY
    }

    @Suppress("DEPRECATION")
    private fun reconcile(verify: Boolean = false) {
        if (!automatic) { stopSelf(); return }
        val permission = granted(ACCESS_FINE_LOCATION) && granted(ACCESS_BACKGROUND_LOCATION)
        val location = getSystemService(LocationManager::class.java).isLocationEnabled
        val wifi = if (permission && location) getSystemService(WifiManager::class.java).connectionInfo else null
        val ssid = wifi?.takeIf { it.networkId != -1 }?.ssid?.removeSurrounding("\"")
            ?.takeUnless { it == WifiManager.UNKNOWN_SSID }
        val trustedWifi = ssid != null && ssid in networks
        val trustedHotspot = hotspot && preferences.getBoolean("own_hotspot", false)
        val connection = if (trustedWifi) "wifi:$ssid" else "hotspot"
        if (!trustedWifi && !trustedHotspot) {
            failedContext = ""
            // Do not disable debugging enabled independently by the user.
            if (preferences.getBoolean("managed", false)) {
                try { setAdb(false); preferences.edit().putBoolean("managed", false).apply() }
                catch (_: RuntimeException) {
                    android.util.Log.w("PhoneControl", "Could not disable debugging outside trusted Wi-Fi")
                }
            }
            lastProblem = ""
            notifications.cancel(2)
            return
        }
        if (adbEnabled()) { recovered(); return }
        if (connection == failedContext) {
            if (verify) report(if (trustedHotspot && !trustedWifi) "Android rejected hotspot-only debugging."
                else "Debugging is still off on trusted Wi-Fi. Tap to open developer settings.")
            return
        }
        try {
            setAdb(true)
            preferences.edit().putBoolean("managed", true).apply()
            failedContext = connection
            // Re-check current trust and state, not the network captured before this delay.
            handler.postDelayed({ reconcile(verify = true) }, 5_000)
        } catch (_: RuntimeException) {
            failedContext = connection
            report("Cannot enable debugging. Check the ADB permission and developer settings.")
        }
    }

    private fun recovered() {
        failedContext = ""
        lastProblem = ""
        notifications.cancel(2)
    }

    private fun notification(channel: String, title: String, text: String, helper: Boolean = channel == "recovery"):
        Notification {
        val target = if (helper) Intent(this, MainActivity::class.java)
            else Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
        val action = PendingIntent.getActivity(this, if (channel == "recovery") 1 else 2, target,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, channel)
            .setSmallIcon(resources.getIdentifier("ic_phone", "drawable", packageName))
            .setContentTitle(title).setContentText(text).setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(action).setOngoing(channel == "recovery").build()
    }

    private fun report(text: String) {
        if (text != lastProblem) {
            lastProblem = text
            notifications.notify(2, notification("failures", "Wireless debugging needs attention", text))
        }
    }

    override fun onDestroy() {
        notifications.cancel(2)
        contentResolver.unregisterContentObserver(settingObserver)
        handler.removeCallbacksAndMessages(null)
        if (registered) connectivity.unregisterNetworkCallback(callback)
        unregisterReceiver(wifiEvents)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED) && context.automatic)
            context.startRecovery()
    }
}
