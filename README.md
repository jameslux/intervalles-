# Intervalles

Prototype de jeu tactique PC en 2D, construit avec Godot 4.3. Le prototype explore une boucle de jeu : préparer les ordres d’une escouade, puis regarder les deux camps les exécuter simultanément sur six intervalles courts.

## Ouvrir le projet

1. Installer ou lancer Godot 4.3 ou une version Godot 4 compatible.
2. Importer le dossier qui contient `project.godot`.
3. Lancer la scène principale avec **F6** ou le projet avec **F5**.

Le projet n’embarque aucun asset externe : le terrain et les unités sont dessinés par le prototype.

## Jouer

- Cliquez un combattant bleu pour le sélectionner.
- **Déplacement** puis clic sur une case libre : l’unité avance d’une case par intervalle.
- **Attaquer** puis clic sur une cible rouge : l’unité s’approche et tire dès qu’elle a une ligne de tir.
- **Garder la position** : l’unité ne se déplace pas et tire sur un ennemi visible à portée.
- **Résoudre 6 intervalles** lance la séquence. Les ordres rouges sont choisis automatiquement.
- Les blocs gris arrêtent les déplacements et les tirs.
- Après une victoire ou une défaite, le bouton de résolution permet de recommencer.

Les dégâts d’un même intervalle sont appliqués ensemble. Les unités ont chacune une portée et des dégâts propres; la cadence actuelle est d’un tir tous les deux intervalles.

## État du prototype

Cette tranche sert à valider la lisibilité et le rythme du système d’ordres. Elle contient deux escouades de cinq membres, un terrain fixe, une IA ennemie directe et une condition de victoire par élimination. Il n’y a pas encore d’éditeur de cartes, de sauvegarde, de campagne, d’animations, de son ni d’équilibrage entre classes.
