class_name Layers
extends Object
## Valeurs binaires des calques de physique (voir project.godot > layer_names).
## Usage : `collision_mask = Layers.ENEMY | Layers.WORLD`

const WORLD := 1 << 0            # 1
const PLAYER := 1 << 1           # 2
const ENEMY := 1 << 2            # 4
const PLAYER_PROJECTILE := 1 << 3  # 8
const ENEMY_PROJECTILE := 1 << 4   # 16
const PICKUP := 1 << 5           # 32
