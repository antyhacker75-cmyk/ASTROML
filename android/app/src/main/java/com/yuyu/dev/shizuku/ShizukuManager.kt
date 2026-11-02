
package com.yuyu.dev.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import android.util.Log

import kotlinx.coroutines.CompletableDeferred

import rikka.shizuku.Shizuku

object ShizukuManager {

    private const val TAG = "ShizukuManager"
    private const val REQUEST_CODE = 1001
    private const val SERVICE_TAG = "YuyuUnzipService"
    private const val SERVICE_SUFFIX = "yuyu"
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
            .daemon(false)
    }

    // Shizuku binder received
    private val binderReceivedListener =
        Shizuku.OnBinderReceivedListener {
            Log.i(TAG, "Shizuku binder received")
            checkState()
        }

    // Shizuku binder died
    private val binderDeadListener =
        Shizuku.OnBinderDeadListener {
            Log.e(TAG, "Shizuku binder died")

            service = null
            isBinding = false
            state = State.Unavailable
        }

    // Permission result
    private val permissionListener =
        Shizuku.OnRequestPermissionResultListener {
                requestCode,
                grantResult ->

            if (requestCode == REQUEST_CODE) {

                if (grantResult == PackageManager.PERMISSION_GRANTED) {

                    Log.i(TAG, "Shizuku permission granted")

                    checkState()

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
                state = State.Bound

                if (!pendingService.isCompleted) {
                    pendingService.complete(remoteService)
                }

                Log.i(TAG, "Yuyu UserService successfully BOUND")

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
            state = State.Idle

            pendingService = CompletableDeferred()
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

            Log.i(TAG, "bindUserService request submitted")

        } catch (e: Exception) {

            Log.e(TAG, "Failed to bind UserService", e)

            isBinding = false
            service = null
            state = State.Unavailable

            if (!pendingService.isCompleted) {
                pendingService.completeExceptionally(e)
            }
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
