import os

manifest_path = 'android/app/src/main/AndroidManifest.xml'
with open(manifest_path, 'r') as f:
    content = f.read()

# 1. Add MANAGE_EXTERNAL_STORAGE if missing
if 'MANAGE_EXTERNAL_STORAGE' not in content:
    content = content.replace('<application', 
        '<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />\n'
        '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />\n'
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />\n\n    <application', 1)
    print("✅ Added MANAGE_EXTERNAL_STORAGE to Manifest")

# 2. Add requestLegacyExternalStorage just in case (helps with older Android versions)
if 'requestLegacyExternalStorage="true"' not in content:
    content = content.replace('<application', '<application android:requestLegacyExternalStorage="true"', 1)
    print("✅ Added requestLegacyExternalStorage")

with open(manifest_path, 'w') as f:
    f.write(content)
