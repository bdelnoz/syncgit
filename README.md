################################################################################
# DOCUMENT INFORMATION
################################################################################
# Document Name    : README.md
# Document Full Path & name : README.md
# Author         : Bruno DELNOZ
# Email          : bruno.delnoz@protonmail.com
# Version        : V1.0
# Date  / Time   : 2026-02-09 19:22:16
# Project : syncgit
# Short description : Project overview
################################################################################
# Document Name    : README.md
# Document Full Path & name : README.md
# Author         : Bruno DELNOZ
# Email          : bruno.delnoz@protonmail.com
# Version        : V1.0
# Date  / Time   : 2026-02-09 19:22:16
# Project : syncgit
# Short description : Project overview
################################################################################
# syncgit.sh

> **Version** : v1.2.0
> **Date**    : 2026-03-03
> **Author**  : Bruno DELNOZ <bruno.delnoz@protonmail.com>

---

## Description

Scanne récursivement un répertoire racine pour trouver tous les dépôts Git (dossiers `.git`).
Pour chaque dépôt trouvé, le script exécute soit :

1. **La séquence de sync par défaut** (sans `--cmd`) :
   ```bash
   git checkout <branch>        # [a/5]
   git add .                    # [b/5]
   git commit -m "commit last version done by syncgit.sh"   # [c/5] sauté si rien à committer
   git push --set-upstream --force origin <branch>          # [d/5]
   git push --force origin --all                            # [e/5]
   ```
   Chaque step est affiché avec son statut `✔ done` ou `✘ FAILED (exit N)`.
   Si un step échoue, les steps suivants sont sautés et le repo est marqué FAILED.

   Chaque repo est encadré clairement :
   ```
   ╔══════════════════════════════════════════════════════════════════╗
   ║  REPO [3/12]  /mnt/data2_78g/Security/scripts/mon-projet
   ║  DIR  : /mnt/data2_78g/Security/scripts/mon-projet
   ╚══════════════════════════════════════════════════════════════════╝
     ┌─ [a/5] git checkout main
     └─ ✔ done
     ┌─ [b/5] git add .
     └─ ✔ done
     ┌─ [c/5] git commit
     └─ ✔ nothing to commit – skipped
     ┌─ [d/5] git push --set-upstream --force origin main
     └─ ✔ done
     ┌─ [e/5] git push --force origin --all
     └─ ✔ done
     ✔ SUCCESS : /mnt/data2_78g/Security/scripts/mon-projet
   ```

2. **Une commande personnalisée** via `--cmd "<commande>"`.
   Utiliser `--cmd_mode bash-i` pour les commandes interactives shell.

---

## Quick Start

```bash
# Vérifier les prérequis
syncgit.sh --prerequis

# Sync par défaut sur tous les repos du dossier courant
syncgit.sh --exec

# Sync sur un dossier racine spécifique
syncgit.sh --exec --root_dir /mnt/data/Security

# Simulation (dry-run, aucun changement réel)
syncgit.sh --simulate

# Simulation sur un dossier spécifique
syncgit.sh --simulate --root_dir /mnt/data/Security

# Commande personnalisée dans chaque repo
syncgit.sh --exec --cmd "git pull --rebase"

# Répéter automatiquement toutes les 5 minutes
syncgit.sh --exec --root_dir /mnt/data --recurrent 300

# Purger les logs et résultats
syncgit.sh --purge --yes
```

---

## Arguments

| Argument        | Court  | Description                                  | Défaut           |
|-----------------|--------|----------------------------------------------|------------------|
| `--exec`        | `-exe` | Lance la logique de sync principale          | –                |
| `--simulate`    | `-s`   | Dry-run (aucun changement réel)              | –                |
| `--root_dir`    | –      | Répertoire racine à scanner                  | `.`              |
| `--dest_dir`    | –      | Dossier de sortie pour les fichiers résultat | `./results`      |
| `--results_dir` | –      | Alias de `--dest_dir`                        | `./results`      |
| `--logs_dir`    | –      | Dossier pour les fichiers de log             | `./logs`         |
| `--branch`      | –      | Branche git (défaut main, validée)           | `main`           |
| `--cmd`         | –      | Commande shell personnalisée par repo        | (séquence défaut)|
| `--cmd_mode`    | –      | `direct` ou `bash-i` (support alias)         | `direct`         |
| `--recurrent`   | –      | Répéter toutes les N secondes                | désactivé        |
| `--prerequis`   | `-pr`  | Vérifier les prérequis                       | –                |
| `--install`     | `-i`   | Installer les prérequis manquants            | –                |
| `--changelog`   | `-ch`  | Afficher le changelog complet                | –                |
| `--purge`       | `-pu`  | Supprimer ./logs et ./results                | –                |
| `--yes`         | –      | Confirmation requise pour `--purge`          | –                |
| `--help`        | `-h`   | Afficher l'aide                              | –                |

---

## Notes

- `--simulate` est une action autonome — pas besoin de `--exec --simulate`
- `--branch` valide le nom : seuls les caractères `a-z A-Z 0-9 / _ - .` sont acceptés
- Les logs et résultats sont toujours générés **à côté du script** (via `BASH_SOURCE[0]`),
  peu importe le répertoire depuis lequel le script est appelé
- Le script ne génère ni ne modifie jamais `README.md` ou `CHANGELOG.md`

---

## Fichiers générés

| Type      | Chemin                                                    |
|-----------|-----------------------------------------------------------|
| Logs      | `<script_dir>/logs/log.syncgit.sh.<TIMESTAMP>.log`        |
| Résultats | `<script_dir>/results/summary.syncgit.sh.<TIMESTAMP>.txt` |

---

## Auteur

| Champ  | Valeur                      |
|--------|-----------------------------|
| Nom    | Bruno DELNOZ                |
| Email  | bruno.delnoz@protonmail.com |
