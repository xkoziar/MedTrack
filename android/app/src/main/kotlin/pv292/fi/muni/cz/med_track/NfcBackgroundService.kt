package pv292.fi.muni.cz.med_track

import android.app.Service
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.IBinder
import android.util.Log

class NfcBackgroundService : Service() {
    companion object {
        private const val TAG = "NfcBackgroundService"
        private const val CHANNEL = "med_track/nfc_background"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "NFC Background Service started")

        if (intent?.action == NfcAdapter.ACTION_TAG_DISCOVERED ||
            intent?.action == NfcAdapter.ACTION_NDEF_DISCOVERED) {

            val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            tag?.let {
                val tagId = bytesToHexString(it.id)
                Log.d(TAG, "NFC tag detected in background: $tagId")

                // Store tag ID for processing when app opens
                val prefs = getSharedPreferences("nfc_prefs", MODE_PRIVATE)
                prefs.edit().apply {
                    putString("pending_tag_id", tagId)
                    putLong("pending_tag_time", System.currentTimeMillis())
                    apply()
                }

                // Launch the app if it's not running
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                launchIntent?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    startActivity(this)
                }
            }
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun bytesToHexString(bytes: ByteArray): String {
        return bytes.joinToString(":") { String.format("%02X", it) }
    }
}
