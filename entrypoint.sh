#!/bin/sh

# Exit on first error
set -e

# Assert that the required keys have been set
if [ -z ${EASOL_KEY} ]; then
  echo "EASOL_KEY not defined, unable to authorize"
  exit 1
fi

if [ -z ${EASOL_SECRET} ]; then
  echo "EASOL_SECRET not defined, unable to authorize"
  exit 1
fi

if [ -z ${THEME_KEY} ]; then
  echo "THEME_KEY not defined, required to add theme"
  exit 1
fi

# Setup aws credentials for us to authorize
mkdir ~/.aws
touch ~/.aws/credentials

cat << EOF > ~/.aws/credentials
[default]
aws_access_key_id=${EASOL_KEY}
aws_secret_access_key=${EASOL_SECRET}
EOF

S3_THEME="s3://easol-themes/${THEME_KEY}"
WORK_DIR=$(mktemp -d)

# Each deploy records when it started and the files it uploads, so a later
# deploy can tell which files an earlier deploy removed.
MANIFEST="${S3_THEME}/.deploy-manifest"
find assets blocks pages partials templates types -type f 2>/dev/null | sort > "${WORK_DIR}/deploy-files"

# The previous deploy's record, missing for a theme's first deploy with this
# action.
previous_started_at=
if aws s3 cp "${MANIFEST}" "${WORK_DIR}/previous-manifest" --quiet --region eu-west-1 2>/dev/null; then
  previous_started_at=$(head -n 1 "${WORK_DIR}/previous-manifest")
fi

# Recorded before uploading, with the previous deploy's files too. A deploy that
# fails partway may have uploaded some of its files, and may not yet have
# replaced the blocks that use files it removes. Keeping both sets stops a later
# deploy pruning either too early.
started_at=$(date +%s)
{
  echo "${started_at}"
  {
    if [ -f "${WORK_DIR}/previous-manifest" ]; then tail -n +2 "${WORK_DIR}/previous-manifest"; fi
    cat "${WORK_DIR}/deploy-files"
  } | sort -u
} | aws s3 cp - "${MANIFEST}" --quiet --region eu-west-1

# Syncs only the files matched by the filters given. Each call finishes before
# the next starts, so files from an earlier call are in S3 before any file that
# needs them. Later filters take precedence over earlier ones.
sync_theme() {
  aws s3 sync . "${S3_THEME}" --no-progress --region eu-west-1 \
    --exclude "*" "$@"
}

# 1. Files that blocks and templates depend on. The skin list waits until the
#    skins it lists are uploaded, and skin pages wait for the blocks they use.
sync_theme \
  --include "assets/*" \
  --include "partials/*" \
  --include "types/*" \
  --exclude "assets/skins/index.json" \
  --exclude "assets/skins/*/pages/*"

# 2. Blocks and templates. The block list waits until the blocks it lists are
#    uploaded.
sync_theme \
  --include "blocks/*" \
  --include "templates/*" \
  --exclude "blocks/index.json"

# 3. The lists of blocks and skins, and theme and skin pages, which are built
#    from blocks.
sync_theme \
  --include "blocks/index.json" \
  --include "assets/skins/index.json" \
  --include "assets/skins/*/pages/*" \
  --include "pages/*"

# 4. Delete removed theme pages, skin pages and templates. Easol lists pages
#    from S3, so a removed page left there would still be offered to sites.
sync_theme --delete \
  --include "assets/skins/*/pages/*" \
  --include "pages/*" \
  --include "templates/*"

# 5. Prune every other file that an earlier deploy removed. Easol caches block
#    markup, the block and skin lists, and skin defaults for up to 15 minutes.
#    That cached content can use files the previous deploy removed, so keep
#    those, and prune only when the previous deploy started at least 30
#    minutes ago: 15 minutes of caching, plus time for that deploy to finish.
#    Later deploys catch up on any pruning skipped. Files outside the theme
#    folders, such as `.git/`, are pruned too.
case "${previous_started_at}" in
  "" | *[!0-9]*) prune=false ;;
  *) [ $(($(date +%s) - previous_started_at)) -ge 1800 ] && prune=true || prune=false ;;
esac

# An empty list would mean pruning the whole theme, so never prune then.
if [ "${prune}" = true ] && [ -s "${WORK_DIR}/deploy-files" ]; then
  tail -n +2 "${WORK_DIR}/previous-manifest" | cat - "${WORK_DIR}/deploy-files" > "${WORK_DIR}/keep"

  aws s3api list-objects-v2 --bucket easol-themes --prefix "${THEME_KEY}/" \
    --query "Contents[].Key" --output text --region eu-west-1 |
    tr '\t' '\n' |
    sed "s#^${THEME_KEY}/##" |
    grep -vxF -e "None" -e ".deploy-manifest" -f "${WORK_DIR}/keep" > "${WORK_DIR}/prune" || true

  if [ -s "${WORK_DIR}/prune" ]; then
    sed 's/^/prune: /' "${WORK_DIR}/prune"

    # delete-objects takes at most 1,000 keys at a time.
    python3 - "${THEME_KEY}" "${WORK_DIR}" <<'PY'
import json, sys

theme, work_dir = sys.argv[1], sys.argv[2]
with open(f"{work_dir}/prune") as prune:
    keys = [theme + "/" + line.rstrip("\n") for line in prune if line.strip()]
for start in range(0, len(keys), 1000):
    with open(f"{work_dir}/prune-{start}.json", "w") as batch:
        json.dump({"Objects": [{"Key": key} for key in keys[start:start + 1000]], "Quiet": True}, batch)
PY

    for batch in "${WORK_DIR}"/prune-*.json; do
      aws s3api delete-objects --bucket easol-themes --delete "file://${batch}" --region eu-west-1
    done
  fi
else
  echo "Not pruning: the previous deploy started less than 30 minutes ago, or has no record"
fi

# Every file is uploaded and no block uses a removed file, so record only this
# deploy's files.
{ echo "${started_at}"; cat "${WORK_DIR}/deploy-files"; } |
  aws s3 cp - "${MANIFEST}" --quiet --region eu-west-1

# Remove aws creds and working files
rm -rf ~/.aws "${WORK_DIR}"
