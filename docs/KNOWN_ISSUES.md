# Known Issues

## Runtime Validation Pending

Godot is not installed in the current execution environment, so the new scaffold could not be run inside the editor during this session.

Impact:
- scene loading, theme application, and `@tool` rendering still need a real editor smoke test

## Placeholder Typography Is Temporary

The UI currently relies on Godot's default font stack with custom colors, panel treatment, and sizing.

Impact:
- the visual direction is coherent enough for a placeholder pass, but a more characterful final font treatment should be added later without introducing third-party licensing risk
