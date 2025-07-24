#!/usr/bin/bash
while getopts 'd' opt; do
    case "$opt" in
        d) DRY_RUN=true ;;
        *) echo "Usage $0 [-d]" >&2; exit 1
    esac
done
shift "$((OPTIND-1))"

export GH_PAGER=
DAYS_OLD=10

mapfile -t packages < <(yq -r '.jobs | keys[]' < .github/workflows/packages.yml \
                            | sort -u | grep -v 'changed-files')

now=$(date +%s)

for pkg in "${packages[@]}"; do
    gh api --paginate -H "Accept: application/vnd.github+json" \
        "/users/$REPOSITORY_OWNER/packages/container/$REPOSITORY%2F$pkg/versions" | \
    jq -c '.[]' | while read -r version; do

        id=$(echo "$version" | jq -r '.id')
        tags=$(echo "$version" | jq -r '.metadata.container.tags | join(",")')
        updated_at=$(echo "$version" | jq -r '.updated_at')
        updated_epoch=$(date -d "$updated_at" +%s)
        age_days=$(( (now - updated_epoch) / 86400 ))
        pkgname="${pkg//%2F//}"

        should_delete=false

        if [[ -z "$tags" ]]; then
          echo "🗑 Deleting untagged $pkgname $id"
          should_delete=true
        fi

        if echo "$tags" | grep -Eq '\bpr-[0-9]+\b'; then
          pr_num=$(echo "$tags" | grep -o '[0-9]\+')
          state=$(gh api "/repos/$REPOSITORY_OWNER/$REPOSITORY/pulls/$pr_num" -q '.state')
          if [[ "$state" == "closed" ]]; then
            echo "🗑 Deleting PRs artifacts: $pkgname $tags (ID: $id)"
            should_delete=true
          else
            echo "⏩ Skipping PR-$pr_num (still open) in $pkgname: $tags"
            continue
          fi
        fi

        if [[ "$tags" =~ latest ]]; then
          # echo "⏩ Skipping: $pkgname $tags (contains 'latest')"
          continue
        fi

        if [[ "$tags" =~ debuginfo-main ]]; then
          # echo "⏩ Skipping: $pkgname $tags (contains 'debuginfo-main')"
          continue
        fi

        if [[ "$age_days" -ge "$DAYS_OLD" ]]; then
          echo "🗑 Deleting: $pkgname $tags (ID: $id, $age_days days old)"
          should_delete=true
        fi

        if [[ "$should_delete" == true ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "💤 Dry-run: would delete /users/$REPOSITORY_OWNER/packages/container/$REPOSITORY%2F$pkg/versions/$id"
            else
                gh api -X DELETE "/users/$REPOSITORY_OWNER/packages/container/$REPOSITORY%2F$pkg/versions/$id"
            fi
        fi
    done
done
