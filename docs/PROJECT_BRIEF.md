# Project Brief

Pocket Hoops is a portrait, half-court, arcade basketball game built for a class demo and structured for later mobile polish.

## Product Goal

Deliver a fast, readable offense-only basketball loop where the player:

- moves the current ballhandler with a thumb-friendly joystick
- taps teammates to pass
- holds on the ballhandler to open a slow-motion timing meter
- releases inside a fixed green meter window to score no matter what, or in red to miss / risk a block
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
- global state transitions stay explicit and logged
- gameplay values are tunable through resources
- deterministic tests cover the highest-risk behaviors
