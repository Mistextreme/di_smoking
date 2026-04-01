# DOTINIT SMOKING SCRIPT

A QBCore-based smoking resource with cigarette boxes, smoking mechanics, and a coupon shop system. Supports both qb-inventory and ox_inventory.

## Features

- **Box Opening**: Open cigarette boxes to receive cigarettes and bonus coupons.
- **Smoking System**: Consume cigarettes with stress reduction and animations.
- **Smoking Shop**: Buy boxes with money or exchange coupons for boxes.
- **Dual Inventory Support**: Works with qb-inventory and ox_inventory.
- **PED Interaction**: Optional NPC at shop locations with godmode.
- **Multiple Interaction Modes**: Key press (E), qb-target, or ox-target.

## Configuration

Edit `config.lua` to customize:

- `Config.Inventory`: "qb" or "ox" - Inventory system.
- `Config.Notify`: "qb" or "ox" - Notification system.
- `Config.Progressbar`: Progress bar system ("qb" or "ox").
- `Config.SmokingShop`: Enable/disable shop, pricing, redemption, locations, PED options.
- `Config.Boxes`: Box settings, bonuses, consume options.

## Installation

1. Place `di_smoking` in your resources folder.
2. Add items to your inventory config.
3. Ensure dependencies: qb-core, ox_lib (if using ox), qb-target/ox_target (if using target).
4. Configure `config.lua`.
5. Start the resource.

## Usage

- Open boxes using inventory.
- Smoke cigarettes (requires lighter).
- Visit shop locations to buy/exchange coupons.
- Interact via E, qb-target, or ox-target as configured.

## Dependencies

- qb-core
- ox_lib (for menus, notifications, progress)
- qb-inventory or ox_inventory
- qb-target or ox_target (optional)

# SUPPORT/ASSISTANCE

## Join 
**DOTINIT SCRIPTS** - https://discord.gg/52duTcAfx9