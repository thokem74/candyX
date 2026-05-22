# candyX

A mobile-friendly match-3 puzzle prototype for Android, built with Godot 4.x and GDScript. The game uses documented CC0 external assets for candy art, UI, sound effects, and music; see `res://assets/licenses/CREDITS.md`.

## Run in the editor

1. Open the project in Godot 4.6.x.
2. Run the existing main scene.
3. Use mouse drag or tap-two-adjacent-pieces input to test swaps.

## Android testing

1. Keep the existing Android export preset.
2. Connect an Android phone with USB debugging enabled.
3. In Godot, use the Android one-click deploy/run flow or export the Android preset.
4. Test in portrait orientation with touch swipes and taps.

## Gameplay checks

- Complete level goals to unlock the Next button.
- Use Restart to reset the current level.
- Match 4 pieces to create striped bombs.
- Match 5 pieces to create color bombs.
- Create L/T matches to create wrapped bombs.
- Swap a color bomb with a normal piece to clear that color.
