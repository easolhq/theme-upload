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

# Sync the current repo with the theme catalogue on S3
aws s3 sync . s3://easol-themes/${THEME_KEY} --delete --no-progress --region eu-west-1

# Remove aws creds
rm -rf ~/.aws
