#!/bin/bash

# Open Godot editor with project
echo "Launching Godot editor..."
/home/nikolas/Documents/codes/starmapper/.godot_bin/Godot_v4.3-stable_linux.x86_64 --editor /home/nikolas/Documents/codes/starmapper &

# Give editor time to load, then run the app
sleep 5
echo "Running app in play mode..."
/home/nikolas/Documents/codes/starmapper/.godot_bin/Godot_v4.3-stable_linux.x86_64 /home/nikolas/Documents/codes/starmapper &

echo "Both running. Close windows to stop."
