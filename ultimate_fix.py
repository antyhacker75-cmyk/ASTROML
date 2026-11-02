import os, re

# 1. Dynamically find the package for IUnzipService
unzip_import = "import com.yuyu.dev.engine.IUnzipService" # Default fallback
for root, dirs, files in os.walk('android'):
    for file in files:
        if file.endswith(('.kt', '.java', '.aidl')):
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                content = f.read()
                if 'interface IUnzipService' in content:
                    # Find the package declaration
                    match = re.search(r'^package\s+([a-zA-Z0-9_.]+)', content, re.MULTILINE)
                    if match:
                        unzip_import = f"import {match.group(1)}.IUnzipService"
                        break
    if 'import' in unzip_import and 'engine' not in unzip_import:
        break

print(f"✅ Found IUnzipService import: {unzip_import}")

# 2. Write the perfect ShizukuManager.kt
sm_code = f'''package com.yuyu.dev.shizuku

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import rikka.shizuku.Shizuku
import kotlinx.coroutines.delay
{unzip_import}

object ShizukuManager {{
    enum class State {{ Bound, Idle, NoPermission, Unavailable }}

    var state: State = State.Unavailable
        private set

    var service: IUnzipService? = null
        private set

    private const val REQUEST_CODE = 1001

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {{
        checkState()
    }}

    private val binderDeadListener = Shizuku.OnBinderDeadListener {{
        state = State.Unavailable
        service = null
    }}

    private val permissionListener = Shizuku.OnRequestPermissionResultListener {{ requestCode, grantResult ->
        if (requestCode == REQUEST_CODE) {{
            checkState()
        }}
    }}

    fun init(context: Context) {{
        try {{
            // STICKY is crucial: catches the binder even if Shizuku is already running
            Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
            Shizuku.addBinderDeadListener(binderDeadListener)
            Shizuku.addRequestPermissionResultListener(permissionListener)
        }} catch (e: Throwable) {{
            // Ignore if already added
        }}
        checkState()
    }}

    fun bind() {{
        checkState()
    }}

    fun requestPermission(activity: Activity) {{
        if (Shizuku.pingBinder() && !Shizuku.isPreV11()) {{
            if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {{
                Shizuku.requestPermission(REQUEST_CODE)
            }}
        }}
    }}

    suspend fun awaitService(): IUnzipService {{
        var retries = 50 // 5 seconds timeout
        while (state != State.Bound && retries > 0) {{
            delay(100)
            retries--
        }}
        return service ?: throw IllegalStateException("Shizuku service is not bound")
    }}

    private fun checkState() {{
        try {{
            if (!Shizuku.pingBinder()) {{
                state = State.Unavailable
                service = null
                return
            }}

            if (Shizuku.isPreV11() || Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {{
                val binder = Shizuku.getBinder()
                if (binder != null) {{
                    service = IUnzipService.Stub.asInterface(binder)
                    state = State.Bound
                }} else {{
                    state = State.Unavailable
                    service = null
                }}
            }} else {{
                state = State.NoPermission
            }}
        }} catch (e: Throwable) {{
            state = State.Unavailable
            service = null
        }}
    }}
}}
'''

sm_path = 'android/app/src/main/java/com/yuyu/dev/shizuku/ShizukuManager.kt'
with open(sm_path, 'w') as f:
    f.write(sm_code)
print("✅ Rewritten ShizukuManager.kt with Sticky Listeners and Crash Protection")

# 3. Fix MainActivity.kt imports and return types
ma_path = 'android/app/src/main/java/com/yuyu/dev/MainActivity.kt'
with open(ma_path, 'r') as f:
    ma_content = f.read()

# Ensure the import is correct
ma_content = re.sub(r'^import .*ShizukuManager.*$', '', ma_content, flags=re.MULTILINE)
ma_content = re.sub(r'^(package .*)$', r'\1\nimport com.yuyu.dev.shizuku.ShizukuManager', ma_content, count=1, flags=re.MULTILINE)

# Ensure 'when' statement returns a String to prevent crash
ma_content = ma_content.replace('else -> {}', 'else -> "Unknown"')
ma_content = ma_content.replace('else -> { /* fallback */ }', 'else -> "Unknown"')

with open(ma_path, 'w') as f:
    f.write(ma_content)
print("✅ Fixed MainActivity.kt imports and return types")

