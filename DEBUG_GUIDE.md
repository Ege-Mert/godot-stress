# DEBUGGING GUIDE - Game Won't Start

## Step-by-Step Debugging

### 1. Check Godot Error Console
When you try to run the game, what exact error messages appear in Godot's output/debugger console?

### 2. Try Running Individual Scenes
Test each scene separately to isolate the problem:

**A. Test SlotMachine Scene:**
- In Godot, right-click `SlotMachine.tscn` → "Change Main Scene" 
- Press F5 to run
- Does it start?

**B. Test PacmanScene:**
- Right-click `PacmanScene.tscn` → "Change Main Scene"
- Press F5 to run  
- Does it start?

### 3. Common Issues to Check

**A. Missing Node References:**
- Open `SlotMachine.tscn`
- Check if all UI nodes exist (SpinButton, etc.)
- Look for red error icons next to nodes

**B. Script Attachment Issues:**
- Select the root SlotMachine node
- In Inspector, verify `SlotMachine.gd` is attached
- Look for red warning icons

**C. Missing Resources:**
- Check if `SlotMachineConfig` resource exists
- Verify symbol textures are loaded

### 4. Minimal Test Version

If nothing works, let's create a minimal test version:

```gdscript
# MinimalSlotMachine.gd - Ultra simple version for testing
extends Control

func _ready():
    print("Minimal slot machine started!")
    
    var label = Label.new()
    label.text = "MINIMAL TEST - PRESS SPACE TO SPIN"
    label.position = Vector2(100, 100)
    add_child(label)
    
func _input(event):
    if event.is_action_pressed("ui_accept"):
        print("Spin pressed!")
```

### 5. Check Project Settings
Verify in `Project → Project Settings`:
- Main Scene is set to `res://Scenes/SlotMachine.tscn`
- GameManager autoload is properly configured

### 6. Web vs Desktop
Are you testing on:
- Desktop (F5) 
- Web export
- Both?

Some issues only appear in web builds.

## Quick Fixes to Try

### A. Remove Problematic @onready References
In `SlotMachine.gd`, temporarily comment out problematic lines:

```gdscript
# @onready var ui_manager = $UI as SlotMachineUI
# @onready var reel_manager = $ReelManager as SlotMachineReels
```

### B. Add Debug Prints
Add this to SlotMachine.gd `_ready()`:

```gdscript
func _ready():
    print("SlotMachine _ready() started")
    setup_random_seed()
    print("Random seed setup complete")
    # ... rest of function
```

### C. Disable Components Temporarily
Comment out parts of the `_ready()` function one by one:

```gdscript
func _ready():
    setup_random_seed()
    # setup_configuration()      # COMMENT OUT
    # setup_components()         # COMMENT OUT  
    # connect_signals()          # COMMENT OUT
    # initialize_game()          # COMMENT OUT
```

## Let me know:
1. What error messages you see
2. Which scenes (if any) can run individually
3. Results of the minimal test
4. Whether you're testing desktop or web

This will help me pinpoint the exact issue!
