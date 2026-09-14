class_name UIUtils
extends Object
## Petits utilitaires partagés par les écrans construits par code.


## Vide un conteneur.
##
## `queue_free()` seul est différé : si deux rafraîchissements tombent dans la
## même frame, les anciens enfants sont encore présents pendant la
## reconstruction et le conteneur contient transitoirement deux jeux de nœuds.
## On les détache immédiatement pour que son contenu soit toujours celui attendu.
static func clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
