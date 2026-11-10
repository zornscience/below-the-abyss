# Publication status

Implementation commit `e9882557d0a643db7a6cbda21772d1898d55b9c6` was pushed to
`origin/testbox-combat`. `git ls-remote` confirmed that exact remote hash. The
subsequent documentation-only commit records this publication blocker.

Attempted command, exit 1:

```sh
gh pr create --repo zornscience/below-the-abyss --base main --head testbox-combat \
  --title "Add a disposable combat and handling test box" \
  --body-file docs/testing/combat-testbox/PR.md
```

Exact error:

```text
Post "https://api.github.com/graphql": Forbidden
```

The read-only existing-PR query failed with the same API error. No GitHub connector
or browser capability is available in this environment. The Git push succeeded,
but **a PR was not created**. Local validation is complete; no PR-specific CI
result exists, and no merge or merge request was made.

[Open the PR creation page](https://github.com/zornscience/below-the-abyss/pull/new/testbox-combat)
using the [prepared complete PR body](PR.md). The intended base is `main`.
Do not merge or request merge until that PR's own CI is green.
