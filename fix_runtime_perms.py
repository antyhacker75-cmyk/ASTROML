import re, os

# 1. Ensure Manifest has READ and WRITE permissions
manifest_path = 'android/app/src/main/AndroidManifest.xml'
with open(manifest_path, 'r') as f:
    manifest = f.read()

if 'android.permission.WRITE_EXTERNAL_STORAGE' not in manifest:
    manifest = manifest.replace('<application', 
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />\n'
        '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />\n\n    <application', 1)
    print("✅ Added READ/WRITE storage to Manifest")

with open(manifest_path, 'w') as f:
    f.write(manifest)

# 2. Inject runtime permission request (Request Code 1001) into MainActivity.kt
ma_path = 'android/app/src/main/java/com/yuyu/dev/MainActivity.kt'
with open(ma_path, 'r') as f:
    ma_content = f.read()

# Add imports if missing
if 'import android.Manifest' not in ma_content:
    ma_content = re.sub(r'^(package\s+.*?)$', r'\1\nimport android.Manifest\nimport androidx.core.app.ActivityCompat\nimport androidx.core.content.ContextCompat', ma_content, count=1, flags=re.MULTILINE)

# Inject permission request right before ShizukuManager.init
target_line = 'ShizukuManager.init(applicationContext)'
if target_line in ma_content and 'REQUEST_CODE_STORAGE' not in ma_content:
    perm_request = '''
        // Request Standard Storage Permissions (Code 1001)
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
                1001
            )
        }
        '''
    ma_content = ma_content.replace(target_line, perm_request + '\n        ' + target_line, 1)
    print("✅ Injected runtime request (Code 1001) into MainActivity.kt")

with open(ma_path, 'w') as f:
    f.write(ma_content)

