# CHANGELOG – syncgit.sh

> **Auteur** : Bruno DELNOZ <bruno.delnoz@protonmail.com>

---

## v1.2.0 – 2026-03-03 – Bruno DELNOZ

Bugfixes, hardening et nettoyage.

- **FIXED**: `cd` sans retour au répertoire d'origine dans la boucle repos → remplacé
  par `pushd`/`popd` avec `popd` explicite dans chaque branche (`continue`, skip, fin normale)

- **FIXED**: `RESULT_FILE` calculé avec `RUN_TS` vide lors du parsing des arguments
  (ligne parasite dans `--dest_dir` supprimée — `init_run_context()` gère seul)

- **FIXED**: `_check_one()` imbriquée dans `check_prerequisites()` → extraite en
  fonction globale `prereq_check_one()` avec flag partagé `__prereq_all_pass`

- **FIXED**: `read` sans fallback dans `install_prerequisites()` — crashait sur stdin
  non-interactif (cron, pipe, CI) → ajout de `|| answer="N"`

- **FIXED**: `find` remontait les `.git` des submodules git → ajout de
  `-not -path '*/.git/*'` pour les exclure

- **FIXED**: `generate_docs()` écrasait `./README.md` et `./CHANGELOG.md` à chaque
  `--exec` → fonction entièrement supprimée, le script ne touche plus jamais aux `.md`

- **ADDED**: `--branch` validé contre le charset `[a-zA-Z0-9/_.-]`

- **ADDED**: `--simulate` est maintenant une action autonome (plus besoin de `--exec --simulate`)

- **ADDED**: affichage `┌─ [a/5]...[e/5]` avec `✔ done` / `✘ FAILED (exit N)` pour
  chaque step de la séquence par défaut — avancement visible en temps réel

- **IMPROVED**: gestion des erreurs step par step — si `checkout`, `commit` ou `push`
  échoue, les steps suivants sont sautés immédiatement et le repo est marqué FAILED
  avec le message d'erreur git affiché directement (ex: gros fichiers, remote reject)

- **ADDED**: encadré `╔ REPO [N/TOTAL] ╚` pour chaque repo traité — chemin et
  dossier clairement visibles dans le terminal

- **ADDED**: affichage `✔ SUCCESS` / `✘ FAILED (exit N)` en fin de traitement
  de chaque repo

- **CHANGED**: message de commit → `"commit last version done by syncgit.sh"`

- **CHANGED**: séquence par défaut — ajout de `git push --force origin --all` (step e)
  après `git push --set-upstream --force origin <branch>`

- **REMOVED**: toutes les références à l'alias `gita` et `~/.bash_aliases`

- **REMOVED**: check prérequis `~/.bash_aliases`

- **REMOVED**: `generate_docs()` et le dossier `./infos/` ne sont plus utilisés

---

## v1.1.0 – 2026-02-28 – Bruno DELNOZ

Merge des meilleures fonctionnalités de la version de référence (v1.3.0 style).

- **ADDED**: `set -Eeuo pipefail` + `IFS=$'\n\t'` — mode strict bash complet
- **ADDED**: `ts_now()` / `ts_human()` / `die()` / `sep()` — fonctions utilitaires
- **ADDED**: `--cmd_mode direct|bash-i`
- **ADDED**: `--recurrent <seconds>` — répète le run toutes les N secondes
- **ADDED**: `--root_dir` remplace `--base_dir`
- **ADDED**: `--results_dir` alias de `--dest_dir`
- **ADDED**: `--logs_dir` pour surcharger le dossier logs
- **ADDED**: `--yes` flag obligatoire pour `--purge`
- **ADDED**: `SCRIPT_DIR` auto-détecté via `BASH_SOURCE[0]`
- **ADDED**: `init_run_context()` — initialise `RUN_TS`, `LOG_FILE`, `RESULT_FILE` par pass
- **UPDATED**: pas de version dans le nom de fichier
- **UPDATED**: `run_cmd()` utilise `CMD_MODE` pour choisir entre `bash -c` et `bash -ic`
- **UPDATED**: commit sauté proprement si rien à committer (`git diff --cached --quiet`)

---

## v1.0.1 – 2026-02-28 – Bruno DELNOZ

- **FIXED**: exécution via `bash -i -c` pour l'expansion des alias shell
- **FIXED**: check prérequis teste la commande custom via `bash -i -c "type <cmd>"`
- **UPDATED**: option renommée de `--alias` à `--cmd`

---

## v1.0.0 – 2026-02-28 – Bruno DELNOZ

Version initiale.

- Scan récursif des `.git` via `find`
- Bascule automatique de branche avant exécution
- Support complet des arguments : `--exec` / `--simulate` / `--prerequis` / `--install` / `--changelog` / `--purge` / `--help`
- Affichage de la progression par étape (format N/TOTAL)
- Création automatique de `./logs`, `./results`
- Liste numérotée des actions post-exécution
