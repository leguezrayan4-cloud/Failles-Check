class_name DemoProvider
extends VulnProvider
## FaillesCheck — fournisseur de démonstration.
## Source locale de données clairement fictives (marquées DÉMO · FICTIF).
## Sert de solution hors ligne et de catalogue d'exemple.

func source_name() -> String:
	return "démo"

func fetch(query: String, max_results: int) -> void:
	# Léger différé pour émuler une source et laisser l'interface afficher
	# son état de chargement uniformément.
	await get_tree().process_frame
	var q := query.strip_edges().to_lower()
	var out: Array = []
	for v in catalog():
		if q != "":
			var hay := "%s %s %s %s" % [str(v.get("title", "")), str(v.get("product", "")), str(v.get("id", "")), str(v.get("summary", ""))]
			if not hay.to_lower().contains(q):
				continue
		out.append(v)
		if out.size() >= max_results:
			break
	_finish(out, _ok(out))

## Catalogue fictif complet (nouvelle copie à chaque appel).
static func catalog() -> Array:
	var items: Array = [
		{
			"id": "FC-2025-0142",
			"title": "Dépassement de tampon dans le décodage d'images PNG",
			"severity": "critique",
			"score": 9.8,
			"product": "PhotoView Pro",
			"version": "3.2.1 → 3.4.0",
			"date": "2025-04-18",
			"status": "Correctif disponible",
			"summary": "Une image PNG spécialement conçue peut provoquer un dépassement de tampon lors du décodage et permettre l'exécution de code arbitraire.",
			"description": "Le décodeur d'images de PhotoView Pro ne valide pas correctement la taille des blocs tEXt. Un fichier malveillant peut écrire au-delà de la zone allouée, corrompant la mémoire du processus. Un attaquant distant peut exploiter cette faille en incitant l'utilisateur à ouvrir une image piégée.",
			"remediation": "Mettez à jour vers la version 3.4.1 ou supérieure. Désactivez l'aperçu automatique des images provenant de sources non fiables en attendant.",
			"vector": "Réseau / Sans authentification",
		},
		{
			"id": "FC-2025-0118",
			"title": "Exécution de code à distance via une dépendance obsolète",
			"severity": "critique",
			"score": 9.1,
			"product": "WebGuard",
			"version": "7.0.0 → 7.0.9",
			"date": "2025-03-27",
			"status": "Correctif disponible",
			"summary": "Une bibliothèque réseau obsolète permet à un attaquant d'exécuter du code à distance sans authentification.",
			"description": "WebGuard embarque une version vulnérable de sa pile HTTP. Une requête forgée peut déclencher une désérialisation non sûre et aboutir à l'exécution de code. La faille est exploitable sans authentification préalable.",
			"remediation": "Installez la mise à jour 7.0.10. Restreignez l'accès réseau du service aux seuls réseaux de confiance.",
			"vector": "Réseau / Sans authentification",
		},
		{
			"id": "FC-2025-0097",
			"title": "Contournement de l'authentification par injection dans l'en-tête",
			"severity": "elevee",
			"score": 8.2,
			"product": "ComptaFlex",
			"version": "12.4.0 → 12.6.2",
			"date": "2025-02-14",
			"status": "Correctif disponible",
			"summary": "Un en-tête HTTP mal formé permet de contourner le contrôle d'authentification de l'interface d'administration.",
			"description": "Le service d'administration de ComptaFlex analyse un en-tête personnalisé sans neutraliser les caractères de contrôle. Un attaquant peut s'authentifier en tant qu'administrateur en manipulant cet en-tête.",
			"remediation": "Appliquez la version 12.6.3. Limitez l'accès à l'interface d'administration par liste blanche d'adresses IP.",
			"vector": "Réseau / Authentification requise",
		},
		{
			"id": "FC-2025-0083",
			"title": "Élévation de privilèges via un lien symbolique",
			"severity": "elevee",
			"score": 7.8,
			"product": "BackupMaster",
			"version": "5.1.0 → 5.3.4",
			"date": "2025-01-30",
			"status": "Correctif disponible",
			"summary": "Un utilisateur local peut élever ses privilèges en exploitant un lien symbolique lors de la restauration d'archives.",
			"description": "Le processus de restauration suit les liens symboliques fournis dans l'archive. Un utilisateur local peut ainsi écraser des fichiers système et obtenir les droits administrateur.",
			"remediation": "Mettez à jour vers 5.3.5. N'exécutez les restaurations qu'avec des archives de confiance.",
			"vector": "Local / Authentification requise",
		},
		{
			"id": "FC-2025-0061",
			"title": "Divulgation d'informations dans les journaux d'erreur",
			"severity": "moyenne",
			"score": 5.3,
			"product": "HelpDesk Cloud",
			"version": "9.8.0 → 9.9.1",
			"date": "2025-01-12",
			"status": "Correctif disponible",
			"summary": "Les pages d'erreur exposent des chemins internes et des jetons de session dans le corps de la réponse.",
			"description": "En cas d'erreur applicative, HelpDesk Cloud renvoie une trace détaillée incluant des identifiants de session et l'arborescence du serveur. Ces informations facilitent la reconnaissance par un attaquant.",
			"remediation": "Installez la version 9.9.2. Configurez le mode production pour masquer les traces d'erreur.",
			"vector": "Réseau / Sans authentification",
		},
		{
			"id": "FC-2025-0044",
			"title": "Faiblesse du hachage des mots de passe stockés",
			"severity": "moyenne",
			"score": 5.9,
			"product": "ComptaFlex",
			"version": "12.0.0 → 12.6.3",
			"date": "2024-12-19",
			"status": "Correctif disponible",
			"summary": "Les mots de passe sont stockés avec un algorithme de hachage obsolète, sans sel, facilitant les attaques par dictionnaire.",
			"description": "La base locale de ComptaFlex conserve les mots de passe avec une fonction de hachage rapide et sans sel unique. La compromission de la base permet de retrouver rapidement de nombreux mots de passe.",
			"remediation": "Mettez à jour vers 12.6.4. Imposez la réinitialisation des mots de passe après migration.",
			"vector": "Local / Authentification requise",
		},
		{
			"id": "FC-2024-0932",
			"title": "Déni de service par consommation excessive de mémoire",
			"severity": "faible",
			"score": 4.1,
			"product": "WebGuard",
			"version": "7.1.0 → 7.2.0",
			"date": "2024-11-08",
			"status": "Correctif disponible",
			"summary": "Une succession de requêtes malformées fait croître la mémoire du service jusqu'à son interruption.",
			"description": "Le tampon de lecture des requêtes n'est jamais libéré en cas d'erreur de format, ce qui permet à un attaquant de saturer progressivement la mémoire du service et de le rendre indisponible.",
			"remediation": "Installez la version 7.2.2. Activez la limitation de débit sur le serveur exposé.",
			"vector": "Réseau / Sans authentification",
		},
		{
			"id": "FC-2024-0810",
			"title": "Certificat TLS non vérifié lors des mises à jour",
			"severity": "faible",
			"score": 3.7,
			"product": "SpeedDownload",
			"version": "2.9.0 → 3.0.5",
			"date": "2024-10-02",
			"status": "Correctif disponible",
			"summary": "Le client de mise à jour accepte un certificat non valide, exposant à une attaque de type interposition.",
			"description": "Lors du téléchargement des mises à jour, le client désactive la vérification de la chaîne de certificats. Un attaquant positionné sur le réseau peut substituer un paquet falsifié.",
			"remediation": "Mettez à jour vers 3.0.6. Contrôlez l'intégrité des paquets via la signature fournie par l'éditeur.",
			"vector": "Réseau / Authentification requise",
		},
	]
	for v in items:
		v["demo"] = true
		v["source"] = "démo"
		v["url"] = ""
	return items
