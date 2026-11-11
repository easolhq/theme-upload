# Github Action for uploading themes to Easol

This is a customized version of the s3-sync-action that will deploy an
[Easol](https://easol.com) theme for use in building sites on Easol.

## Usage

### `main.yml` Example

Place in a `.yml` file such as this one in your `.github/workflows` folder.
[Refer to the documentation on workflow YAML syntax
here.](https://help.github.com/en/articles/workflow-syntax-for-github-actions)

The example below is configured to deploy the theme every time a new commit is
pushed to the `main` branch.

```yaml
name: Theme Deploy
on:
  push:
    branches: [ main ]
# Run one deploy at a time, so an older deploy can't finish last
concurrency:
  group: theme-deploy-${{ github.ref }}
  cancel-in-progress: false
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: easolhq/theme-upload
        env:
          EASOL_KEY: ${{ secrets.EASOL_KEY }}
          EASOL_SECRET: ${{ secrets.EASOL_SECRET }}
          THEME_KEY: 'alchemist'
```

### Configuration

The following settings must be passed as environment variables as shown in the
example. Sensitive information, especially `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY`, should be [set as encrypted
secrets](https://help.github.com/en/articles/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables)
— otherwise, they'll be public to anyone browsing your repository's source code
and CI logs.

| Key          | Value                                                  | Suggested Type | Required |
| ------------ | -------------------------------------------------------|----------------|----------|
| EASOL_KEY    | The Easol access key provided by your contact at Easol | `secret env`   | Yes      |
| EASOL_SECRET | The Easol secret key provided by your contact at Easol | `secret env`   | Yes      |
| THEME_KEY    | The key creators will use to refer to your theme       | `env`          | Yes      |

## How a deploy works

The action uploads only the folders Easol reads: `assets/`, `blocks/`,
`pages/`, `partials/`, `templates/` and `types/`. It uploads them in this
order, so a site never gets a file before the files it needs:

1. `assets/`, `partials/` and `types/`, except `assets/skins/index.json` and
   skin pages in `assets/skins/<skin>/pages/`
2. `blocks/` and `templates/`, except `blocks/index.json`
3. `blocks/index.json`, `assets/skins/index.json`, skin pages and `pages/`

It then deletes files you removed from `pages/`, skin pages and `templates/`.
Easol lists pages from S3, so a removed page left there would still be offered
to sites.

Files you removed from `assets/`, `blocks/`, `partials/` and `types/` are kept
for a while. Easol caches block markup, the block and skin lists, and skin
defaults for up to 15 minutes, and that cached content can still use the
removed files.

Each deploy records when it started and the files it uploaded, in
`.deploy-manifest` in the theme's S3 folder. A later deploy deletes every file
that is in neither its own commit nor the previous deploy's record, as long as
the previous deploy started at least 30 minutes earlier. Otherwise it skips
this step, and a later deploy catches up. A deploy that fails keeps the
previous deploy's files on its record, so nothing it was about to replace is
pruned early. This also deletes files outside the
theme folders left by older versions of this action, such as `.git/`.

Pruning relies on deploys not overlapping, so keep the `concurrency` setting
from the example.
