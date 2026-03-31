<!--
Document : INSTALL.md
Author : Bruno DELNOZ
Email : bruno.delnoz@protonmail.com
Version : v1.6.0
Date : 2026-03-31 16:30
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

## Pull mode with snapshot backup
```bash
./syncgit.sh --exec --gitpull --root_dir /path/to/root
```
This mode creates and pushes `syncgit-pull-snapshot/YYYYMMDD-HHhMM` before
pulling all local branches recursively (when `origin/<branch>` exists).

## Remote branch note
- From v1.3.9, the remote-ahead guard does not fail when `origin/<branch>` is
  absent on a repository remote (for example remote default branch `master`).

## Copy-only mode
```bash
./syncgit.sh --cpagentsmdonly --root_dir /path/to/root
```

## Visibility listing mode
```bash
./syncgit.sh --listpubpriv --root_dir /path/to/root
```
Note: requires authenticated GitHub CLI (`gh auth status`).


## findgit.sh quick usage
```bash
chmod +x ./findgit.sh
./findgit.sh --prerequis
./findgit.sh --simulate --root_dir .
./findgit.sh --exec --root_dir .
```
