# Decisions

## 2026-04-07 — Presentation Scaffold Uses Script-Drawn Placeholder Art

Decision:
- Implement the first art pass as script-drawn 2D placeholder scenes instead of imported sprite sheets.

Why:
- keeps the placeholder layer original and license-safe
- avoids creating asset pipeline debt before gameplay logic exists
- makes it easy to recolor, resize, and replace visuals later without changing scene contracts
- supports editor-safe reuse for the coordinator and future workers

Tradeoff:
- the look is intentionally simple and may be less expressive than a hand-drawn sprite sheet
- runtime/editor smoke testing is still needed because this environment cannot launch Godot

## 2026-04-07 — UI Theme Is Built From A Shared Presentation Resource

Decision:
- Build UI styling from `RetroPresentationTheme.tres` plus `RetroUiThemeBuilder.gd` instead of scattering per-scene color overrides.

Why:
- keeps the placeholder presentation data-driven
- gives future workers one place to retune the retro palette and spacing direction
- reduces coupling between menu/HUD/overlay scenes and future gameplay scripts
