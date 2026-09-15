class_name UIUtils
extends Object
## Petits utilitaires partagés par les écrans construits par code.


## Repère le contrôle qui a le focus, pour le retrouver après reconstruction.
##
## Renvoie son NOM et son RANG parmi les contrôles focalisables. Le nom sert au
## cas nominal ; le rang au cas où le contrôle a disparu ou est devenu inactif —
## on rend alors le focus au voisin le plus proche plutôt qu'au premier de la
## liste, ce qui garderait le joueur coincé en haut de l'écran.
static func capture_focus(root: Node) -> Dictionary:
	var owner := root.get_viewport().gui_get_focus_owner() if root.is_inside_tree() else null
	var list := focusable_controls(root)
	return {"name": owner.name if owner != null else &"", "index": list.find(owner)}


## Rend le focus après reconstruction : même nom si possible, sinon le voisin de
## même rang, sinon le repli.
##
## Un écran qui se reconstruit sur signal détruit le bouton qui vient d'être
## pressé — donc le porteur du focus. Sans cette restitution, l'écran devient un
## cul-de-sac à la manette : plus rien n'a le focus, la navigation directionnelle
## n'a plus de point de départ, et il faut la souris pour en sortir.
static func restore_focus(root: Node, captured: Dictionary, fallback: Control) -> void:
	var list := focusable_controls(root)
	if list.is_empty():
		if fallback != null and fallback.is_inside_tree():
			fallback.grab_focus()
		return
	var wanted: StringName = captured.get("name", &"")
	if wanted != &"":
		for control in list:
			if control.name == wanted:
				control.grab_focus()
				return
	var index: int = captured.get("index", -1)
	if index >= 0:
		list[clampi(index, 0, list.size() - 1)].grab_focus()
		return
	if fallback != null and fallback.is_inside_tree():
		fallback.grab_focus()
	else:
		list[0].grab_focus()


## Contrôles réellement atteignables à la manette, dans l'ordre de l'arbre.
## Un bouton désactivé est exclu : le laisser focalisable oblige à traverser les
## douze nœuds verrouillés de la Forge pour atteindre le seul qu'on peut ouvrir.
static func focusable_controls(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect_focusable(root, out)
	return out


static func _collect_focusable(node: Node, out: Array[Control]) -> void:
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree():
			return
		var usable := control.focus_mode != Control.FOCUS_NONE
		if usable and control is Button and (control as Button).disabled:
			usable = false
		if usable:
			out.append(control)
	for child in node.get_children():
		_collect_focusable(child, out)


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
