import bpy

with open('/private/tmp/new-age-makehuman/blender-gui-probe.txt', 'w', encoding='utf-8') as handle:
    handle.write(bpy.app.version_string)

bpy.ops.wm.quit_blender()
