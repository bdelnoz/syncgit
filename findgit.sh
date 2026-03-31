#!/bin/bash

# Script pour trouver tous les dépôts Git et leurs submodules

find_git_repos() {
    local dir="$1"
    while IFS= read -r -d '' repo; do
        echo "Dépôt Git trouvé : $repo"
        cd "$repo" || continue
        if [ -d ".gitmodules" ]; then
            echo "  Submodules dans ce dépôt :"
            git submodule status | awk '{print "    - " $2}'
        else
            echo "  Aucun submodule trouvé."
        fi
        cd "$dir" || exit 1
    done < <(find "$dir" -type d -name ".git" -print0 | xargs -0 dirname)
}

find_git_repos "."
