<!--
Document : WHY.md
Auteur : Bruno DELNOZ
Email : bruno.delnoz@protonmail.com
Version : v1.5.0
Date : 2026-03-29 03:29
-->
# Why this project exists

`syncgit.sh` is designed to automate repetitive multi-repository Git operations with:

- explicit execution steps
- simulation mode (`--simulate`)
- detailed logs and result summaries
- safety guards around branch and push logic
- robust remote-ahead behavior when `origin/<branch>` does not exist remotely
- optional `--cpagentsmd` propagation to keep a single master `AGENTS.md` policy
  synchronized across all discovered repositories

- dedicated `--cpagentsmdonly` mode for AGENTS propagation without any other repo action
- dedicated `--listpubpriv` mode to list only GitHub `PRIVATE`/`PUBLIC` repositories
  sorted by visibility criteria
- dedicated `--gitpull` mode to create a backup snapshot branch
  (`syncgit-pull-snapshot/YYYYMMDD-HHhMM`), push it to origin, then pull all
  local branches recursively with clear `PULLED`/`SYNCED` outcomes
