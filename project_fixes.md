# Debt Collector - Bug Fixes and Issues

## Critical Issues Found:

### 1. **GameManager Initial State**
**Problem**: GameManager starts with 500 coins instead of 5
**Location**: `Scripts/GameManager.gd` line 4
**Fix**: Change `var current_coins: int = 500` to `var current_coins: int = 5`

### 2. **Conflicting Scene Structure**
**Problem**: You have two different game implementations
- Simple version in `Scenes/main.tscn` (inline scripts)
- Complex modular version with separate scenes
**Fix**: Decide which implementation to use and remove the other

### 3. **Input Map Missing Actions**
**Problem**: Scripts reference undefined input actions
**Actions needed**:
- `ui_up`, `ui_down`, `ui_left`, `ui_right` (should be built-in)
- `ui_accept` (should be built-in)
**Check**: Project Settings > Input Map

### 4. **Audio Node References**
**Problem**: Scripts reference audio nodes that may not exist
**Files affected**:
- `SlotMachine.gd` references audio nodes like `$Audio/SpinSound`
- `PacmanScene.gd` references `$Audio/CoinPickup`
**Fix**: Either add these audio nodes to scenes or add null checks

### 5. **TileMapLayer vs TileMap**
**Problem**: Inconsistent TileMap API usage
**Fix**: Use TileMapLayer consistently for Godot 4.4

### 6. **Reel Animation Issues**
**Problem**: Complex reel animation in SlotMachine might be causing performance issues
**Symptoms**: Potential frame drops during spinning

### 7. **Ghost AI References**
**Problem**: Ghost AI tries to find player by name "Player" but player might not be named correctly
**Fix**: Use groups instead of node names

## Quick Fixes to Apply:

1. **Fix GameManager initial coins**
2. **Add null checks for audio nodes** 
3. **Simplify reel animations**
4. **Fix player detection in ghosts**
5. **Clean up scene structure**

## Recommended Implementation Path:

1. **Use the modular scene approach** (SlotMachine.tscn, PacmanScene.tscn, etc.)
2. **Remove or update main.tscn** to just load SlotMachine.tscn
3. **Fix all audio references**
4. **Test the core game loop**

## Testing Priority:

1. ✅ GameManager coin management
2. ✅ Slot machine basic functionality  
3. ✅ Scene transitions (slot → pacman → slot)
4. ✅ Pacman movement and coin collection
5. ✅ Ghost AI and collision detection
6. ✅ Upgrade system
7. ✅ Audio and visual effects
