class_name AppMode
## Process-wide UI mode flags (set from CLI args in app.gd before any screen
## builds). freeze_motion keeps screenshots deterministic and doubles as the
## reduced-motion setting hook.

static var freeze_motion := false
