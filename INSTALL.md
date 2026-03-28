<!--
Document : INSTALL.md
Auteur : Bruno DELNOZ
Email : bruno.delnoz@protonmail.com
Version : v1.3.9
Date : 2026-03-28 06:10
-->
# Installation

## Requirements
- Bash 4+
- `git`
- Standard Unix utilities (`find`, `sed`, `awk`, `tee`, `date`)

## Setup
1. Clone this repository.
2. Make the script executable:
   ```bash
   chmod +x ./syncgit.sh
   ```
3. Run a prerequisite check:
   ```bash
   ./syncgit.sh --prerequis
   ```

## First execution
```bash
./syncgit.sh --exec --root_dir .
```

## Remote branch note
- From v1.3.9, the remote-ahead guard does not fail when `origin/<branch>` is
  absent on a repository remote (for example remote default branch `master`).

## Copy-only mode
```bash
./syncgit.sh --cpagentsmdonly --root_dir /path/to/root
```
