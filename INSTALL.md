<!--
Document : INSTALL.md
Auteur : Bruno DELNOZ
Email : bruno.delnoz@protonmail.com
Version : v1.0.1
Date : 2026-03-28 02:30
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

## Copy-only mode
```bash
./syncgit.sh --cpagentsmdonly --root_dir /path/to/root
```
