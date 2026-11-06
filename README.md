# release-action

Composite actions used by Fintoc SDKs to publish releases

## Usage

A consumer workflow runs `prepare`, then the language-specific publish (npm, poetry, gem, ...), then `finalize`. With `push: 'true'`, `prepare` pushes the release commit and tag before anything is published, and `finalize` only creates the GitHub Release:

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
        with:
          ref: main
      # ... install + build + test ...

      - uses: fintoc-com/release-action/prepare@v2
        id: prep
        with:
          bump: ${{ inputs.bump }}
          version-format: npm
          tag-prefix: v
          push: 'true'
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

Validates inputs, bumps the version file, commits and tags locally as `fin-releases[bot]`. With `push: 'true'`, it then pushes the commit and tag atomically (see [Pushing before publishing](#pushing-before-publishing)).

All inputs except `push` are required, so every consumer states its intent explicitly. `push` defaults to `'false'` to keep existing workflows unchanged.

| Input | Notes |
|---|---|
| `bump` | `patch`, `minor` or `major` |
| `version-format` | Selects `prepare/scripts/bump-<format>.sh`. Supported: `npm`, `py`, `ruby`. |
| `tag-prefix` | Prepended to the version. Use `v` for `v1.2.3`, `''` to keep the version as-is. |
| `app-id` | `fin-releases` App ID |
| `app-private-key` | `fin-releases` App private key (PEM) |
| `push` | Optional, default `'false'`. `'true'` pushes the commit and tag before publishing. Recommended. |

Outputs:

| Output | Example |
|---|---|
| `version` | `1.2.3` |
| `tag` | `v1.2.3` |

### `finalize`

Pushes the commit and tag prepared by `prepare`, then creates the GitHub Release. If the tag is already on the remote (pushed by `prepare` with `push: 'true'`), the push is skipped.

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

## Pushing before publishing

The push sends `HEAD` to the checked-out branch and the tag in one `git push --atomic`, without force. Either both refs land or neither does. The job must check out the branch by name (`actions/checkout` with `ref: <branch>`); a detached `HEAD` fails the push.

Without `push: 'true'`, the push happens in `finalize`, after publishing. If someone merges to the branch while the release runs, the push is rejected but the package is already on the registry, with no commit, tag or GitHub Release behind it. With `push: 'true'`, that rejection happens before publishing.

### Failure modes

| What fails | State | Recovery |
|---|---|---|
| Push in `prepare` (the branch moved) | Nothing changed: no commit, no tag, nothing published. | Re-run the release from the new tip of the branch. |
| Publish, after the push | Commit and tag are on the branch, but the version is not on the registry. | Publish that version from the tag (`git checkout <tag>`, then the registry's publish command), then create the Release with `gh release create <tag>`. Or skip the version: the next release bumps from it, and the tag stays without a package. |
| GitHub Release creation in `finalize` | Package, commit and tag are published, but there is no GitHub Release. | `gh release create <tag> --notes '...'`. |

Re-running the whole job after a push has landed bumps to the next version, since `prepare` starts from the release commit already on the branch.

### Adopting it in an existing workflow

1. Check out the release branch by name (`ref: <branch>`) in the release job.
2. Add `push: 'true'` to `prepare`.
3. Leave `finalize` as it is. It skips the push and creates the GitHub Release.

## Adding a new version-format

Drop `prepare/scripts/bump-<format>.sh`. The script receives env `BUMP`, `TAG_PREFIX`, `GITHUB_OUTPUT`, and must:

1. Bump the version in the appropriate file (e.g. `pyproject.toml` for `poetry`).
2. Stage what it touched (`git add ...`).
3. Write `version` and `tag` to `$GITHUB_OUTPUT`.

Consumers then pass `version-format: <format>` to `prepare`.

## Testing

`tests/push.test.sh` runs `shared/push.sh` against a temporary bare repo. It needs only `git` and `bash`.

## Versioning

Major tags (`v1`, `v2`, ...) are moving and follow the latest minor/patch on their major. Pin to a specific `vX.Y.Z` if you need full reproducibility.

## License

BSD-3-Clause.
