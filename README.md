# my-hp11c
## Application macOS autonome

```bash
./macos/build.sh            # construit dist/HP-11C.app
./macos/build.sh --install  # construit et copie dans /Applications
```

App native (Swift + WebKit, ~2 Mo, Intel et Apple Silicon) qui embarque `index.html`.
La pile et les registres sont conservés entre deux lancements.
Après une modification de `index.html`, relancer `./macos/build.sh`.

## Programmation

| Touches | Effet |
|---|---|
| `g P/R` | entrer / sortir du mode programme (indicateur PRGM, lignes `001-42,21,11`) |
| `SST` / `g BST` | ligne suivante / précédente |
| `←` | (mode programme) supprime la ligne courante |
| `f CLEAR PRGM` | (mode programme) efface tout le programme ; sinon revient en ligne 000 |
| `GTO . nnn` | va à la ligne nnn |
| `f LBL A–E / 0–9` | étiquette |
| `f A–E`, `GSB x` | lance le programme à l'étiquette (`R/S` : depuis la ligne courante) |
| `GTO`, `GSB`, `g RTN`, `R/S`, `f PSE` | sauts, sous-programmes (4 niveaux), arrêt, pause |
| tests `x≤y x>y x≠y x=y x<0 x>0 x≠0 x=0`, `g F? n` | sautent la ligne suivante si faux |
| `f DSE`, `f ISG` | boucles sur I = nnnnn.xxxyy |
| `STO/RCL I`, `(i)`, `GTO I` | registre I et adressage indirect |
| `f USER` | A–E lancent les étiquettes sans `f` |
| `g MEM` | lignes libres (203 au total) |

Le listage du programme s'affiche dans le panneau de droite (clic sur une ligne pour s'y placer).
Une touche quelconque arrête un programme en cours (« running »).

## Touche ON et combinaisons

`ON` éteint / rallume ; la mémoire est continue (tout est retrouvé à l'identique).
Sur la vraie HP-11C on maintient ON, on appuie sur une touche puis on relâche ON.
Ici, en deux temps : **calculatrice éteinte**, appuyer sur la touche **puis** sur `ON`.

| Séquence (éteinte) | Effet |
|---|---|
| `·` puis `ON` | bascule virgule / point décimal (1.234,50 ↔ 1,234.50) |
| `−` puis `ON` | remise à zéro complète de la mémoire (« Pr Error », FIX 4, DEG) |
| `×` puis `ON` | autotest (« running » puis tous les segments) |
