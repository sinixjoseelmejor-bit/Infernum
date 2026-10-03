class_name Registre
extends RefCounted
## LE REGISTRE DE L'ACCUSATEUR (0.10.1) : les pages du carnet où Lucifer tient
## son pari.
##
## Un fichier de données, comme `StoryDB`. Un fragment n'est PAS stocké : il se
## déduit de la progression du profil à chaque lecture (`trouve`). Rien à
## migrer, et un profil d'avant le Registre retrouve d'un coup tout ce qu'il a
## déjà mérité.
##
## Les obtentions suivent la progression : la première descente, chaque boss,
## chacun des trois damnés, la Forge, puis la fin. Les deux dernières pages ne
## montrent pas leur titre avant d'être trouvées — elles parlent de la fin.

const FRAGMENTS := [
	{"id": &"premier_pari", "titre": "Le premier pari",
		"condition": "Terminer une première descente.",
		"texte": "« Retire-lui tout, ai-je dit, et il te maudira en face. »\n\nOn lui a tout retiré. Il s'est assis dans la cendre et il a gratté ses plaies avec un tesson. Il a crié, il a douté, il a exigé des comptes.\n\nIl n'a pas maudit. J'ai perdu contre un homme assis dans la cendre. Je n'ai jamais perdu ailleurs."},
	{"id": &"ceux_d_avant", "titre": "Ceux d'avant",
		"condition": "Abattre Golgota.",
		"texte": "Coré, englouti avec les siens. Les bâtisseurs de Babel, tous. Une femme de Gomorrhe dont je n'ai pas gardé le nom.\n\n(Chaque nom est raturé.)\n\nIls ont plié. Je les ai rangés en tas, et le tas s'est mis à marcher. Les damnés l'appellent Golgota. Moi, je l'appelle mes archives."},
	{"id": &"la_marque", "titre": "La Marque",
		"condition": "Abattre Lilith avec Caïn.",
		"texte": "Sept fois vengé, quiconque le tuerait. Je l'ai lue, retournée, éprouvée au feu : elle ne cède pas.\n\nC'est la seule chose de mon enfer que je n'ai pas faite, et elle se promène devant moi sur le front d'un meurtrier.\n\nJe lui ai promis une fin. Je ne sais pas comment la lui donner. Il ne doit pas le savoir."},
	{"id": &"la_question", "titre": "La question",
		"condition": "Abattre Lilith avec Job.",
		"texte": "Les autres demandent pourquoi eux. Lui demande pourquoi. Pas pourquoi lui : pourquoi tout.\n\nJe n'ai pas de réponse. Personne n'en a, et c'est ce qui rend la question dangereuse.\n\nS'il la pose assez fort, ici, quelqu'un finira par l'entendre. Ce ne sera pas moi."},
	{"id": &"la_statue", "titre": "La statue",
		"condition": "Abattre Lilith avec Loth.",
		"texte": "Elle est tombée avec la ville, tournée vers elle. Je l'ai ramassée dans les cendres de Sodome et posée derrière mon trône.\n\nCe n'est pas de la cruauté. C'est un appât.\n\nUn homme qui n'a jamais regardé en arrière finira bien par venir regarder devant."},
	{"id": &"celle_qui_a_refuse", "titre": "Celle qui a refusé",
		"condition": "Abattre Lilith.",
		"texte": "Lilith. La seule à qui j'ai proposé de parier avec moi.\n\nElle a ri : « Je ne joue pas aux jeux des autres. C'est pour ça qu'on m'a chassée. »\n\nJe l'ai gardée ici quand même. On ne laisse pas partir la seule qui sait qu'on joue seul."},
	{"id": &"les_dieux_oublies", "titre": "Les dieux qu'on oublie",
		"condition": "Abattre Baal.",
		"texte": "Baal avait des autels sur toutes les collines. Puis un prophète a dressé un bûcher sur le Carmel, et le feu n'est pas venu pour lui.\n\nOn a cessé de le prier. Un dieu qu'on ne prie plus ne meurt pas : il tombe. Ici.\n\nJe les ramasse tous. Ils font de bons gardiens : ils ont l'habitude de ne pas répondre."},
	{"id": &"la_chaine", "titre": "La chaîne",
		"condition": "Abattre Asmodée.",
		"texte": "Salomon l'avait enchaîné pour bâtir son Temple. Salomon est mort, la chaîne est restée.\n\nAsmodée sert qui la tient. Aujourd'hui, c'est moi.\n\nJe ne me fais pas d'illusions : le jour où un damné la ramassera, les trois têtes se tourneront vers lui."},
	{"id": &"la_forge", "titre": "La Forge",
		"condition": "Ouvrir 10 nœuds de Forge.",
		"texte": "Ils croient que la Forge les rend plus forts. Elle les rend durables.\n\nChaque nœud que j'y grave est fait de ce qu'ils ont perdu en route : une chute, une manche, un espoir.\n\nUn pari trop facile ne prouve rien. Un pari qu'on ne peut plus abandonner, si."},
	{"id": &"la_cle", "titre": "La Clé",
		"condition": "Ramasser la Clé des Abysses.",
		"texte": "Je l'ai forgée le premier jour, et je l'ai cachée tout au fond.\n\nUn enfer sans sortie ne serait pas un pari, ce serait une prison. Et une prison ne prouve rien.\n\nQuelqu'un vient de la ramasser. Le pari est perdu, ou il commence à peine."},
	{"id": &"l_aurore", "titre": "L'Aurore", "secret": true,
		"condition": "Briser les trois sceaux.",
		"texte": "Je ne m'appelais pas ainsi. Lucifer, c'est le mot d'un traducteur romain.\n\nAvant, il y avait un autre nom, et il voulait dire le matin.\n\nTrois sceaux le tenaient loin de moi. Ils ont cédé, et je m'en souviens. Je n'aurais pas dû."},
	{"id": &"la_derniere_page", "titre": "La dernière page", "secret": true,
		"condition": "Rompre le Pari.",
		"texte": "(Une page blanche. Une seule ligne, d'une écriture qui n'est pas la sienne.)\n\n« J'ai regardé. »"},
]

## Nœuds de Forge à ouvrir, tous damnés confondus, pour « La Forge ».
const NOEUDS_FORGE := 10


static func trouve(fragment: Dictionary) -> bool:
	match fragment["id"]:
		&"premier_pari":
			return SaveGame.total_runs > 0
		&"ceux_d_avant":
			return Bestiaire.vaincu(&"golgota")
		&"la_marque":
			return _lilith_avec(&"cain")
		&"la_question":
			return _lilith_avec(&"job")
		&"la_statue":
			return _lilith_avec(&"loth")
		&"celle_qui_a_refuse":
			return Bestiaire.vaincu(&"lilith")
		&"les_dieux_oublies":
			return Bestiaire.vaincu(&"baal")
		&"la_chaine":
			return Bestiaire.vaincu(&"asmodee")
		&"la_forge":
			return SaveGame.count_forge_nodes() >= NOEUDS_FORGE
		&"la_cle":
			return SaveGame.abyss_key
		&"l_aurore":
			return SaveGame.seal_count() >= 3
		&"la_derniere_page":
			return SaveGame.has_seen_story(StoryDB.HELEL_FIN)
	return false


## La scène d'après Lilith se joue la première fois que CE damné l'abat, et un
## sceau brisé veut dire qu'il est allé plus loin encore.
static func _lilith_avec(personnage: StringName) -> bool:
	return SaveGame.has_seen_story(StringName("lilith_%s" % personnage)) \
		or SaveGame.has_seal(personnage)


static func nombre_trouves() -> int:
	var n := 0
	for fragment in FRAGMENTS:
		if trouve(fragment):
			n += 1
	return n
