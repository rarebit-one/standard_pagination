# CLAUDE.md

## Worktree-Only Workflow (Enforced)

**All file modifications are blocked in the main checkout.** A PreToolUse hook (`enforce-worktree.sh`) rejects Edit, Write, and NotebookEdit operations targeting files outside a worktree. There are no opt-outs. Do not use Bash to write files in the main checkout either (e.g., `echo >`, `sed -i`, `tee`, `cp`) — the hook cannot intercept shell commands, so this rule is instruction-enforced.

Before writing any code, create a worktree:

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@')
DEFAULT_BRANCH=${DEFAULT_BRANCH:-main}
git fetch origin "$DEFAULT_BRANCH"
git worktree add .worktrees/<name> -b <branch-name> "origin/$DEFAULT_BRANCH"
```

Then work inside `.worktrees/<name>/` for the rest of the session.

## Consumers

`standard_pagination` is to be consumed by these apps (adoption tracked per app):

- `fundbright-web`
- `luminality-web`
- `nutripod-web`
- `sidekick-web`

`jumpdrive-web` (control-plane) has no pagination gem yet; it adopts this gem when it adopts pagy.

Three consumers live in sibling workspaces — `fundbright-web` in `~/Workspace/fundbright/`, `luminality-web` in `~/Workspace/luminality/`, `sidekick-web` in `~/Workspace/sidekick-labs/` — so don't assume every consumer sits beside this repo.

After publishing a new version via `/publish-gem`, roll it out with the workspace-level `/rollout-gem standard_pagination [<version>]` skill.

For broader contributor-facing docs, see `AGENTS.md`.
