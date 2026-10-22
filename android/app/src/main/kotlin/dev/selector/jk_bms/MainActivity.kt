package dev.selector.jk_bms

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** UI attaches to the engine the companion service may already have started. */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        HandsFreeRuntime.attachActivity(this)
        return HandsFreeRuntime.getOrCreateEngine(context)
    }

    override fun shouldDestroyEngineWithHost() = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // FlutterEngine(Context) already registered plugins once. Channels are
        // installed by the runtime, including the installer before an Activity exists.
        HandsFreeRuntime.attachActivity(this)
    }

    @Deprecated("Activity result API used by CompanionDeviceManager on Android 12")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!HandsFreeRuntime.associationResult(requestCode, resultCode)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (!HandsFreeRuntime.permissionsResult(requestCode)) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onDestroy() {
        HandsFreeRuntime.detachActivity(this)
        super.onDestroy()
    }
}
