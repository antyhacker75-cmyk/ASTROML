import re

ma_path = 'android/app/src/main/java/com/yuyu/dev/MainActivity.kt'
with open(ma_path, 'r') as f:
    content = f.read()

# 1. Add necessary imports for storage intent
imports_to_add = """
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.Settings
"""
# Insert after the package declaration
content = re.sub(r'^(package\s+.*?)$', r'\1\n' + imports_to_add, content, count=1, flags=re.MULTILINE)

# 2. Inject permission check inside onCreate
# We insert it right before ShizukuManager.init
target_line = 'ShizukuManager.init(applicationContext)'
if target_line in content:
    permission_check = '''
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                }
            }
        }
        '''
    content = content.replace(target_line, permission_check + '\n        ' + target_line, 1)
    print("✅ Injected MANAGE_EXTERNAL_STORAGE request into onCreate")
else:
    print("⚠️ Could not find ShizukuManager.init, please check manually.")

with open(ma_path, 'w') as f:
    f.write(content)
