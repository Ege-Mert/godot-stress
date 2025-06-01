# Slot Machine Migration Guide

## Overview
The slot machine has been completely rewritten to use a physics-based system with true randomness. The reels now spin naturally and stop at random positions, eliminating the "last-second change" issue.

## Key Changes

### 1. New Components
- **SlotMachineSymbolStrip**: Defines the symbol order on each reel
- **SlotMachineReel**: Individual reel with physics-based spinning
- **Updated SlotMachineReels**: Now manages physics-based reels

### 2. How It Works Now
- Each reel has a predefined strip of symbols (like a real slot machine)
- Reels spin with velocity and friction
- Natural deceleration determines where they stop
- Results are calculated from the actual stopped positions
- No more predetermined outcomes!

## Migration Steps

### 1. Update Your SlotMachine Scene

In your SlotMachine.tscn, you'll need to:

1. Select the ReelManager node
2. In the Inspector, you'll see new properties:
   - **Reel Strip 1/2/3**: Assign the .tres files (SymbolStrip1.tres, etc.)
   - **Spin Delay Between Reels**: Time between each reel starting (default 0.2)
   - **Auto Stop After**: Safety timer (default 4.0 seconds)
   - **Use Different Strips**: Toggle to use different strips per reel

### 2. Configure Physics Settings

In your SlotMachineConfig resource:
- **Initial Velocity Min/Max**: How fast reels spin (15-25 recommended)
- **Friction**: How quickly they slow down (3.0 recommended)
- **Stop Threshold**: Velocity at which reel stops (0.1 recommended)
- **Snap to Symbol**: Whether to align perfectly with symbols (recommended: true)

### 3. Symbol Strip Configuration

The symbol strips control the probability of wins:
- More frequent symbols = lower chance of matching
- Symbols far apart = harder to get matches
- Edit the .tres files to adjust probabilities

Example strip pattern:
```
[6, 5, 4, 3, 5, 6, 4, 2, 4, 5, 6, 4, 5, 1, 5, 4, 6, 5, 4, 3, 6, 4, 5, 6, 4, 0, ...]
```
- 0 = Seven (Jackpot) - appears rarely
- 1 = Diamond, 2 = Bell, 3 = Cherry (Money symbols) - medium frequency
- 4 = Star, 5 = Lemon, 6 = Orange (Coin symbols) - high frequency

### 4. Testing Your Setup

1. Run the game and spin
2. Watch the reels - they should:
   - Start spinning with a slight delay between each
   - Gradually slow down naturally
   - Stop at random positions
   - Show consistent symbols (no last-second changes!)

### 5. Adjusting Win Rates

To adjust how often players win:
1. Edit the symbol strip patterns
2. Add more rare symbols between matches
3. Or group similar symbols together for easier wins

### 6. Tutorial/First Spin

The first spin tutorial still works but differently:
- Set `force_first_spin_loss` to true in SlotMachine
- Configure `first_spin_symbols` to [0, 1, 2] for guaranteed loss
- After first spin, everything is truly random

## Troubleshooting

**Reels not spinning?**
- Check that symbol strips are assigned in ReelManager
- Verify SlotMachineConfig is assigned

**Symbols not showing?**
- Ensure symbol textures are assigned in SlotMachineConfig
- Check that symbols array has all 7 symbols

**Want different odds per reel?**
- Set "Use Different Strips" to true
- Create custom strips with different symbol distributions
- Assign to Reel Strip 1/2/3 separately

## Benefits of New System

1. **Authentic Feel**: Reels spin and stop naturally
2. **True Randomness**: No predetermined outcomes
3. **No Visual Glitches**: What you see is what you get
4. **Customizable**: Easy to adjust odds via strip patterns
5. **Physics-Based**: Realistic deceleration and stopping
