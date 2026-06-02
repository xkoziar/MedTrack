package pv292.fi.muni.cz.med_track

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "med_track/nfc_background"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Check for NFC intent when app is launched
        handleNfcIntent(intent)

        // Check for pending NFC tag from background
        checkPendingNfcTag()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNfcIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // Check for pending NFC tag when app resumes
        checkPendingNfcTag()
    }

    private fun handleNfcIntent(intent: Intent) {
        Log.d("MainActivity", "Handling intent with action: ${intent.action}")

        if (intent.action == NfcAdapter.ACTION_TAG_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TECH_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_NDEF_DISCOVERED) {

            val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            tag?.let {
                val tagId = bytesToHexString(it.id)
                Log.d("MainActivity", "NFC tag detected via intent: $tagId")

                // Store in SharedPreferences for later processing
                val prefs = getSharedPreferences("nfc_prefs", MODE_PRIVATE)
                prefs.edit().apply {
                    putString("pending_tag_id", tagId)
                    putLong("pending_tag_time", System.currentTimeMillis())
                    apply()
                }

                // Try to send to Flutter immediately
                methodChannel?.invokeMethod("onNfcTagScanned", tagId)
            }
        }
    }

    private fun checkPendingNfcTag() {
        val prefs = getSharedPreferences("nfc_prefs", MODE_PRIVATE)
        val pendingTagId = prefs.getString("pending_tag_id", null)
        val pendingTime = prefs.getLong("pending_tag_time", 0)

        if (pendingTagId != null && pendingTime > 0) {
            // Check if tag was scanned within the last 5 minutes
            val currentTime = System.currentTimeMillis()
            if (currentTime - pendingTime < 5 * 60 * 1000) {
                Log.d("MainActivity", "Processing pending NFC tag: $pendingTagId")
                methodChannel?.invokeMethod("onNfcTagScanned", pendingTagId)
            }

            // Clear the pending tag
            prefs.edit().apply {
                remove("pending_tag_id")
                remove("pending_tag_time")
                apply()
            }
        }
    }

    private fun bytesToHexString(bytes: ByteArray): String {
        return bytes.joinToString(":") { String.format("%02X", it) }
    }
}
