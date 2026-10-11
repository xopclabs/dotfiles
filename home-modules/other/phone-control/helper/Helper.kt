package dev.phonecontrol.debugginghelper

import android.Manifest.permission.*
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.database.ContentObserver
import android.graphics.Typeface
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.location.LocationManager
import android.net.*
import android.net.wifi.WifiManager
import android.os.*
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.*
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.security.cert.X509Certificate
import javax.net.ssl.*
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

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

// Exported only so the authenticated ADB shell can provision private relay settings.
// Android apps (including those with notification access) cannot use this endpoint.
class PairingProvider : ContentProvider() {
    override fun onCreate() = true
    private fun authorize(uri: Uri) {
        check(Binder.getCallingUid() == 2000 && uri.path == "/pair") { "ADB shell only" }
    }
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        authorize(uri)
        require(mode == "w")
        val pipe = ParcelFileDescriptor.createReliablePipe()
        Thread {
            try {
                val raw = ParcelFileDescriptor.AutoCloseInputStream(pipe[0]).use {
                    val bytes = ByteArray(4097)
                    var size = 0
                    while (size < bytes.size) {
                        val read = it.read(bytes, size, bytes.size - size)
                        if (read < 0) break
                        size += read
                    }
                    require(size <= 4096)
                    String(bytes, 0, size, Charsets.UTF_8)
                }
                val pair = JSONObject(raw)
                val url = URL(pair.getString("url"))
                require(url.protocol == "https" && url.userInfo == null && url.path == "/snapshot")
                require(pair.getString("pin").matches(Regex("[0-9a-f]{64}")))
                require(pair.getString("token").matches(Regex("[A-Za-z0-9_-]{32,128}")))
                check(requireNotNull(context).preferences.edit().putString("relay_pair", pair.toString()).commit())
            } catch (_: Exception) {
                // Do not log provisioning content or URLs.
            }
        }.start()
        return pipe[1]
    }
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?): android.database.Cursor {
        authorize(uri)
        val raw = requireNotNull(context).preferences.getString("relay_pair", null)
        val identity = if (raw == null) "" else JSONObject(raw).let {
            it.getString("url") + "\n" + it.getString("pin") + "\n" + it.getString("token")
        }
        val digest = MessageDigest.getInstance("SHA-256").digest(identity.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 255) }
        return android.database.MatrixCursor(arrayOf("digest")).apply { addRow(arrayOf(digest)) }
    }
    override fun getType(uri: Uri): String { authorize(uri); return "application/json" }
    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw SecurityException()
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = throw SecurityException()
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = throw SecurityException()
}

class MainActivity : Activity() {
    private lateinit var status: TextView
    private lateinit var detail: TextView
    private lateinit var result: TextView
    private lateinit var enable: Button
    private lateinit var relayPreview: TextView
    private val previewTick = object : Runnable {
        override fun run() {
            relayPreview.text = RelayListener.preview(this@MainActivity)
            handler.postDelayed(this, 1_000)
        }
    }
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
        val relay = card("Notification relay · local preview")
        label(relay, "Selected alerts are queued in encrypted private phone storage until the paired PC displays them. Delivery waits while its internal display is off. No content logs. Android may redact sensitive content.")
        button(relay, "Allow notification access") {
            open(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
        button(relay, "Select apps") { selectRelayApps() }
        label(relay, "Select Phone, Messaging, and ntfy, then receive a test notification or incoming call. This preview reads currently active notifications, including updates and removals.", 13f)
        label(relay, "Your trusted PC configures this automatically over ADB when you open Phone Control. Delivery then works without debugging. Unpairing lasts until the next PC setup.", 13f)
        button(relay, "Unpair PC") {
            preferences.edit().remove("relay_pair").remove("relay_queue").apply()
            RelayListener.clearQueue()
        }
        relayPreview = label(relay, "", 14f)
        val setup = card("Permissions & privacy")
        label(setup, "Android needs location access to read Wi-Fi names in the background. " +
            "This app never reads coordinates. Internet access is used for the paired notification receiver.")
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

    private fun selectRelayApps() {
        val suggested = listOf("com.android.dialer", "com.android.messaging", "io.heckel.ntfy")
        val selected = (preferences.getStringSet("relay_apps", emptySet()) ?: emptySet()).toMutableSet()
        val apps = packageManager.getInstalledApplications(0)
            .filter { it.packageName != packageName }
            .sortedWith(compareBy<android.content.pm.ApplicationInfo> {
                suggested.indexOf(it.packageName).let { index -> if (index < 0) suggested.size else index }
            }.thenBy { packageManager.getApplicationLabel(it).toString().lowercase() })
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(8), dp(20), 0)
        }
        val search = EditText(this).apply {
            hint = "Search apps"
            isSingleLine = true
            setTextColor(color("ink"))
            setHintTextColor(color("muted"))
            content.addView(this, LinearLayout.LayoutParams(-1, -2))
        }
        val rows = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(ScrollView(this).apply { addView(rows) },
            LinearLayout.LayoutParams(-1, dp(360)))
        val views = apps.map { app ->
            val name = packageManager.getApplicationLabel(app).toString()
            val row = LinearLayout(this).apply {
                gravity = Gravity.CENTER_VERTICAL
                minimumHeight = dp(60)
                setPadding(0, dp(6), 0, dp(6))
                addView(ImageView(this@MainActivity).apply {
                    setImageDrawable(packageManager.getApplicationIcon(app))
                    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                }, LinearLayout.LayoutParams(dp(40), dp(40)).apply { marginEnd = dp(12) })
                val check = CheckBox(this@MainActivity).apply {
                    text = name
                    textSize = 16f
                    setTextColor(color("ink"))
                    isChecked = app.packageName in selected
                    setOnCheckedChangeListener { _, checked ->
                        if (checked) selected.add(app.packageName) else selected.remove(app.packageName)
                    }
                }
                addView(check, LinearLayout.LayoutParams(0, -2, 1f))
                setOnClickListener { check.isChecked = !check.isChecked }
                rows.addView(this, LinearLayout.LayoutParams(-1, -2))
            }
            Triple(row, name, app.packageName)
        }
        search.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val query = s?.toString().orEmpty().trim()
                views.forEach { (row, name, pkg) ->
                    row.visibility = if (name.contains(query, true) || pkg.contains(query, true))
                        View.VISIBLE else View.GONE
                }
            }
            override fun afterTextChanged(s: android.text.Editable?) {}
        })
        AlertDialog.Builder(this).setTitle("Apps to preview").setView(content)
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Save") { _, _ ->
                preferences.edit().putStringSet("relay_apps", selected).apply()
            }.show()
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

    override fun onResume() {
        super.onResume()
        refresh()
        handler.removeCallbacks(previewTick)
        handler.post(previewTick)
    }
    override fun onPause() { handler.removeCallbacksAndMessages(null); super.onPause() }
}

class RelayListener : NotificationListenerService() {
    private val sender = Executors.newSingleThreadScheduledExecutor()
    private val pending = java.util.concurrent.atomic.AtomicBoolean(false)
    private val icons = mutableMapOf<String, String>()

    private fun appIcon(pkg: String): String = icons.getOrPut(pkg) {
        try {
            val drawable = packageManager.getApplicationIcon(pkg)
            val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
            try {
                drawable.setBounds(0, 0, 96, 96)
                drawable.draw(Canvas(bitmap))
                ByteArrayOutputStream().use { output ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                    android.util.Base64.encodeToString(output.toByteArray(), android.util.Base64.NO_WRAP)
                }
            } finally { bitmap.recycle() }
        } catch (_: Exception) { "" }
    }
    private var backlog = JSONObject().put("events", JSONArray()).put("seen", JSONObject())
    private var storageReady = false
    private var queueDirty = false

    private fun queueKey(): javax.crypto.SecretKey {
        val store = java.security.KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "notification-relay-queue"
        return (store.getKey(alias, null) as? javax.crypto.SecretKey) ?: run {
            val generator = javax.crypto.KeyGenerator.getInstance("AES", "AndroidKeyStore")
            generator.init(android.security.keystore.KeyGenParameterSpec.Builder(alias,
                android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or
                    android.security.keystore.KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes("GCM").setEncryptionPaddings("NoPadding").build())
            generator.generateKey()
        }
    }

    private fun loadQueue() {
        val encoded = preferences.getString("relay_queue", null)
        if (encoded != null) {
            val bytes = android.util.Base64.decode(encoded, android.util.Base64.NO_WRAP)
            val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(javax.crypto.Cipher.DECRYPT_MODE, queueKey(),
                javax.crypto.spec.GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
            backlog = JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
        }
        storageReady = true
    }

    private fun saveQueue() {
        queueDirty = true
        val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, queueKey())
        val bytes = cipher.iv + cipher.doFinal(backlog.toString().toByteArray(Charsets.UTF_8))
        check(preferences.edit().putString("relay_queue",
            android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)).commit())
        queueDirty = false
    }

    private fun relayEligible(pkg: String, notification: Notification, selected: Set<String>) =
        if (pkg == packageName) notification.channelId == "failures" else pkg in selected

    private fun record(item: StatusBarNotification) {
        if (preferences.getString("relay_pair", null) == null) return
        val selected = preferences.getStringSet("relay_apps", emptySet()) ?: emptySet()
        if (!relayEligible(item.packageName, item.notification, selected) ||
            item.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val event = extract(item)
        val fingerprint = MessageDigest.getInstance("SHA-256").digest(event.toString().toByteArray())
            .joinToString("") { "%02x".format(it.toInt() and 255) }
        val seen = backlog.getJSONObject("seen")
        if (seen.optString(item.key) == fingerprint) return
        val events = backlog.getJSONArray("events")
        // Keep each content update: a later short missed-call alert must not erase earlier messages.
        event.put("id", java.util.UUID.randomUUID().toString()).put("key", item.key)
            .put("package", item.packageName).put("icon", appIcon(item.packageName)).put("app",
                try { packageManager.getApplicationLabel(packageManager.getApplicationInfo(item.packageName, 0)).toString() }
                catch (_: Exception) { item.packageName })
        events.put(event)
        seen.put(item.key, fingerprint)
        saveQueue()
    }

    private fun safely(action: () -> Unit) {
        try {
            if (!storageReady) loadQueue()
            action()
        } catch (_: Exception) { delivery = "Queue storage unavailable · delivery paused" }
    }

    @Volatile private var connected = false
    @Volatile private var delivery = "PC not paired"

    override fun onCreate() {
        super.onCreate()
        sender.scheduleWithFixedDelay({ safely { deliver() } }, 0, 15, TimeUnit.SECONDS)
    }

    private fun changed() {
        if (!sender.isShutdown && pending.compareAndSet(false, true)) sender.execute {
            try { safely { deliver() } } finally { pending.set(false) }
        }
    }

    private fun deliver() {
        if (!connected) return
        val raw = preferences.getString("relay_pair", null)
        if (raw == null) { delivery = "PC not paired"; return }
        try {
            val pair = JSONObject(raw)
            val pin = pair.getString("pin")
            val trust = object : X509TrustManager {
                override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
                override fun checkClientTrusted(chain: Array<X509Certificate>, auth: String) {
                    throw java.security.cert.CertificateException("Not a server")
                }
                override fun checkServerTrusted(chain: Array<X509Certificate>, auth: String) {
                    val digest = MessageDigest.getInstance("SHA-256").digest(chain.first().encoded)
                        .joinToString("") { "%02x".format(it.toInt() and 255) }
                    if (digest != pin) throw java.security.cert.CertificateException("Unpaired certificate")
                }
            }
            val tls = SSLContext.getInstance("TLS").apply { init(null, arrayOf(trust), null) }
            val selected = preferences.getStringSet("relay_apps", emptySet()) ?: emptySet()
            activeNotifications.forEach { record(it) }
            val queued = backlog.getJSONArray("events")
            val retained = JSONArray()
            for (index in 0 until queued.length()) {
                val event = queued.getJSONObject(index)
                if (event.getString("package") in selected ||
                    event.getString("package") == packageName) retained.put(event)
            }
            if (retained.length() != queued.length()) {
                backlog.put("events", retained)
                saveQueue()
            }
            if (queueDirty) saveQueue()
            val batch = JSONArray()
            for (index in 0 until minOf(retained.length(), 8)) batch.put(retained.getJSONObject(index))
            val bytes = JSONObject().put("version", 2).put("events", batch).toString().toByteArray(Charsets.UTF_8)
            val connection = URL(pair.getString("url")).openConnection() as HttpsURLConnection
            try {
                connection.sslSocketFactory = tls.socketFactory
                // Identity is the explicitly paired certificate, not DNS or a public CA.
                connection.hostnameVerifier = HostnameVerifier { _, _ -> true }
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 5_000
                connection.readTimeout = 5_000
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Authorization", "Bearer ${pair.getString("token")}")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setFixedLengthStreamingMode(bytes.size)
                connection.outputStream.use { it.write(bytes) }
                if (connection.responseCode == 200) {
                    val response = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
                    val acked = response.getJSONArray("acked")
                    val ids = (0 until acked.length()).map { acked.getString(it) }.toSet()
                    val remaining = JSONArray()
                    for (index in 0 until retained.length()) {
                        val event = retained.getJSONObject(index)
                        if (event.getString("id") !in ids) remaining.put(event)
                    }
                    if (ids.isNotEmpty()) {
                        backlog.put("events", remaining)
                        saveQueue()
                    }
                    delivery = if (!response.getBoolean("ready")) "PC display off · ${remaining.length()} queued"
                        else if (remaining.length() > 0) "Delivering backlog · ${remaining.length()} queued"
                        else "PC synchronized · queue empty"
                } else delivery = "PC rejected delivery (${connection.responseCode})"
            } finally { connection.disconnect() }
        } catch (error: Exception) {
            // Types only: exception messages may include private URLs or response details.
            val reason = listOf("Permission denied", "EPERM", "EACCES", "Connection reset",
                "Broken pipe", "Connection refused", "Network is unreachable", "Socket closed")
                .firstOrNull { error.message?.contains(it, true) == true }
            delivery = "PC unavailable · ${reason ?: error.javaClass.simpleName}" +
                (error.cause?.let { " / ${it.javaClass.simpleName}" } ?: "") + " · retrying"
        }
    }

    override fun onNotificationPosted(item: StatusBarNotification) {
        if (!sender.isShutdown) sender.execute { safely { record(item); deliver() } }
    }
    override fun onNotificationRemoved(item: StatusBarNotification) {
        if (!sender.isShutdown) sender.execute { safely {
            // Removal changes active state, not whether an unseen event deserves delivery.
            backlog.getJSONObject("seen").remove(item.key)
            saveQueue()
        } }
    }

    companion object {
        private var listener: RelayListener? = null

        fun clearQueue() {
            listener?.let { service ->
                if (!service.sender.isShutdown) service.sender.execute {
                    service.backlog = JSONObject().put("events", JSONArray()).put("seen", JSONObject())
                    service.storageReady = true
                }
            }
        }

        fun preview(context: Context): String {
            val selected = context.preferences.getStringSet("relay_apps", emptySet()) ?: emptySet()
            val service = listener ?: return "Listener disconnected. Enable notification access in Android settings."
            return try {
                val active = service.activeNotifications.filter {
                    service.relayEligible(it.packageName, it.notification, selected) &&
                        it.notification.flags and Notification.FLAG_GROUP_SUMMARY == 0
                }
                if (active.isEmpty()) service.delivery + "\nNo selected notifications active."
                else service.delivery + "\n\n" + active.joinToString("\n\n────────\n\n") {
                    val item = extract(it)
                    listOf(it.packageName, item.getString("title"), item.getString("body"))
                        .filter { text -> text.isNotEmpty() }.joinToString("\n")
                }
            } catch (_: RuntimeException) {
                "Active notifications unavailable. Check notification access."
            }
        }

        private fun extract(item: StatusBarNotification): JSONObject {
            val extras = item.notification.extras
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val messages = Notification.MessagingStyle.Message.getMessagesFromBundleArray(
                extras.getParcelableArray(Notification.EXTRA_MESSAGES))
            val body = if (messages.isNotEmpty()) messages.joinToString("\n") { message ->
                val sender = message.senderPerson?.name?.toString().orEmpty()
                (if (sender.isNotEmpty()) "$sender: " else "") + message.text.toString()
            } else {
                val expanded = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
                val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
                expanded?.takeIf { it.isNotEmpty() }
                    ?: lines?.joinToString("\n")?.takeIf { it.isNotEmpty() }
                    ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
            }
            return JSONObject().put("title", title).put("body", body)
        }
    }

    override fun onListenerConnected() { listener = this; connected = true; changed() }
    override fun onListenerDisconnected() { connected = false; if (listener === this) listener = null }
    override fun onDestroy() {
        connected = false
        sender.shutdownNow()
        if (listener === this) listener = null
        super.onDestroy()
    }
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
