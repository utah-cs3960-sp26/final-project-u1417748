# Project Brief

## Goal

Build a portrait, mobile-first, offense-only retro arcade basketball game in Godot 4.6.2 stable using typed GDScript.

## Current Delivery Focus

This session established the presentation-first foundation for the project:
- original placeholder court visuals for a vertical half-court layout
- reusable player, ball, and hoop presentation scenes
- a black-banner HUD and menu/overlay UI direction
- a shared presentation resource for colors and sizing

## Core Constraints

- portrait-only reference layout around `1080x1920`
- hoop fixed at the top center
- lower third reserved primarily for joystick/input comfort
- offense-only pacing with fast jump-cuts back to human possessions
- original placeholder presentation only, with no copyrighted branding or external assets

## Integration Intent

These presentation assets are not the gameplay implementation. They exist to give the coordinator safe visual building blocks that can be driven later by the game state machine, input controller, AI, ball simulation, and test harness.
