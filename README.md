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

      - uses: fintoc-com/release-action/prepare@v2
        id: prep
        with:
          bump: ${{ inputs.bump }}
          version-format: npm
          tag-prefix: v
          app-id: ${{ vars.FIN_RELEASES_APP_ID }}
          app-private-key: ${{ secrets.FIN_RELEASES_PRIVATE_KEY }}

      - run: npm publish

      - uses: fintoc-com/release-action/finalize@v2
        with:
          tag: ${{ steps.prep.outputs.tag }}
          release-notes: ${{ inputs.release-notes }}
          app-id: ${{ vars.FIN_RELEASES_APP_ID }}
          app-private-key: ${{ secrets.FIN_RELEASES_PRIVATE_KEY }}
```

## Actions

### `prepare`

Validates inputs, bumps the version file, commits and tags locally as `fin-releases[bot]`. Does **not** push.

All inputs are required — there are no defaults, so every consumer states its intent explicitly.

| Input | Notes |
|---|---|
| `bump` | `patch`, `minor` or `major` |
| `version-format` | Selects `prepare/scripts/bump-<format>.sh`. Supported: `npm`, `py`. |
| `tag-prefix` | Prepended to the version. Use `v` for `v1.2.3`, `''` to keep the version as-is. |
| `app-id` | `fin-releases` App ID |
| `app-private-key` | `fin-releases` App private key (PEM) |

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

## Versioning

Major tags (`v1`, `v2`, ...) are moving and follow the latest minor/patch on their major. Pin to a specific `vX.Y.Z` if you need full reproducibility.

## License

BSD-3-Clause.
