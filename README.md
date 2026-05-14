# release-action

Composite actions used by Fintoc SDKs to publish releases through the `fin-releases` GitHub App. Splits a release into two halves so a publish step can run between them — if the publish fails, nothing has been pushed to the remote yet.

## Usage

A consumer workflow runs `prepare`, then the language-specific publish (npm, poetry, gem, ...), then `finalize`:

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      bump:
        type: choice
        required: true
        options: [patch, minor, major]
      release-notes:
        type: string
        required: false

jobs:
  release:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      # ... install + build + test ...

      - uses: fintoc-com/release-action/prepare@v1
        id: prep
        with:
          bump: ${{ inputs.bump }}
          version-format: npm
          app-id: ${{ vars.FIN_RELEASES_APP_ID }}
          app-private-key: ${{ secrets.FIN_RELEASES_PRIVATE_KEY }}

      - run: npm publish

      - uses: fintoc-com/release-action/finalize@v1
        with:
          tag: ${{ steps.prep.outputs.tag }}
          release-notes: ${{ inputs.release-notes }}
          app-id: ${{ vars.FIN_RELEASES_APP_ID }}
          app-private-key: ${{ secrets.FIN_RELEASES_PRIVATE_KEY }}
```

## Actions

### `prepare`

Validates inputs, bumps the version file, commits and tags locally as `fin-releases[bot]`. Does **not** push.

| Input | Required | Default | Notes |
|---|---|---|---|
| `bump` | yes | — | `patch`, `minor` or `major` |
| `version-format` | no | `npm` | Selects `prepare/scripts/bump-<format>.sh`. Today: `npm`. |
| `extra-paths` | no | `''` | Extra files to stage in the release commit (one per line) |
| `app-id` | yes | — | `fin-releases` App ID |
| `app-private-key` | yes | — | `fin-releases` App private key (PEM) |
| `tag-prefix` | no | `v` | Prepended to the version to form the tag |

Outputs:

| Output | Example |
|---|---|
| `version` | `1.2.3` |
| `tag` | `v1.2.3` |

### `finalize`

Pushes the commit and tag prepared by `prepare`, then creates the GitHub Release.

| Input | Required | Default | Notes |
|---|---|---|---|
| `tag` | yes | — | Output `tag` from `prepare` |
| `release-notes` | no | `''` | Body for the GitHub Release |
| `app-id` | yes | — | `fin-releases` App ID |
| `app-private-key` | yes | — | `fin-releases` App private key (PEM) |

Outputs:

| Output | Example |
|---|---|
| `release-url` | `https://github.com/.../releases/tag/v1.2.3` |

## Adding a new version-format

Drop `prepare/scripts/bump-<format>.sh`. The script receives env `BUMP`, `TAG_PREFIX`, `GITHUB_OUTPUT`, and must:

1. Bump the version in the appropriate file (e.g. `pyproject.toml` for `poetry`).
2. Stage what it touched (`git add ...`).
3. Write `version` and `tag` to `$GITHUB_OUTPUT`.

Consumers then pass `version-format: <format>` to `prepare`.

## License

BSD-3-Clause.
