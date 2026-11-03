
package com.astroml.dev.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.util.Log

import kotlinx.coroutines.CompletableDeferred

import rikka.shizuku.Shizuku

object ShizukuManager {

    private const val TAG = "ShizukuManager"
    private const val REQUEST_CODE = 1001
    private const val SERVICE_TAG = "ASTROMLUnzipService"
    private const val SERVICE_SUFFIX = "astroml"
    private const val SERVICE_VERSION = 2

    enum class State {
        Unavailable,
        NoPermission,
        Idle,
        Bound
    }

    @Volatile
    var state: State = State.Unavailable
        private set

    @Volatile
    var service: IUnzipService? = null
        private set

    private var appContext: Context? = null

    @Volatile
    private var isBinding = false

    private var initialized = false

    private var pendingService =
        CompletableDeferred<IUnzipService>()

    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var foregroundRetryCount = 0
    @Volatile private var foregroundActive = false
    private val foregroundRetry = object : Runnable {
        override fun run() {
            if (!foregroundActive || state == State.Bound) return
            checkState()
            if (state != State.Bound && foregroundRetryCount < 30) {
                foregroundRetryCount++
                mainHandler.postDelayed(this, (500L + foregroundRetryCount * 250L).coerceAtMost(5_000L))
            }
        }
    }
    @Volatile private var permissionRetryRunning = false
    private val bindingTimeout: Runnable = Runnable {
        if (isBinding && service == null) {
            Log.w(TAG, "UserService bind callback timed out; allowing a fresh bind")
            isBinding = false
            state = State.Idle
            try {
                appContext?.let { Shizuku.unbindUserService(createServiceArgs(it), connection, false) }
            } catch (e: Exception) {
                Log.w(TAG, "Could not clear timed-out UserService callback", e)
            }
            if (Shizuku.pingBinder() &&
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                mainHandler.postDelayed({ bind() }, 500L)
            }
        }
    }

    /** Check immediately; if Android has not published the grant yet, retry once after 1 second. */
    private fun waitForPermissionThenBind() {
        if (permissionRetryRunning) return
        permissionRetryRunning = true

        fun attempt() {
            try {
                if (!Shizuku.pingBinder()) {
                    state = State.Unavailable
                } else if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                    permissionRetryRunning = false
                    state = State.Idle
                    bind()
                    return
                } else {
                    state = State.NoPermission
                }
            } catch (e: Exception) {
                Log.w(TAG, "Checking Shizuku permission", e)
            }
            permissionRetryRunning = false
        }

        attempt()
        if (state != State.Bound && state != State.Unavailable && state != State.NoPermission) {
            mainHandler.postDelayed({ attempt() }, 1_000L)
        } else if (state == State.NoPermission) {
            // Permission result callback can arrive just before checkSelfPermission updates.
            mainHandler.postDelayed({
                if (Shizuku.pingBinder() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                    state = State.Idle
                    bind()
                }
            }, 1_000L)
        }
    }

    private fun createServiceArgs(context: Context): Shizuku.UserServiceArgs {
        return Shizuku.UserServiceArgs(
            ComponentName(
                context.packageName,
                UserService::class.java.name
            )
        )
            .tag(SERVICE_TAG)
            .processNameSuffix(SERVICE_SUFFIX)
            .version(SERVICE_VERSION)
            .daemon(true)
    }

    // Shizuku binder received
    private val binderReceivedListener =
        Shizuku.OnBinderReceivedListener {
            Log.i(TAG, "Shizuku binder received")
            foregroundRetryCount = 0
            checkState()
        }

    // Shizuku binder died
    private val binderDeadListener =
        Shizuku.OnBinderDeadListener {
            Log.e(TAG, "Shizuku binder died")

            service = null
            isBinding = false
            mainHandler.removeCallbacks(bindingTimeout)
            state = State.Unavailable
            if (foregroundActive) {
                foregroundRetryCount = 0
                mainHandler.removeCallbacks(foregroundRetry)
                mainHandler.postDelayed(foregroundRetry, 700L)
            }
        }

    // Permission result
    private val permissionListener =
        Shizuku.OnRequestPermissionResultListener {
                requestCode,
                grantResult ->

            if (requestCode == REQUEST_CODE) {

                if (grantResult == PackageManager.PERMISSION_GRANTED) {

                    Log.i(TAG, "Shizuku permission granted")

                    state = State.Idle
                    waitForPermissionThenBind()

                } else {

                    Log.w(TAG, "Shizuku permission denied")

                    state = State.NoPermission
                }
            }
        }

    // UserService connection
    private val connection = object : ServiceConnection {

        override fun onServiceConnected(
            name: ComponentName?,
            binder: IBinder?
        ) {

            Log.i(TAG, "UserService connection callback received")

            if (binder == null) {

                Log.e(TAG, "Received null binder")

                service = null
                isBinding = false
                state = State.Unavailable

                return
            }

            if (!binder.isBinderAlive) {

                Log.e(TAG, "Received dead binder")

                service = null
                isBinding = false
                state = State.Unavailable

                return
            }

            try {

                val remoteService =
                    IUnzipService.Stub.asInterface(binder)

                if (remoteService == null) {

                    Log.e(TAG, "AIDL interface conversion failed")

                    service = null
                    isBinding = false
                    state = State.Unavailable

                    return
                }

                service = remoteService
                isBinding = false
                mainHandler.removeCallbacks(bindingTimeout)
                state = State.Bound
                foregroundRetryCount = 0
                mainHandler.removeCallbacks(foregroundRetry)

                if (!pendingService.isCompleted) {
                    pendingService.complete(remoteService)
                }

                Log.i(TAG, "ASTROML UserService successfully BOUND")

            } catch (e: Exception) {

                Log.e(TAG, "Binder conversion failed", e)

                service = null
                isBinding = false
                state = State.Unavailable
            }
        }

        override fun onServiceDisconnected(
            name: ComponentName?
        ) {

            Log.e(TAG, "UserService disconnected")

            service = null
            isBinding = false
            mainHandler.removeCallbacks(bindingTimeout)
            state = State.Idle

            pendingService = CompletableDeferred()

            // Reconnect automatically if Shizuku remains available and permission persists.
            Handler(Looper.getMainLooper()).postDelayed({
                if (state != State.Bound && !isBinding) {
                    checkState()
                }
            }, 400L)
        }
    }

    // Initialize Shizuku
    @Synchronized
    fun init(context: Context) {

        appContext = context.applicationContext

        if (initialized) {
            Log.d(TAG, "Already initialized")
            checkState()
            return
        }

        try {

            Shizuku.addBinderReceivedListenerSticky(
                binderReceivedListener
            )

            Shizuku.addBinderDeadListener(
                binderDeadListener
            )

            Shizuku.addRequestPermissionResultListener(
                permissionListener
            )

            initialized = true

            Log.i(TAG, "ShizukuManager initialized")

            checkState()

        } catch (e: Exception) {

            Log.e(TAG, "Initialization failed", e)

            state = State.Unavailable
        }
    }

    /**
     * Called whenever the app process starts or the app returns to foreground.
     * Shizuku may publish its binder slightly after the first Activity frame,
     * so retry binding during startup instead of requiring the user to leave
     * and reopen the app. This never displays a permission prompt.
     */
    fun onAppForeground() {
        foregroundActive = true
        foregroundRetryCount = 0
        mainHandler.removeCallbacks(foregroundRetry)
        checkState()
        // Keep checking until bound. This covers delayed Shizuku provider/binder
        // startup on OEM builds; it does not display a permission dialog.
        mainHandler.postDelayed(foregroundRetry, 250L)
    }

    fun onAppBackground() {
        foregroundActive = false
        mainHandler.removeCallbacks(foregroundRetry)
    }

    // Request Shizuku permission
    fun requestPermission() {

        try {

            if (!Shizuku.pingBinder()) {

                Log.e(TAG, "Shizuku is not running")

                state = State.Unavailable

                return
            }

            if (Shizuku.isPreV11()) {

                Log.e(TAG, "Shizuku version does not support UserService")

                state = State.Unavailable

                return
            }

            if (
                Shizuku.checkSelfPermission() ==
                PackageManager.PERMISSION_GRANTED
            ) {

                Log.i(TAG, "Permission already granted")

                checkState()

                return
            }

            Log.i(TAG, "Requesting Shizuku permission")

            Shizuku.requestPermission(REQUEST_CODE)

        } catch (e: Exception) {

            Log.e(TAG, "Permission request failed", e)

            state = State.Unavailable
        }
    }

    // Check current Shizuku state
    @Synchronized
    fun checkState() {

        try {

            if (!Shizuku.pingBinder()) {

                Log.w(TAG, "Shizuku binder unavailable")

                state = State.Unavailable

                return
            }

            if (Shizuku.isPreV11()) {

                Log.e(TAG, "Unsupported Shizuku version")

                state = State.Unavailable

                return
            }

            if (
                Shizuku.checkSelfPermission() !=
                PackageManager.PERMISSION_GRANTED
            ) {

                Log.w(TAG, "Shizuku permission not granted")

                state = State.NoPermission
                return
            }

            val currentService = service

            if (
                currentService != null &&
                currentService.asBinder().isBinderAlive
            ) {

                state = State.Bound

                return
            }

            state = State.Idle

            Log.i(TAG, "Shizuku ready, checking UserService")

            bind()

        } catch (e: Exception) {

            Log.e(TAG, "State check failed", e)

            state = State.Unavailable
        }
    }

    // Bind UserService
    @Synchronized
    fun bind() {

        val context = appContext

        if (context == null) {

            Log.e(TAG, "Application context is missing")

            state = State.Unavailable

            return
        }

        if (isBinding) {

            Log.d(TAG, "UserService binding already in progress")

            return
        }

        val currentService = service

        if (
            currentService != null &&
            currentService.asBinder().isBinderAlive
        ) {

            state = State.Bound

            Log.i(TAG, "UserService already connected")

            return
        }

        try {

            if (!Shizuku.pingBinder()) {

                Log.e(TAG, "Cannot bind: Shizuku is not running")

                state = State.Unavailable

                return
            }

            if (
                Shizuku.checkSelfPermission() !=
                PackageManager.PERMISSION_GRANTED
            ) {

                Log.e(TAG, "Cannot bind: permission not granted")

                state = State.NoPermission

                return
            }

            isBinding = true
            state = State.Idle

            pendingService = CompletableDeferred()

            val args = createServiceArgs(context)

            Log.i(TAG, "Starting UserService binding...")
            Log.i(TAG, "Component: ${context.packageName}/${UserService::class.java.name}")
            Log.i(TAG, "Process suffix: $SERVICE_SUFFIX")

            Shizuku.bindUserService(
                args,
                connection
            )
            mainHandler.removeCallbacks(bindingTimeout)
            mainHandler.postDelayed(bindingTimeout, 3_500L)

            Log.i(TAG, "bindUserService request submitted")

        } catch (e: Exception) {

            Log.e(TAG, "Failed to bind UserService", e)

            isBinding = false
            mainHandler.removeCallbacks(bindingTimeout)
            service = null
            state = State.Unavailable

            if (!pendingService.isCompleted) {
                pendingService.completeExceptionally(e)
            }
            // A transient binder/startup race should recover without an app restart.
            mainHandler.postDelayed({
                if (state != State.Bound) onAppForeground()
            }, 700L)
        }
    }

    // Wait for connected UserService
    suspend fun awaitService(): IUnzipService {

        val currentService = service

        if (
            currentService != null &&
            currentService.asBinder().isBinderAlive
        ) {
            return currentService
        }

        if (state == State.Unavailable ||
            state == State.NoPermission
        ) {
            checkState()
        }

        val newService = service

        if (
            newService != null &&
            newService.asBinder().isBinderAlive
        ) {
            return newService
        }

        return pendingService.await()
    }

    // Disconnect and clean up
    @Synchronized
    fun destroy() {

        Log.i(TAG, "Destroying ShizukuManager")

        try {

            val context = appContext

            if (context != null && Shizuku.pingBinder()) {

                Shizuku.unbindUserService(
                    createServiceArgs(context),
                    connection,
                    true
                )
            }

        } catch (e: Exception) {

            Log.e(TAG, "UserService unbind failed", e)
        }

        try {

            if (initialized) {

                Shizuku.removeBinderReceivedListener(
                    binderReceivedListener
                )

                Shizuku.removeBinderDeadListener(
                    binderDeadListener
                )

                Shizuku.removeRequestPermissionResultListener(
                    permissionListener
                )
            }

        } catch (e: Exception) {

            Log.e(TAG, "Listener cleanup failed", e)
        }

        service = null
        isBinding = false
        initialized = false
        state = State.Unavailable
        appContext = null

        if (!pendingService.isCompleted) {
            pendingService.cancel()
        }

        pendingService = CompletableDeferred()

        Log.i(TAG, "ShizukuManager destroyed")
    }
}
