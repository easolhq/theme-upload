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

# Syncs only the files matched by the filters given. Each call finishes before
# the next starts, so files from an earlier call are in S3 before any file that
# needs them. Later filters take precedence over earlier ones.
sync_theme() {
  aws s3 sync . "s3://easol-themes/${THEME_KEY}" --no-progress --region eu-west-1 \
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
#    Easol caches block markup, the block and skin lists, and skin defaults for
#    up to 15 minutes. That cached content can refer to assets, blocks, partials
#    and types that this deploy removed, and sites read those files when they
#    use it. So keep them, and prune them only at least 15 minutes after a
#    deploy.
sync_theme --delete \
  --include "assets/skins/*/pages/*" \
  --include "pages/*" \
  --include "templates/*"

# Remove aws creds
rm -rf ~/.aws
