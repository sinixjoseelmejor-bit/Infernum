extends Node
## Bus de signaux global (autoload `GameEvents`).
##
## Permet aux systèmes (UI, audio, VFX, méta-progression, succès...) de réagir
## aux évènements de jeu sans dépendance directe entre eux.
## Règle : les entités *émettent*, les systèmes *écoutent*.

signal player_spawned(player: Node2D)
signal player_health_changed(current: float, maximum: float)
signal player_died(player: Node2D)
## Seconde chance consommée : le coup fatal a été absorbé.
signal player_revived(player: Node2D)

signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, death_position: Vector2)

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)

## L'arène change d'étage. Émis par `floor_tiler.gd`, qui détient le seuil ;
## tout ce qui doit suivre la lumière du sol écoute ici plutôt que de compter
## les vagues de son côté.
signal arena_depth_changed(deep: bool)

signal damage_dealt(amount: float, world_position: Vector2, is_crit: bool)
## Émis uniquement quand la source des dégâts est le joueur (vol de vie, stats).
signal player_damage_dealt(amount: float, target: Node2D)
## Le joueur a encaissé un coup au contact (renvoi de dégâts, effets défensifs).
signal player_contact_hit(attacker: Node2D, amount: float)

signal boss_spawned(boss: Node2D)
signal boss_health_changed(current: float, maximum: float)
signal boss_phase_changed(phase: int, total: int)
signal boss_enraged(boss: Node2D)
signal boss_died(boss: Node2D)

signal shop_opened()
signal shop_closed()
signal camera_shake_requested(strength: float)

## POUVOIR DEMANDÉ (Espace / A). Le joueur ne sait pas ce que la touche déclenche
## et n'a pas à le savoir : la ruée de Loth vit dans `player.gd` parce qu'elle
## déplace, le Prix du sang vit dans `character_effects.gd` parce qu'il dépense
## un passif. Le joueur appuie, celui que ça concerne répond.
signal power_requested()

## POUVOIR UTILISÉ, lui : émis par celui qui a répondu, et seulement si le
## pouvoir est réellement parti — ruée achevée, parade armée, Jugement rendu,
## Prix du sang payé. Un appui sans effet (Marque trop basse, recharge en
## cours) n'émet rien. C'est à lui que les objets s'accrochent (Bâton de Moïse).
signal pouvoir_utilise(at: Vector2)

## Nouvelle à afficher en grand, au centre de l'écran. Réservée à ce qui change
## la partie pour de bon — il n'y en a qu'une aujourd'hui, la Clé des Abysses.
## Un bandeau qui servirait à tout ne serait plus lu.
signal announce(titre: String, detail: String, couleur: Color)


func request_shake(strength: float = 4.0) -> void:
	camera_shake_requested.emit(strength)
