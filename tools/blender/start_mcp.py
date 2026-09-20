"""Run with Blender's --python option to enable the installed local MCP bridge."""

import addon_utils
import bpy

addon_utils.enable("blender_mcp", default_set=True, persistent=True)
bpy.context.preferences.addons["blender_mcp"].preferences.telemetry_consent = False
bpy.ops.wm.save_userpref()
bpy.context.scene.blendermcp_port = 9876
bpy.ops.blendermcp.start_server()
print("Baseball Blender MCP listening on localhost:9876")
