# Biberon Ananas

Application Android de suivi du quotidien de bébé, inspirée du thème Material 3 chaleureux de Recettes Ananas.

## Fonctionnalités

- Plusieurs profils enfant : prénom, sexe et date de naissance ; sélection de l’enfant actif.
- Journal local par enfant, daté par défaut d’aujourd’hui, consultable pour les jours passés et filtrable par catégorie.
- Allaitement et tirage : sein gauche, droit ou les deux, début modifiable, minuteur avec confirmation d’arrêt, durée ajustable manuellement.
- Biberon : début modifiable et quantité de 10 à 300 mL par incréments de 10, ou N/A.
- Poids au centième de kilogramme et taille au centimètre entier.
- Modification et suppression d’événements enregistrés.
- Export JSON et restauration de tous les profils, événements et du profil actif, sur le modèle de Recettes Ananas.
- Données conservées localement sur l’appareil avec SharedPreferences ; aucune synchronisation externe.
- Recherche de mises à jour GitHub sur les canaux Stable et Bêta, avec téléchargement et installation d’APK sur Android.

Icône de l’application : [Flaticon, icône 452688](https://cdn-icons-png.flaticon.com/512/452/452688.png).

## Développement

Flutter 3.44.x / Dart 3.12.x et Java 17 sont utilisés.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Pour créer un APK de test :

```sh
flutter build apk --debug
```

## Version et mises à jour Android

La version est déclarée dans `pubspec.yaml` sous la forme `X.Y.Z+build`. Le `versionCode` Android combine les quatre composantes afin de rester croissant d’une release à l’autre. Chaque composante doit rester comprise entre 0 et 99. La version courante est `1.0.0+2`.

L’application vérifie les releases GitHub du dépôt `Whisper40/biberon-ananas` : Stable consulte la dernière release stable ; Bêta recherche la version la plus élevée parmi les releases publiées et accepte les pré-releases. Une release installable doit inclure un APK signé compatible avec l’identifiant `com.biberon.biberon_ananas`.

Le workflow GitHub Actions analyse et teste le code à chaque push/PR vers `main` ou `master`. Tant que les secrets de signature ne sont pas configurés, il génère seulement un APK debug téléchargeable comme artefact et ne publie pas de release. Pour activer les mises à jour intégrées, ajouter dans les secrets Actions du dépôt :

- `KEYSTORE_BASE64` : keystore Android encodé en Base64.
- `KEYSTORE_PASSWORD` : mot de passe du keystore.
- `KEY_ALIAS` : alias de la clé.
- `KEY_PASSWORD` : mot de passe de la clé.

Après configuration, chaque push sur la branche principale construit et publie une pré-release bêta signée. Ne jamais réutiliser la clé de signature d’une autre application ni committer le keystore ou `android/key.properties`.
