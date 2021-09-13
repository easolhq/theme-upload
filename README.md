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
