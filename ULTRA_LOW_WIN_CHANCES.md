# Ultra-Low Win Chances System

## Overview
This system drastically reduces winning chances in the slot machine to create an extremely punishing gambling experience. All probabilities are configurable from the inspector.

## New Inspector Settings (GameManager)

### Winning Probabilities (%)
- **Jackpot Chance**: `0.001%` (1 in 100,000) - Chance for massive jackpot
- **Base Win Chance**: `0.5%` (1 in 200) - Base chance for ANY win
- **Coin Win Ratio**: `30%` - Of wins, how many are coin wins vs debt wins
- **Upgrade Win Boost**: `0.02%` - How much each upgrade level increases win chance
- **Lucky Spin Chance Per Level**: `0.01%` - Lucky spin chance per upgrade level

### Payout Ranges
- **Min Coin Win**: `3` coins
- **Max Coin Win**: `8` coins  
- **Min Debt Reduction**: `$25`
- **Max Debt Reduction**: `$75`
- **Lucky Multiplier**: `1.5x` - Multiplier for lucky wins
- **Upgrade Payout Boost**: `0.1` - Payout boost per upgrade level

### Jackpot Settings
- **Jackpot Clears All Debt**: `true` - Whether jackpot clears all debt
- **Jackpot Fixed Amount**: `$1,000,000` - Fixed amount if not clearing all debt

## Visual Manipulation System (SlotMachineConfig)

### Visual Win Chances (%)
- **Jackpot Symbol Chance**: `0.1%` - How often jackpot symbols appear
- **High Value Symbol Chance**: `2.0%` - How often high-value symbols appear  
- **Medium Value Symbol Chance**: `8.0%` - How often medium-value symbols appear
- **Low Value Symbol Chance**: `25.0%` - How often low-value symbols appear
- **Enable Visual Win Manipulation**: `true` - Whether to manipulate reel outcomes
- **Near Miss Frequency**: `5.0%` - How often to show "almost wins"

## How It Works

### 1. Probability Calculation
The system uses extremely low base probabilities:
- **99.5%** of spins are losses (base setting)
- **0.499%** are small wins (coins/debt reduction)
- **0.001%** are jackpots

### 2. Visual Manipulation
When enabled, the system:
1. Calculates the actual win/loss using GameManager probabilities
2. Forces the visual reels to match that result
3. Creates "near miss" combinations 5% of the time on losses for psychological effect

### 3. Win Caps
- Maximum win chance is capped at **15%** even with all upgrades
- Payouts are drastically reduced compared to original system
- Upgrades provide minimal improvement

## Comparison to Original System

| Aspect | Original | New System |
|--------|----------|------------|
| Base Win Chance | 25% | 0.5% |
| Jackpot Chance | 0.01% | 0.001% |
| Coin Win Range | 10-30 | 3-8 |
| Debt Reduction | $100-300 | $25-75 |
| Upgrade Impact | 8% per level | 0.02% per level |

## Configuration Tips

### To make it even more punishing:
- Reduce `base_win_chance` to `0.1%` (1 in 1000)
- Reduce `jackpot_chance` to `0.0001%` (1 in 1,000,000)
- Lower `max_coin_win` to `5`
- Lower `max_debt_reduction` to `50`

### To make it slightly more forgiving:
- Increase `base_win_chance` to `1.0%` (1 in 100)
- Increase `coin_win_ratio` to `0.5` (50% of wins are coins)
- Increase payout ranges slightly

## Technical Implementation

### GameManager Changes:
- New inspector-exposed probability variables
- `calculate_spin_result_only()` - calculates without applying effects
- Updated `calculate_spin_result()` with new ultra-low probabilities

### SlotMachine Changes:
- Visual manipulation system that forces reels to match GameManager results
- Near-miss generation for psychological effect
- Support for both old and new calculation methods

### SlotMachineConfig Changes:
- New visual symbol chance settings
- Enable/disable manipulation toggle

## Debug Output
The system prints detailed debug information:
```
SPIN DEBUG: Chance rolled: 0.234 | Jackpot threshold: 0.00001 | Win threshold: 0.005
Loss - no payout
MANIPULATION: Forced losing combination
```

This helps you verify the system is working as intended during testing.
