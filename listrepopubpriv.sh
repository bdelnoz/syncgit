find /mnt/data2_78g/Security/scripts -type d -name .git -prune -print0 | \
while IFS= read -r -d '' gitdir; do
    repo="${gitdir%/.git}"
    remote="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
    if [ -z "$remote" ]; then
        visibility="LOCAL_ONLY"
    else
        case "$remote" in
            git@github.com:*|https://github.com/*)
                slug="$(printf '%s\n' "$remote" | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')"
                visibility="$(gh repo view "$slug" --json visibility -q .visibility 2>/dev/null || echo UNKNOWN)"
                ;;
            *)
                visibility="UNKNOWN_HOST"
                ;;
        esac
    fi
    printf '%s | %s\n' "$repo" "$visibility"
done
