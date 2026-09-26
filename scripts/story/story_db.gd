class_name StoryDB
extends RefCounted
## Le texte et la mise en scène des cinématiques.
##
## UN FICHIER DE DONNÉES, PAS DE CODE. Corriger une réplique, déplacer un
## personnage ou ajouter un plan se fait ici, sans toucher au lecteur
## (`scripts/story/cinematic.gd`).
##
## L'HISTOIRE — « Le Pari ». Dans le livre de Job, tout commence par un pari
## entre Dieu et l'Accusateur : « retire-lui tout, et il te maudira ».
## L'Accusateur a perdu. Il veut sa revanche, et il a fait descendre trois âmes
## que le Ciel avait épargnées — un meurtrier qu'on n'a pas eu le droit de tuer,
## un juste brisé puis recollé, un fuyard sorti du feu. Ce qui n'a pas plié
## là-haut pliera ici. Ça explique ce que le jeu fait déjà : on meurt et on
## recommence (perdre une manche ne libère personne), la Forge est l'atelier de
## l'Accusateur (un pari trop facile ne prouve rien), et la Clé des Abysses est
## la seule sortie du pari.
##
## Chacun veut autre chose que la victoire : Caïn une fin, Job une réponse,
## Loth quelqu'un.
##
## FORMAT D'UN PLAN
##   "fond"    &"noir", &"abime", &"arene" ou &"menu"
##   "acteurs" [{ "id", "planche", "pos", "echelle", "miroir", "sombre",
##               "cache", "depuis", "sel" }]
##             `depuis` : le personnage entre en marchant depuis ce point.
##             `sombre` : silhouette éteinte, qu'une réplique allume.
##             `cache`  : invisible, qu'une réplique fait apparaître.
##             `sel`    : teinté en statue de sel.
##             `teinte` : couleur appliquée (un boss vaincu, éteint).
##             `lumiere`: repeint en or — Lucifer dans sa lumière d'origine.
##   "zoom"    [départ, arrivée] — la caméra glisse pendant tout le plan
##   "lignes"  [{ "qui", "texte", "allume", "montre", "entre", "son",
##               "secousse", "dessale", "si_min", "si_moins" }]
##             `qui` vide = narration. `dessale` rend sa couleur à une statue.
##             `si_min` / `si_moins` : la réplique ne passe que si le nombre de
##             sceaux brisés est au moins / sous cette valeur. `{sceaux}` et
##             `{reste}` sont remplacés dans le texte.
##   "titre"   [titre, sous-titre] — carton plein écran
##   "duree"   durée d'un plan sans réplique

## Qui parle : nom affiché et couleur. Les damnés prennent la couleur de leur
## fiche de personnage.
const LOCUTEURS := {
	&"lucifer": ["Lucifer", Color(0.95, 0.3, 0.22)],
	&"cain": ["Caïn", Color(0.85, 0.22, 0.18)],
	&"job": ["Job", Color(0.55, 0.72, 0.85)],
	&"loth": ["Loth", Color(0.95, 0.85, 0.5)],
	&"lilith": ["Lilith", Color(0.86, 0.4, 0.72)],
	&"edith": ["Édith", Color(0.94, 0.92, 0.86)],
	&"helel": ["Hélel", Color(1.0, 0.9, 0.55)],
}

## Planches : repos et marche.
const PLANCHES := {
	&"lucifer": "res://assets/sprites/bosses/lucifer/lucifer",
	&"cain": "res://assets/sprites/characters/cain/cain",
	&"job": "res://assets/sprites/characters/job/job",
	&"loth": "res://assets/sprites/characters/loth/loth",
	&"femme_sel": "res://assets/sprites/story/femme_sel/femme_sel",
	&"lilith": "res://assets/sprites/bosses/lilith/lilith",
}

const LE_PARI := &"le_pari"
## Boss après lesquels une scène se joue, dans l'ordre de la run.
const BOSSES_RACONTES: Array[StringName] = [&"lilith"]
const LUCIFER_RELEVE := &"lucifer_releve"
const HELEL_ENTREE := &"helel_entree"
const HELEL_FIN := &"helel_fin"

const CINEMATIQUES := {
	&"le_pari": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Au commencement du livre de Job, il y eut un pari."},
				{"texte": "« Retire-lui tout, disait l'Accusateur, et il te maudira en face. »"},
				{"texte": "On lui a tout retiré. Il n'a pas maudit."},
				{"texte": "L'Accusateur a perdu."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.12],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(0, 40), "echelle": 8.0,
					"miroir": true, "cache": true},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Perdre une fois, c'est une leçon.",
					"montre": &"lucifer", "son": &"boss", "secousse": 0.6},
				{"qui": &"lucifer", "texte": "Je n'aime pas les leçons."},
				{"qui": &"lucifer", "texte": "Alors j'ai relevé la mise."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.05, 0.95],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(0, -150), "echelle": 6.0,
					"miroir": true},
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-460, 190), "echelle": 5.0,
					"sombre": true},
				{"id": &"job", "planche": &"job", "pos": Vector2(0, 230), "echelle": 5.0,
					"sombre": true},
				{"id": &"loth", "planche": &"loth", "pos": Vector2(460, 190), "echelle": 5.0,
					"sombre": true, "miroir": true},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Trois âmes que le Ciel avait épargnées."},
				{"qui": &"lucifer", "texte": "Un meurtrier qu'on n'a pas eu le droit de tuer.",
					"allume": &"cain"},
				{"qui": &"lucifer", "texte": "Un juste qu'on a brisé, puis recollé.",
					"allume": &"job"},
				{"qui": &"lucifer", "texte": "Un fuyard qu'on a laissé sortir du feu.",
					"allume": &"loth"},
				{"qui": &"lucifer", "texte": "Ce qui n'a pas plié là-haut pliera ici. C'est tout le pari."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.1, 1.25],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(0, 40), "echelle": 8.0,
					"miroir": true},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Ils mourront. Souvent."},
				{"qui": &"lucifer", "texte": "Chaque fois, je les relèverai à ma Forge."},
				{"qui": &"lucifer", "texte": "Un pari trop facile ne prouve rien : je leur prêterai même des armes."},
			],
		},
		{
			"fond": &"arene",
			"zoom": [1.2, 1.0],
			"lignes": [
				{"texte": "L'enfer n'a pas de portes. Il a des vagues."},
				{"texte": "Et tout au fond, dit-on, une clé qui n'ouvre rien de ce qu'on connaît."},
			],
		},
		{
			"fond": &"noir",
			"titre": ["INFERNUM", "Le Pari"],
			"duree": 3.2,
		},
	],

	&"prologue_cain": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Caïn, le Premier Sang."},
				{"texte": "Quiconque le tuerait serait vengé sept fois : ainsi l'avait voulu le Ciel."},
				{"texte": "Personne n'a jamais osé."},
			],
		},
		{
			"fond": &"arene",
			"zoom": [1.0, 1.1],
			"acteurs": [
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-120, 120), "echelle": 7.0,
					"depuis": Vector2(-1100, 120)},
			],
			"lignes": [
				{"qui": &"cain", "texte": "Des siècles à marcher. Les rois meurent, les villes meurent."},
				{"qui": &"cain", "texte": "Moi, jamais."},
				{"qui": &"cain", "texte": "On m'a interdit de mourir. Personne ne m'a interdit de descendre."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.08],
			"acteurs": [
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-380, 150), "echelle": 6.0},
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(380, 90), "echelle": 7.0,
					"miroir": true, "cache": true},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Le premier meurtrier vient frapper à ma porte. J'en suis presque ému.",
					"montre": &"lucifer", "son": &"boss", "secousse": 0.4},
				{"qui": &"cain", "texte": "Je ne viens pas pour toi. Je viens chercher une fin."},
				{"qui": &"lucifer", "texte": "Gagne, et je te la donnerai."},
				{"qui": &"lucifer", "texte": "Perds, et tu recommenceras. Tu as l'habitude."},
				{"qui": &"cain", "texte": "Montre-moi ce qu'il faut tuer."},
			],
		},
	],

	&"prologue_job": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Job, l'Éprouvé."},
				{"texte": "On lui avait pris ses troupeaux, sa maison, ses enfants, et jusqu'à sa peau."},
				{"texte": "Il n'avait pas maudit. On lui avait tout rendu."},
			],
		},
		{
			"fond": &"arene",
			"zoom": [1.15, 1.0],
			"acteurs": [
				{"id": &"job", "planche": &"job", "pos": Vector2(0, 110), "echelle": 7.0},
			],
			"lignes": [
				{"qui": &"job", "texte": "Je me suis endormi chez moi. Mes filles riaient dans la cour."},
				{"qui": &"job", "texte": "Je me suis réveillé ici."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.1],
			"acteurs": [
				{"id": &"job", "planche": &"job", "pos": Vector2(-380, 150), "echelle": 6.0},
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(380, 90), "echelle": 7.0,
					"miroir": true, "cache": true},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Bonjour, Job. Tu ne me reconnais pas ? Nous avons un passé commun.",
					"montre": &"lucifer", "son": &"boss", "secousse": 0.4},
				{"qui": &"job", "texte": "Qu'ai-je fait, cette fois ?"},
				{"qui": &"lucifer", "texte": "Rien. C'est bien ce qui rend la chose intéressante."},
				{"qui": &"job", "texte": "On m'a déjà tout pris une fois. Je sais comment ça se termine."},
				{"qui": &"lucifer", "texte": "Là-haut, oui. Ici, c'est moi qui écris la fin."},
			],
		},
	],

	&"prologue_loth": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Loth, le Fuyard."},
				{"texte": "Quand le feu est tombé sur Sodome, il a couru sans se retourner."},
				{"texte": "Derrière lui, sa femme s'est retournée. Elle est devenue sel."},
			],
		},
		{
			"fond": &"arene",
			"zoom": [1.0, 1.12],
			"acteurs": [
				{"id": &"femme", "planche": &"femme_sel", "pos": Vector2(360, 110), "echelle": 7.0,
					"miroir": true, "sel": true},
				{"id": &"loth", "planche": &"loth", "pos": Vector2(-260, 130), "echelle": 7.0,
					"depuis": Vector2(200, 130), "miroir": true},
			],
			"lignes": [
				{"qui": &"loth", "texte": "Toute ma vie, j'ai fui. Et toute ma vie, j'ai eu ce sel sur les lèvres."},
				{"qui": &"loth", "texte": "On dit que son âme est tombée ici, avec la ville."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.08],
			"acteurs": [
				{"id": &"loth", "planche": &"loth", "pos": Vector2(-380, 150), "echelle": 6.0},
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(380, 90), "echelle": 7.0,
					"miroir": true, "cache": true},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Le seul homme qui a su ne pas regarder en arrière…",
					"montre": &"lucifer", "son": &"boss", "secousse": 0.4},
				{"qui": &"lucifer", "texte": "… revient chercher ce qu'il a laissé derrière lui."},
				{"qui": &"loth", "texte": "Où est-elle ?"},
				{"qui": &"lucifer", "texte": "En bas. Tout en bas. Cours, Loth. Tu sais faire."},
				{"qui": &"loth", "texte": "Cette fois, je ne fuis pas. Je descends."},
			],
		},
	],

	# --- Après Lilith (vague 10) -------------------------------------------
	# LE MILIEU DU PARI. Lilith, la première femme — chassée du premier jardin
	# pour avoir dit non —, vaincue, révèle ce que Lucifer tait : personne
	# là-haut n'a accepté son pari. Il joue seul, contre un Ciel qui se tait.
	# Chacun l'entend avec ce qu'il est venu chercher.

	&"lilith_cain": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "La Première Nuit est tombée."},
				{"texte": "En enfer, rien ne meurt tout à fait."},
			],
		},
		{
			"fond": &"arene",
			"zoom": [1.1, 1.0],
			"acteurs": [
				{"id": &"lilith", "planche": &"lilith", "pos": Vector2(330, 120), "echelle": 7.0,
					"miroir": true, "teinte": Color(0.7, 0.5, 0.6)},
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-300, 130), "echelle": 7.0,
					"depuis": Vector2(-1100, 130)},
			],
			"lignes": [
				{"qui": &"lilith", "texte": "Le premier meurtrier. Nous aurions dû nous rencontrer plus tôt, toi et moi."},
				{"qui": &"cain", "texte": "Relève-toi ou reste à terre. Mais ne me fais pas perdre mon temps."},
				{"qui": &"lilith", "texte": "Ton temps ? Tu en as plus que quiconque. C'est ta malédiction, pas la mienne."},
				{"qui": &"lilith", "texte": "Il t'a promis une fin, n'est-ce pas ? Il la promet à tous."},
				{"qui": &"cain", "texte": "Et alors ?"},
				{"qui": &"lilith", "texte": "Ta Marque ne vient pas de lui. Ce qu'il n'a pas posé, il ne peut pas l'ôter."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.15],
			"acteurs": [
				{"id": &"lilith", "planche": &"lilith", "pos": Vector2(330, 120), "echelle": 7.0,
					"miroir": true, "teinte": Color(0.7, 0.5, 0.6)},
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-300, 130), "echelle": 7.0},
			],
			"lignes": [
				{"qui": &"cain", "texte": "Alors qui le peut ?"},
				{"qui": &"lilith", "texte": "Celui qui ne répond plus."},
				{"qui": &"lilith", "texte": "Personne n'a accepté son pari, Caïn. Il parie seul, contre un Ciel qui se tait.", "secousse": 0.3},
				{"qui": &"cain", "texte": "Alors je descendrai jusqu'à ce que quelqu'un réponde."},
			],
		},
	],

	&"lilith_job": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "La Première Nuit est tombée."},
				{"texte": "En enfer, rien ne meurt tout à fait."},
			],
		},
		{
			"fond": &"arene",
			"zoom": [1.1, 1.0],
			"acteurs": [
				{"id": &"lilith", "planche": &"lilith", "pos": Vector2(330, 120), "echelle": 7.0,
					"miroir": true, "teinte": Color(0.7, 0.5, 0.6)},
				{"id": &"job", "planche": &"job", "pos": Vector2(-300, 130), "echelle": 7.0,
					"depuis": Vector2(-1100, 130)},
			],
			"lignes": [
				{"qui": &"lilith", "texte": "Job. L'homme qui n'a jamais dit non."},
				{"qui": &"job", "texte": "J'ai dit beaucoup de choses. On ne les a pas toutes écrites."},
				{"qui": &"lilith", "texte": "Moi, j'ai dit non. Une seule fois, au premier jardin. On m'a chassée pour ça."},
				{"qui": &"lilith", "texte": "Toi, on t'a tout pris, et tu as remercié."},
				{"qui": &"job", "texte": "Je n'ai pas remercié. J'ai attendu une réponse."},
				{"qui": &"lilith", "texte": "Et elle est venue ?"},
				{"qui": &"job", "texte": "Du milieu d'une tempête. Elle ne répondait à rien de ce que j'avais demandé."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.15],
			"acteurs": [
				{"id": &"lilith", "planche": &"lilith", "pos": Vector2(330, 120), "echelle": 7.0,
					"miroir": true, "teinte": Color(0.7, 0.5, 0.6)},
				{"id": &"job", "planche": &"job", "pos": Vector2(-300, 130), "echelle": 7.0},
			],
			"lignes": [
				{"qui": &"lilith", "texte": "Alors écoute celle-ci. Là-haut, personne n'a tenu le pari. Il joue seul.", "secousse": 0.3},
				{"qui": &"lilith", "texte": "Tu souffres pour un adversaire qui ne regarde même pas."},
				{"qui": &"job", "texte": "Je n'ai jamais souffert pour lui."},
				{"qui": &"job", "texte": "Mais maintenant, je sais à qui poser la question."},
			],
		},
	],

	&"lilith_loth": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "La Première Nuit est tombée."},
				{"texte": "En enfer, rien ne meurt tout à fait."},
			],
		},
		{
			"fond": &"arene",
			"zoom": [1.1, 1.0],
			"acteurs": [
				{"id": &"lilith", "planche": &"lilith", "pos": Vector2(330, 120), "echelle": 7.0,
					"miroir": true, "teinte": Color(0.7, 0.5, 0.6)},
				{"id": &"loth", "planche": &"loth", "pos": Vector2(-300, 130), "echelle": 7.0,
					"depuis": Vector2(-1100, 130)},
			],
			"lignes": [
				{"qui": &"lilith", "texte": "Le fuyard. Tu cours moins vite qu'à Sodome."},
				{"qui": &"loth", "texte": "Ma femme. Tu l'as vue ?"},
				{"qui": &"lilith", "texte": "Je vois toutes celles qu'on a punies d'avoir regardé."},
				{"qui": &"lilith", "texte": "Tu crois qu'elle s'est retournée par curiosité ? Tes filles aînées étaient restées dans la ville."},
				{"qui": &"loth", "texte": "… Je le sais."},
				{"qui": &"lilith", "texte": "Tu le savais, et tu as couru quand même. Elle, elle s'est retournée."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.15],
			"acteurs": [
				{"id": &"femme", "planche": &"femme_sel", "pos": Vector2(0, -60), "echelle": 5.0,
					"miroir": true, "sel": true, "cache": true},
				{"id": &"lilith", "planche": &"lilith", "pos": Vector2(330, 120), "echelle": 7.0,
					"miroir": true, "teinte": Color(0.7, 0.5, 0.6)},
				{"id": &"loth", "planche": &"loth", "pos": Vector2(-300, 130), "echelle": 7.0},
			],
			"lignes": [
				{"qui": &"loth", "texte": "Où est-elle ?"},
				{"qui": &"lilith", "texte": "Plus bas. Toujours plus bas.", "montre": &"femme"},
				{"qui": &"lilith", "texte": "Et sache ceci, fuyard : ce pari, personne là-haut ne l'a accepté. Il joue seul.", "secousse": 0.3},
				{"qui": &"lilith", "texte": "Il ne te la rendra pas. Il n'a personne à qui prouver quoi que ce soit."},
				{"qui": &"loth", "texte": "Alors je ne lui demanderai pas. J'irai la prendre."},
			],
		},
	],

	# --- Lucifer (vague 25) ------------------------------------------------
	# L'ENTRÉE : la première fois que CE personnage atteint Lucifer.
	# LA FIN : chacun obtient ce qu'il était venu chercher — Caïn une fin, Job
	# une réponse (il n'y en a pas), Loth sa femme — puis Lucifer se relève,
	# et le sceau de ce personnage se brise. Les trois brisés, le portail vers
	# Hélel s'ouvre.

	&"lucifer_entree_cain": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Le fond de l'enfer n'a pas de fond."},
				{"texte": "Il a une salle, et quelqu'un qui attend."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.12],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(330, 90), "echelle": 8.0, "miroir": true},
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-330, 140), "echelle": 7.0, "depuis": Vector2(-1100, 140)},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Caïn. Tu as traversé mon enfer pour une fin que je t'ai promise."},
				{"qui": &"cain", "texte": "Lilith dit que tu ne peux pas me la donner."},
				{"qui": &"lucifer", "texte": "Lilith a toujours eu un faible pour ceux qu'on chasse."},
				{"qui": &"cain", "texte": "Alors prouve-lui qu'elle a tort."},
				{"qui": &"lucifer", "texte": "Viens. On verra bien lequel de nous deux tombe.", "son": &"boss", "secousse": 0.6},
			],
		},
	],
	&"lucifer_entree_job": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Le fond de l'enfer n'a pas de fond."},
				{"texte": "Il a une salle, et quelqu'un qui attend."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.12],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(330, 90), "echelle": 8.0, "miroir": true},
				{"id": &"job", "planche": &"job", "pos": Vector2(-330, 140), "echelle": 7.0, "depuis": Vector2(-1100, 140)},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Te voilà, Job. Sans troupeaux, sans maison, sans rien. Comme la première fois."},
				{"qui": &"job", "texte": "Tu joues seul. Lilith me l'a dit."},
				{"qui": &"lucifer", "texte": "Et pourtant tu es venu jusqu'ici. Pour qui, sinon pour moi ?"},
				{"qui": &"job", "texte": "Pour la question. Pourquoi moi ?"},
				{"qui": &"lucifer", "texte": "Parce que tu n'as pas plié. Je ne supporte pas ce qui ne plie pas.", "son": &"boss", "secousse": 0.6},
			],
		},
	],
	&"lucifer_entree_loth": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Le fond de l'enfer n'a pas de fond."},
				{"texte": "Il a une salle, et quelqu'un qui attend."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.12],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(330, 90), "echelle": 8.0, "miroir": true},
				{"id": &"loth", "planche": &"loth", "pos": Vector2(-330, 140), "echelle": 7.0, "depuis": Vector2(-1100, 140)},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Le fuyard ne fuit plus. Que cherches-tu, si près du feu ?"},
				{"qui": &"loth", "texte": "Tu le sais."},
				{"qui": &"lucifer", "texte": "Elle est derrière moi. Il te suffirait de ne pas te retourner, cette fois encore."},
				{"qui": &"loth", "texte": "Je ne vais pas me retourner. Je vais passer.", "son": &"boss", "secousse": 0.6},
			],
		},
	],

	&"lucifer_fin_cain": [
		{
			"fond": &"arene",
			"zoom": [1.1, 1.0],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(330, 110), "echelle": 7.0, "miroir": true, "teinte": Color(0.62, 0.42, 0.42)},
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-300, 130), "echelle": 7.0},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Assez… Tu la veux, ta fin ? Prends-la."},
				{"texte": "Sur le front de Caïn, la Marque pâlit."},
				{"texte": "Pour la première fois depuis Abel, son cœur recommence à compter les battements."},
				{"qui": &"cain", "texte": "Enfin. Je peux mourir."},
				{"qui": &"cain", "texte": "Pas tout de suite. Mais je peux."},
			],
		},
	],
	&"lucifer_fin_job": [
		{
			"fond": &"arene",
			"zoom": [1.1, 1.0],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(330, 110), "echelle": 7.0, "miroir": true, "teinte": Color(0.62, 0.42, 0.42)},
				{"id": &"job", "planche": &"job", "pos": Vector2(-300, 130), "echelle": 7.0},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Tu veux ta réponse ? La voici."},
				{"qui": &"lucifer", "texte": "Il n'y avait pas de raison. Il n'y en a jamais eu."},
				{"qui": &"job", "texte": "…"},
				{"qui": &"job", "texte": "Alors je n'ai plus de question."},
				{"texte": "Pour la première fois depuis la tempête, Job ne demande plus rien. Et il se tient droit."},
			],
		},
	],
	&"lucifer_fin_loth": [
		{
			"fond": &"arene",
			"zoom": [1.0, 1.12],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(480, 150), "echelle": 6.0, "miroir": true, "teinte": Color(0.62, 0.42, 0.42)},
				{"id": &"femme", "planche": &"femme_sel", "pos": Vector2(160, 110), "echelle": 7.0, "miroir": true, "sel": true},
				{"id": &"loth", "planche": &"loth", "pos": Vector2(-320, 130), "echelle": 7.0, "depuis": Vector2(-1100, 130)},
			],
			"lignes": [
				{"texte": "Derrière le trône, une statue de sel, tournée vers une ville qui n'existe plus."},
				{"qui": &"loth", "texte": "Je suis revenu."},
				{"texte": "Le sel se fend. Sous la croûte blanche, une main tiède.", "dessale": &"femme", "secousse": 0.3},
				{"qui": &"edith", "texte": "Tu t'es retourné.", "son": &"baiser"},
				{"qui": &"loth", "texte": "Cette fois, oui."},
			],
		},
	],

	&"lucifer_releve": [
		{
			"fond": &"abime",
			"zoom": [1.0, 1.2],
			"acteurs": [
				{"id": &"lucifer", "planche": &"lucifer", "pos": Vector2(0, 40), "echelle": 9.0, "miroir": true, "cache": true, "lumiere": true},
			],
			"lignes": [
				{"qui": &"lucifer", "texte": "Tu croyais que la lumière s'éteignait si facilement ?", "montre": &"lucifer", "son": &"boss", "secousse": 1.0},
				{"qui": &"lucifer", "texte": "Avant d'être Lucifer, j'étais autre chose. Et ce que j'étais ne meurt pas."},
				{"qui": &"lucifer", "texte": "Trois sceaux me tiennent loin de ce que j'étais. Tu viens d'en briser un."},
			],
		},
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Un sceau se brise.  Sceaux brisés : {sceaux} / 3."},
				{"qui": &"lucifer", "texte": "Il en reste {reste}. J'ai l'éternité, et vous n'êtes que trois.", "si_moins": 3},
				{"texte": "L'enfer sans fin s'ouvre devant vous.", "si_moins": 3},
				{"qui": &"lucifer", "texte": "Le dernier vient de céder. Le portail est ouvert.", "si_min": 3},
				{"qui": &"lucifer", "texte": "Venez donc voir qui j'étais.", "si_min": 3},
			],
		},
	],

	# --- Hélel, fils de l'Aurore ---------------------------------------------
	# Le nom d'avant la chute : Isaïe 14:12, « Hêlēl ben Šāḥar », que la
	# Vulgate traduit « Lucifer ». Les trois sceaux ont lié les trois âmes :
	# elles n'ont plus qu'un corps pour entrer, d'où les changements de
	# personnage en plein combat.

	&"helel_entree": [
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Avant la chute, il portait la lumière du matin."},
				{"texte": "Isaïe l'appelait Hélel, fils de l'Aurore. Rome a traduit : Lucifer."},
			],
		},
		{
			"fond": &"abime",
			"zoom": [1.0, 1.12],
			"acteurs": [
				{"id": &"helel", "planche": &"lucifer", "pos": Vector2(0, 30), "echelle": 9.0, "miroir": true, "cache": true, "lumiere": true},
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-560, 190), "echelle": 5.0},
				{"id": &"job", "planche": &"job", "pos": Vector2(-380, 230), "echelle": 5.0},
				{"id": &"loth", "planche": &"loth", "pos": Vector2(-200, 190), "echelle": 5.0},
			],
			"lignes": [
				{"qui": &"helel", "texte": "Hélel. C'est ainsi qu'on m'appelait, quand on m'appelait encore.", "montre": &"helel", "son": &"boss", "secousse": 1.0},
				{"qui": &"helel", "texte": "Les trois sceaux brisés vous ont liés. Là où vous entrez, vous entrez ensemble."},
				{"qui": &"helel", "texte": "Trois âmes, un seul corps pour passer. Qu'importe."},
				{"qui": &"helel", "texte": "Je vous prendrai l'un après l'autre, dans le désordre."},
			],
		},
	],
	&"helel_fin": [
		{
			"fond": &"abime",
			"zoom": [1.1, 1.0],
			"acteurs": [
				{"id": &"helel", "planche": &"lucifer", "pos": Vector2(300, 90), "echelle": 8.0, "miroir": true, "teinte": Color(0.75, 0.7, 0.6)},
				{"id": &"cain", "planche": &"cain", "pos": Vector2(-520, 170), "echelle": 6.0},
				{"id": &"job", "planche": &"job", "pos": Vector2(-330, 210), "echelle": 6.0},
				{"id": &"loth", "planche": &"loth", "pos": Vector2(-140, 170), "echelle": 6.0},
			],
			"lignes": [
				{"qui": &"helel", "texte": "Le Ciel… ne regardait pas."},
				{"qui": &"cain", "texte": "Non. Mais nous, si."},
				{"qui": &"job", "texte": "Tu as perdu ton pari. Deux fois, maintenant."},
				{"qui": &"loth", "texte": "Et personne ne s'est retourné pour te voir tomber."},
			],
		},
		{
			"fond": &"noir",
			"lignes": [
				{"texte": "Le Pari est rompu."},
				{"texte": "Ce que devient un enfer sans parieur, personne ne le sait encore."},
			],
		},
		{
			"fond": &"noir",
			"titre": ["INFERNUM", "Le Pari est rompu"],
			"duree": 4.0,
		},
	],
}


static func prologue_id(personnage: StringName) -> StringName:
	return StringName("prologue_%s" % personnage)


## Ce que ce profil n'a pas encore vu avant de lancer une partie avec ce
## personnage : le Pari la toute première fois, puis le prologue de chaque
## damné la première fois qu'on le joue.
static func pending_for(personnage: StringName) -> Array[StringName]:
	var file: Array[StringName] = []
	if not SaveGame.has_seen_story(LE_PARI):
		file.append(LE_PARI)
	var prologue := prologue_id(personnage)
	if CINEMATIQUES.has(prologue) and not SaveGame.has_seen_story(prologue):
		file.append(prologue)
	return file


## Après la mort d'un boss, la première fois que CE personnage le bat : la
## scène `<boss>_<personnage>` si elle existe. `boss` est le nom du fichier de
## sa scène (« lilith »), pas son nom affiché.
static func pending_after_boss(boss: StringName, personnage: StringName) -> Array[StringName]:
	var file: Array[StringName] = []
	var id := StringName("%s_%s" % [boss, personnage])
	if CINEMATIQUES.has(id) and not SaveGame.has_seen_story(id):
		file.append(id)
	return file


## Pour « Revoir » : le début, vu ou non, puis ce que ce personnage a DÉJÀ vu
## plus loin — les scènes d'après boss ne se divulguent pas depuis le menu.
static func all_for(personnage: StringName) -> Array[StringName]:
	var file: Array[StringName] = [LE_PARI]
	if CINEMATIQUES.has(prologue_id(personnage)):
		file.append(prologue_id(personnage))
	var suite: Array[StringName] = []
	for boss in BOSSES_RACONTES:
		suite.append(StringName("%s_%s" % [boss, personnage]))
	suite.append(StringName("lucifer_entree_%s" % personnage))
	suite.append(StringName("lucifer_fin_%s" % personnage))
	for id in suite:
		if CINEMATIQUES.has(id) and SaveGame.has_seen_story(id):
			file.append(id)
	# Le Pari rompu appartient aux trois : il se revoit avec n'importe lequel.
	for id in [HELEL_ENTREE, HELEL_FIN]:
		if SaveGame.has_seen_story(id):
			file.append(id)
	return file
