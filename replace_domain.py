import os

OLD_DOMAIN = "luminadata-v2.pages.dev"
NEW_DOMAIN = "mlbbbackend.pages.dev"
VALID_EXTS = ('.dart', '.kt', '.java', '.xml', '.json', '.yaml', '.yml', '.txt', '.html', '.js', '.ts', '.gradle', '.properties')

replace_count = 0
modified_files = []

for root, dirs, files in os.walk('.'):
    # Skip hidden folders and build directories
    dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ('build', 'node_modules')]
    
    for file in files:
        if file.endswith(VALID_EXTS):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                if OLD_DOMAIN in content:
                    new_content = content.replace(OLD_DOMAIN, NEW_DOMAIN)
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    modified_files.append(filepath)
                    print(f"✅ Updated: {filepath}")
                    replace_count += content.count(OLD_DOMAIN)
            except Exception as e:
                print(f"⚠️ Could not process {filepath}: {e}")

print(f"\n🎉 Replacement complete! Changed {replace_count} occurrence(s) across {len(modified_files)} file(s).")
