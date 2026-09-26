# biberon-ananas

Je souhaite que tu prennes fortement exemple sur l'application "recipe-ananas" dans ../recipe-ananas.

Ensuite je veux que tu crée une nouvelle application, avec le même système de mise à jour.
Utilise le même design aussi.

Cette nouvelle application est une application d'enregistrement d'évenements pour bébé.
Sur cette on doit pouvoir enregistrer un évenement de type "allaitement/biberon/tirage de lait/poids/taille".
Avant toute chose il faut pouvoir créer un enfant, définir son nom/sexe/date de naissance.

Allaitement : On doit pouvoir renseigner une date de début automatiquement défini par défaut à la date et heure ou on est actuellement.
Ensuite on doit pouvoir sélectionner le sein concerné, le gauche, le droit ou les deux.
Et ensuite il doit y avoir un minuteur qui nous permet de le lancer puis de l'arrêter quand on a terminé. Quand on clique sur arrêter une popup de confirmation d'arret doit s'afficher.
Et ensuite un boutton sauvegarder pour enregistrer cet évenement.

Biberon : On doit pouvoir renseigner une date de début automatiquement défini par défaut à la date et heure ou on est actuellement. On doit avoir un selecteur de quantité bu en mL (de 10 à 300 mL avec une option N/A si jamais on en sait pas)
Et ensuite un boutton sauvegarder pour enregistrer cet évenement.

Tirage du lait : On doit pouvoir renseigner une date de début automatiquement défini par défaut à la date et heure ou on est actuellement.
Ensuite on doit pouvoir sélectionner le sein concerné, le gauche, le droit ou les deux.
Et ensuite il doit y avoir un minuteur qui nous permet de le lancer puis de l'arrêter quand on a terminé. Quand on clique sur arrêter une popup de confirmation d'arret doit s'afficher.
Et ensuite un boutton sauvegarder pour enregistrer cet évenement.

Poids : On doit pouvoir définir le poids de l'enfant en Kg puis sauvegarder.

taille : On doit pouvoir définir la taille en cm puis sauvegarder.

Ensuite il doit y avoir un onglet "Journal" défini sur la date du jour actuel par défaut qui permet le suivi dans chaque catégorie définie qui récapitule la liste des évenements à la date d'enregistrement ou la date de début de l'action (allaitement/biberon).

## Précisions validées

- L'application doit gérer plusieurs enfants et permettre de choisir l'enfant actif.
- Le sexe de l'enfant est choisi parmi « Fille » et « Garçon ».
- Les événements enregistrés peuvent être modifiés et supprimés depuis le journal.
- Pour l'allaitement et le tirage, l'heure de début et la durée peuvent être corrigées manuellement. Le minuteur sert à mesurer la durée.
- Lorsqu'on arrête le minuteur, une confirmation d'arrêt s'affiche. Après confirmation, un bouton permet de valider l'événement ; sa validation ouvre le journal filtré sur la catégorie correspondante. La confirmation d'arrêt seule n'enregistre pas l'événement.
- Le journal présente les événements par ordre chronologique, propose un filtre par catégorie et permet de consulter aujourd'hui ainsi que les jours passés.
- Le poids est saisi au centième de kilogramme (ex. 3,50 kg) et la taille au centimètre entier (ex. 52 cm). La date et l'heure de ces mesures correspondent à leur saisie.
