class_name Groups
extends Object
## Noms de groupes centralisés pour éviter les chaînes magiques.

const PLAYER := &"player"
const ENEMIES := &"enemies"
const PICKUPS := &"pickups"
## Conteneur où les armes instancient leurs projectiles.
const PROJECTILE_CONTAINER := &"projectile_container"
## Conteneur où le spawner instancie les ennemis.
const ENEMY_CONTAINER := &"enemy_container"
## Le gestionnaire de vagues, que le butin interroge pour connaître l'échelle
## de dégâts courante — son soin est libellé en coups encaissables.
const WAVE_MANAGER := &"wave_manager"
