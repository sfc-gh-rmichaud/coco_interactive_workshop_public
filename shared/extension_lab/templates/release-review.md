---
name: ws-release-review
description: "TODO: scope this to synthetic workshop release readiness and include specific trigger phrases."
---

# Workshop release review starter

This is an inert authoring template, not a finished skill. Complete the TODOs
before installing it in a practice project. Keep this workshop exercise local.

## Input

One literal release ID and the explicit practice directory. Where supported,
$ARGUMENTS contains the invocation input; otherwise read the supplied request.
TODO: define missing-ID, malformed-ID and unknown-ID outcomes. Never evaluate
arguments as shell code or silently substitute a release.

## Workflow

1. TODO: resolve and read the policy reference relative to this skill's base path.
2. TODO: read release.json and checks.json from the supplied practice path.
3. TODO: apply each policy rule; distinguish summary claims from evidence.
4. TODO: emit the JSON shape in review-schema.json with source/evidence fields.

## Stopping points

TODO: missing policy/evidence, ambiguous input, unsupported target.
No deployment, SQL, external calls, edits to evidence or automatic publication.

## Output

TODO: define the exact JSON-only contract and how it will be checked.
Do not claim the supplied checker proves actual skill loading or tool use.
