> **Version** : v1.3.4
> **Date**    : 2026-03-27
> **Author**  : Bruno DELNOZ <bruno.delnoz@protonmail.com>

---

## Description

Scanne récursivement un répertoire racine pour trouver tous les dépôts Git (dossiers `.git`).
Pour chaque dépôt trouvé, le script exécute soit :

1. **La séquence de sync par défaut** (sans `--cmd`) :
   ```bash
   git branch syncgit-snapshot/YYYYMMDD-HHhMM                  # [a/6]
   git checkout <branch>                                        # [b/6]
   git add .                                                    # [c/6]
   git commit -m "commit last version done by syncgit.sh user: <USER>   date : <YYYY-MM-DD> time <HH:MM:SS>"  # [d/6] sauté si rien à committer
   [guard] si `origin/<branch>` est ahead, skip push et FAIL    # pré-check
   git push --set-upstream --force origin <branch>             # [e/6]
   git push --force origin --all                               # [f/6]
   ```
   Chaque step est affiché avec son statut `✔ done` ou `✘ FAILED (exit N)`.
   Si un step échoue, les steps suivants sont sautés et le repo est marqué FAILED.

   Chaque repo est encadré clairement :
   ```
   ╔══════════════════════════════════════════════════════════════════╗
   ║  REPO [3/12]  /mnt/data2_78g/Security/scripts/mon-projet
   ║  DIR  : /mnt/data2_78g/Security/scripts/mon-projet
   ╚══════════════════════════════════════════════════════════════════╝
    ┌─ [a/6] git branch syncgit-snapshot/20260327-15h47
    └─ ✔ done
    ┌─ [b/6] git checkout main
    └─ ✔ done
    ┌─ [c/6] git add .
    └─ ✔ done
    ┌─ [d/6] git commit
    └─ ✔ nothing to commit – skipped
    ┌─ [e/6] git push --set-upstream --force origin main
    └─ ✔ done
    ┌─ [f/6] git push --force origin --all
    └─ ✔ done
     ✔ SUCCESS : /mnt/data2_78g/Security/scripts/mon-projet
   ```

2. **Une commande personnalisée** via `--cmd "<commande>"`.

---

## Warnings automatiques

Le script peut intervenir automatiquement sur un repo et signaler l'opération via un WARNING :

| Statut   | Warning                                              | Déclencheur                                                                 |
|----------|------------------------------------------------------|-----------------------------------------------------------------------------|
| ✔ SYNCED | `WARNING SSH to HTTPS applied`                       | Remote en `git@github.com:` ou `git@gitlab.com:` → converti en HTTPS       |
| ✔ SYNCED | `WARNING main does not exists - created from master` | Branche `main` absente mais `master` présente → `main` créée depuis master  |
| ✔ SYNCED | `WARNING current branch <nom> behind main`           | Branche courante ≠ `main` avec changements non commités → auto-commit `wip` |
| ✔ SYNCED | `WARNING BIG FILES DETECTED - push would fail`       | Blobs > 100MB détectés en historique (en `--simulate` uniquement)           |
| ✘ FAILED | `BIG FILES DETECTED`                                 | Push échoué + blobs > 100MB détectés dans l'historique git                  |
| ✘ FAILED | `remote ahead from local`                            | `origin/<branch>` contient des commits absents en local → push forcé ignoré |

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

# Exclure des repos spécifiques
syncgit.sh --exec --exclude "LinkedIn-Learning-Downloader;kali-arm"

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
| `--exclude`     | –      | Liste de repos à ignorer (séparés par `;`)   | –                |
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
- Les remotes SSH (`git@github.com:` / `git@gitlab.com:`) sont automatiquement convertis en HTTPS
- En `--simulate`, les blobs > 100MB sont détectés proactivement sans exécuter le push

---

## Fichiers générés

| Type          | Chemin                                                          |
|---------------|-----------------------------------------------------------------|
| Logs          | `<script_dir>/logs/log.syncgit.sh.<TIMESTAMP>.log`              |
| Résultats     | `<script_dir>/results/summary.syncgit.sh.<TIMESTAMP>.txt`       |
| Stderr        | `<script_dir>/logs/stderr.syncgit.sh.<TIMESTAMP>.log`           |
| Gros fichiers | `<script_dir>/logs/largefiles.syncgit.sh.<TIMESTAMP>.log`       |

---

## Auteur

| Champ  | Valeur                      |
|--------|-----------------------------|
| Nom    | Bruno DELNOZ                |
| Email  | bruno.delnoz@protonmail.com |
