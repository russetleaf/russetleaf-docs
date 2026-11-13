# Setup guide: the GitLab group and the repo mirrors

The step-by-step procedure for the project's **GitLab group**, `russetleaf`, and the private GitLab project that mirrors each GitHub repo (Phase 1 [step 1.1](../plan.md#step-11-create-the-repos)). Each repo's `gitlab-sync` workflow pushes to its mirror on every push to `main`, so a copy of every repo exists outside both GitHub and AWS ([disaster recovery plan](../disaster-recovery.md)). The reasoning is in [ADR 1060](../adr/1060-github-organization-and-gitlab-group.md).

**Note:** the click paths in this guide are those the services showed when the procedure was last carried out. Providers change their consoles without notice, and their own documentation can lag behind the console. Before following a path, check the provider's current documentation, linked in each part; where the screen still differs, follow what it shows and fix this guide to match.

## Before starting

Have these ready:

- **The operator's personal GitLab account,** with both YubiKeys registered ([account sign-in setup guide](account-sign-in.md#part-2-github-and-gitlab)). The group belongs to it, and the mirror's token is issued by it.
- **The GitHub repo** in the `russetleaf` organization, with the `gitlab-sync` workflow (`.github/workflows/gitlab-sync.yml`, as in `russetleaf-docs`) ([GitHub organization setup guide](github-organization.md)).
- **Bitwarden,** for the token.

## Part 1: Create the group (once)

1. In GitLab's upper-right corner, select **Create new** (**+**), then **New group**, then **Create group**.
2. Fill in:
    - **Group name:** `russetleaf`
    - **Group URL:** `russetleaf`
    - **Visibility level:** **Private**, so only the group's members can see or clone the mirrors. A private group can hold only private projects.
3. Skip the optional questions and invitations, and select **Create group**.

## Part 2: Create the mirror project (for each repo)

1. Select **Create new** (**+**), then **New project/repository**, then **Create blank project**.
2. Fill in:
    - **Project name:** the GitHub repo's name, for example `russetleaf-docs`
    - **Project URL:** choose the `russetleaf` group from the namespace list
    - **Visibility Level:** **Private**
    - **Initialize repository with a README:** cleared, so the project starts empty and the first sync pushes the full history
3. Select **Create project**.

## Part 3: Create the token (for each repo)

GitLab.com offers project access tokens only on its paid tiers, so the workflow uses a **personal access token** of the operator's account, one per repo, limited to pushing code.

1. Select the avatar in the upper-right corner, then **Edit profile**.
2. In the left sidebar, select **Access → Personal access tokens**.
3. From the **Generate token** list, select **Legacy token**, and fill in:
    - **Token name:** the repo's name
    - **Token description:** `GitHub to GitLab backup`
    - **Expiration date:** one year from today (GitLab's maximum)
    - **Scopes:** `write_repository` only
4. Select **Generate token**, and copy the token into Bitwarden at once: GitLab does not show it again. Record its expiry date; the credential inventory (step 4.2) lists it for renewal.

## Part 4: Give the workflow its secrets (for each repo)

In the GitHub repo, **Settings → Secrets and variables → Actions → New repository secret**, add three secrets:

| Secret | Value |
|---|---|
| `GITLAB_URL` | The mirror's HTTPS URL, `https://gitlab.com/russetleaf/<repo>.git` |
| `GITLAB_USERNAME` | The operator's GitLab username |
| `GITLAB_PAT` | The token from Part 3 |

## Part 5: Test the mirror

1. In the GitHub repo, open **Actions**, select the **Backup to GitLab** workflow, then **Run workflow** (on `main`).
2. When the run succeeds, open the GitLab project: its `main` branch shows the same latest commit as GitHub.

## Checks

The mirror part of the step 1.1 test:

- [ ] The `russetleaf` group and each mirror project are **Private**.
- [ ] A push to `main` on GitHub appears in the GitLab mirror within minutes, and the **Backup to GitLab** run succeeds.
- [ ] Each token has only the `write_repository` scope, is in Bitwarden, and has its expiry recorded.

## If something goes wrong

- **The workflow fails to authenticate:** the token has expired or been revoked. Create a new one (Part 3), replace `GITLAB_PAT` (Part 4), and run the workflow again.
- **The push is rejected:** the GitLab project is not empty, or its `main` branch is protected against the push. Check that the project was created without a README, or allow the push for `main` in the project's protected branches.
- **GitHub is lost:** restore the repos from their mirrors, as in the [disaster recovery plan](../disaster-recovery.md).

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- GitLab: ["Groups"](https://docs.gitlab.com/user/group/), checked 2026-11-13
- GitLab: ["Project and group visibility"](https://docs.gitlab.com/user/public_access/), checked 2026-11-13
- GitLab: ["Create a project"](https://docs.gitlab.com/user/project/), checked 2026-11-13
- GitLab: ["Personal access tokens"](https://docs.gitlab.com/user/profile/personal_access_tokens/), checked 2026-11-13
- GitLab: ["Project access tokens"](https://docs.gitlab.com/user/project/settings/project_access_tokens/), checked 2026-11-13
- GitLab: ["Manage projects"](https://docs.gitlab.com/user/project/working_with_projects/), checked 2026-11-13
- GitHub: ["kujov/gitlab-sync"](https://github.com/kujov/gitlab-sync) (the sync action's README: the secrets and their format), checked 2026-11-13
