# CHANGELOG – syncgit.sh

> **Auteur** : Bruno DELNOZ <bruno.delnoz@protonmail.com>

---

## v1.3.2 – 2026-03-27 – Bruno DELNOZ

Feature.

- **ADDED**: création d'une branche snapshot avant la séquence de sync par défaut :
  `git branch syncgit-snapshot/YYYYMMDD-HHhMM`

---

## v1.3.1 – 2026-03-05 – Bruno DELNOZ

Bugfix + Features + Nettoyage.

- **FIXED**: direction de conversion remote inversée (était HTTPS→SSH) → corrigée en
  SSH→HTTPS : `git@github.com:` / `git@gitlab.com:` → `https://github.com/` / `https://gitlab.com/`
  Warning : `SYNCED - WARNING SSH to HTTPS applied`

- **ADDED**: `--exclude "repo1;repo2;..."` – ignorer des repos par basename ;
  affichés comme `⊘ EXCLUDED` dans la sortie, comptés comme skipped dans le résumé

- **ADDED**: détection des gros fichiers (blobs > 100MB) en mode `--simulate` —
  scan proactif de l'historique git avant le push fictif ;
  Warning : `SYNCED - WARNING BIG FILES DETECTED - push would fail`

- **ADDED**: détection des gros fichiers sur échec de push en `--exec` ;
  sortie : `FAILED - BIG FILES DETECTED` ; liste complète dans `logs/largefiles.<TIMESTAMP>.log`

- **ADDED**: capture stderr — affiché en temps réel ET écrit dans `logs/stderr.<TIMESTAMP>.log`

- **ADDED**: si branche `main` absente et `master` présente → création automatique de `main`
  depuis `master` ; Warning : `SYNCED - WARNING main does not exists - created from master`

- **ADDED**: si branche courante ≠ `main` avec changements non commités bloquant le checkout →
  auto-commit `"wip"` puis bascule sur `main` ;
  Warning : `SYNCED - WARNING current branch <nom> behind main`

- **REMOVED**: `--cmd_mode` et toute référence aux alias shell (`bash -ic`, `bash-i`) —
  `run_cmd()` utilise uniquement `bash -c` désormais

---

## v1.2.1 – 2026-03-03 – Bruno DELNOZ

Bugfix.

- **FIXED**: `git add` (et toute commande git) pouvait bloquer indéfiniment sur des repos
  contenant des `.git` imbriqués (submodules non enregistrés) — git attendait une
  confirmation sur stdin. Fix : `run_cmd` redirige stdin depuis `/dev/null` pour `bash -c`
  et `bash -ic`. (`GIT_TERMINAL_PROMPT` laissé intact pour préserver les credentials HTTPS.)

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

- **ADDED**: encadré `╔ REPO [N/TOTAL] ╚` pour chaque repo traité

- **ADDED**: affichage `✔ SUCCESS` / `✘ FAILED (exit N)` en fin de traitement de chaque repo

- **CHANGED**: message de commit → `"commit last version done by syncgit.sh"`

- **CHANGED**: séquence par défaut — ajout de `git push --force origin --all` (step e)

- **REMOVED**: toutes les références à l'alias `gita` et `~/.bash_aliases`

- **REMOVED**: `generate_docs()` et le dossier `./infos/` ne sont plus utilisés

---

## v1.1.0 – 2026-02-28 – Bruno DELNOZ

Merge des meilleures fonctionnalités de la version de référence.

- **ADDED**: `set -Eeuo pipefail` + `IFS=$'\n\t'` — mode strict bash complet
- **ADDED**: `ts_now()` / `ts_human()` / `die()` / `sep()` — fonctions utilitaires
- **ADDED**: `--recurrent <seconds>` — répète le run toutes les N secondes
- **ADDED**: `--root_dir` remplace `--base_dir`
- **ADDED**: `--results_dir` alias de `--dest_dir`
- **ADDED**: `--logs_dir` pour surcharger le dossier logs
- **ADDED**: `--yes` flag obligatoire pour `--purge`
- **ADDED**: `SCRIPT_DIR` auto-détecté via `BASH_SOURCE[0]`
- **ADDED**: `init_run_context()` — initialise `RUN_TS`, `LOG_FILE`, `RESULT_FILE` par pass
- **UPDATED**: pas de version dans le nom de fichier
- **UPDATED**: commit sauté proprement si rien à committer (`git diff --cached --quiet`)

---

## v1.0.1 – 2026-02-28 – Bruno DELNOZ

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
