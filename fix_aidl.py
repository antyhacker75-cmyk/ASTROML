import os, re

aidl_dir = 'android/app/src/main/aidl/com/yuyu/dev/shizuku'
kotlin_dir = 'android/app/src/main/java/com/yuyu/dev'

# 1. Fix AIDL package declarations
for filename in os.listdir(aidl_dir):
    if filename.endswith('.aidl'):
        filepath = os.path.join(aidl_dir, filename)
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Force the correct package name
        content = re.sub(r'^package\s+.*?;', 'package com.yuyu.dev.shizuku;', content, flags=re.MULTILINE)
        
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Fixed package in {filename}")

# 2. Fix Kotlin imports in ShizukuManager.kt and YuyuEngine.kt
target_files = [
    os.path.join(kotlin_dir, 'shizuku', 'ShizukuManager.kt'),
    os.path.join(kotlin_dir, 'engine', 'YuyuEngine.kt')
]

for filepath in target_files:
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Remove ANY existing IUnzipService imports (to clear out the wrong ones)
        content = re.sub(r'^import\s+.*?IUnzipService.*?$', '', content, flags=re.MULTILINE)
        
        # Add the correct import right after the package declaration
        content = re.sub(r'^(package\s+.*?)$', r'\1\nimport com.yuyu.dev.shizuku.IUnzipService', content, count=1, flags=re.MULTILINE)
        
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Fixed IUnzipService import in {os.path.basename(filepath)}")

