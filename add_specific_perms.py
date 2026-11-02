import re

manifest_path = 'android/app/src/main/AndroidManifest.xml'
with open(manifest_path, 'r') as f:
    content = f.read()

# List of all standard permissions shown in your screenshots
perms = [
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_AUDIO',
    'android.permission.MANAGE_EXTERNAL_STORAGE'
]

for p in perms:
    if f'android:name="{p}"' not in content:
        content = content.replace('<application', f'<uses-permission android:name="{p}" />\n    <application', 1)
        print(f'✅ Added {p}')

with open(manifest_path, 'w') as f:
    f.write(content)

print("✅ Manifest updated with standard permissions!")
