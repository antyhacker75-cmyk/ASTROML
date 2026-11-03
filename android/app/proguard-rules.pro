# Keep Shizuku UserService class name
-keep class com.astroml.dev.shizuku.UserService {
    *;
}

# Keep AIDL interfaces and generated Binder classes
-keep class com.astroml.dev.shizuku.IUnzipService { *; }
-keep class com.astroml.dev.shizuku.IUnzipService$Stub { *; }
-keep class com.astroml.dev.shizuku.IUnzipCallback { *; }
-keep class com.astroml.dev.shizuku.IUnzipCallback$Stub { *; }

# Keep all Shizuku package classes
-keep class com.astroml.dev.shizuku.** { *; }

-keep class org.tukaani.xz.** { *; }
-keep class org.apache.commons.compress.archivers.sevenz.** { *; }
