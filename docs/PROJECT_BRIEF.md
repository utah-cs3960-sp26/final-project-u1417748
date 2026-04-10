# Project Brief

Pocket Hoops is a portrait, half-court, arcade basketball game built for a class demo and structured for later mobile polish.

## Product Goal

Deliver a fast, readable offense-only basketball loop where the player:

- drags inside a lower-screen invisible touch zone to move the current ballhandler
- flicks toward teammates to pass, with a live pre-release pass-target preview
- releases a non-pass gesture to arm a timing meter and live arc preview at normal speed
- taps anywhere inside the green meter window to score no matter what, or outside it to miss / risk a block
- resolves makes, misses, steals, rebounds, and jump-cut opponent possessions quickly

## Demo Bar

The demo is complete when a player can:

- boot directly into a match
- play a full 3:00 offense-only game
- score 2PT and 3PT baskets
- trigger live rebounds and opponent sim possessions
- pause, resume, finish, and restart without soft-locking

## Constraints

- Godot 4.6.x
- typed GDScript
- portrait only
- no live human defense
- no fouls, free throws, overtime, persistence, audio, or online systems
- no third-party gameplay frameworks

## Success Criteria

- shooting feels like the center of the game
- shots climb into a dramatic, readable arcade arc instead of a line drive to the rim
- the court reads as a flat rectangle, fills the phone vertically without stretching, and players stay easy to read on a phone-sized screen
- global state transitions stay explicit and logged
- gameplay values are tunable through resources
- deterministic tests cover the highest-risk behaviors
