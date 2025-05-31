# URGENT GAME JAM FIXES

## Priority 1: Critical Crashes (Fix These First!)

### 1. Audio Null Reference Fix
**Problem**: Game crashes when audio nodes don't exist
**Files affected**: SlotMachine.gd, PacmanScene.gd
**Status**: CRITICAL - Will crash game

### 2. Reel Animation Performance
**Problem**: Complex reel system causes frame drops
**File**: SlotMachine.gd lines 200-300
**Status**: HIGH - Affects gameplay smoothness

### 3. Player Group Detection
**Problem**: Ghost can't find player reliably
**File**: Ghost.gd line 35
**Status**: MEDIUM - Breaks ghost AI

## Priority 2: Game Flow Issues

### 4. Unnecessary Main Scene
**Problem**: main.tscn just redirects - adds loading time
**Fix**: Set SlotMachine.tscn as main scene directly

### 5. Wall-Phasing Ghost Detection
**Problem**: Detection area might not connect properly
**File**: WallPhasingGhost.gd
**Status**: MEDIUM - Breaks tutorial mechanic

## Quick Wins (5-minute fixes):

1. ✅ Change project.godot main scene to SlotMachine.tscn
2. ✅ Add null checks to all audio references
3. ✅ Ensure player is in "player" group
4. ✅ Simplify reel animation for performance
5. ✅ Test wall-phasing ghost collision

## Files to modify:
- project.godot (main scene)
- Scripts/SlotMachine.gd (audio null checks, reel performance)
- Scripts/PacmanScene.gd (audio null checks)
- Scripts/Ghost.gd (player detection)
- Scripts/WallPhasingGhost.gd (detection reliability)
