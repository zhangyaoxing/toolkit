# Mouse Mover
Move cursor or window to the target screen.
**MacOS only!**

## Usage
```bash
./build.sh
```

Define your hotkeys in "Preferences...". 3 hot keys are defined by default:
- Command + Shift + 1: move mouse to screen 0 center.
- Command + Shift + 2: move mouse to screen 1 center.
- Command + Shift + 3: move mouse to screen 2 center.

If mouse button is down, move to the same position of the target screen. This is designed for draggin your window.

You can also use the modifier + hotkey to move currently active window to the target screen. The modifier is by default disabled.

**Important**: in order to get the full feature, you need to allow the application to control your computer. Go to "Privacy & Security" -> "Accessibility" and add MouseMover to the list.