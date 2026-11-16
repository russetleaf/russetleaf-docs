# Setup guide: Slack and the outside monitoring services

The step-by-step procedure for the Slack workspace, the bot that posts alerts, and the two outside services that watch the platform from beyond it (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)). What goes to which channel, and why, is in the Phase 1 design's [Alerting and notifications](../design.md#alerting-and-notifications-slack).

**Note:** the click paths in this guide are those the services showed when the procedure was last carried out. Providers change their consoles without notice, and their own documentation can lag behind the console. Before following a path, check the provider's current documentation, linked in each part; where the screen still differs, follow what it shows and fix this guide to match.

## Before starting

- **Bitwarden** (the project's password manager) open, with entries ready for Slack, the bot token, the heartbeat service and the uptime checker.
- The **Slack app** on the operator's phone, for the `#rl-critical` notifications, signed in with password sign-in and the authenticator code, without adding the Workspace account to the phone ([account sign-in setup guide](account-sign-in.md#part-4-slack-and-the-outside-monitoring-services)). On the workstation, Slack is used in a browser, with no desktop app.
- The two **YubiKeys** and the operator's **Google Account** (in Advanced Protection), for each account's sign-in ([account sign-in setup guide](account-sign-in.md)).

## Part 1: The Slack workspace

1. **Create the workspace** on Slack's "create a new workspace" page, with the operator's Workspace address (`<name>@russetleaf.dev`): name it **RussetLeaf**, with a workspace URL such as `russetleaf.slack.com`. The **free plan** is enough (90 days of history, up to 10 apps; the project uses about five).
2. **Secure the owner account:** follow Part 4 of the [account sign-in setup guide](account-sign-in.md#part-4-slack-and-the-outside-monitoring-services): daily sign-in with **Continue with Google** (the Workspace account, in Advanced Protection), and the owner's password from Bitwarden protected by an authenticator code, with the **backup codes** in Bitwarden. Slack accepts no security keys.
3. **Keep the workspace closed,** so the only way in is an invitation the owner approves. Open the admin pages from **Admin** in the sidebar, or, if the sidebar has no **Admin**, from the workspace name at the top left, then select **Workspace settings**:
    1. Next to **Allow people with approved email domains to join this workspace**, select **Expand**, and check that **Let people with approved email addresses join this workspace** is **not** checked.
    2. On the **Permissions** tab, next to **Invitations**, select **Expand**, check **Require admin approval**, and select **Save**.
4. **Create the eight channels:** for each, select the **+** in the sidebar, then **Channel**, enter the name (without `#`), choose public or private, and select **Create**; skip adding people.

    | Channel | Used for |
    |---|---|
    | `#rl-aws-alerts` | aws.russetleaf.dev warning and critical alerts (Phase 3) |
    | `#rl-costs` | Budgets, cost anomalies and cost reports |
    | `#rl-critical` | Critical alerts from both sites; the only channel with phone notifications |
    | `#rl-deploys` | Syncs, rollouts, rollbacks and version bumps |
    | `#rl-dev-alerts` | russetleaf.dev warning and critical alerts |
    | `#rl-mlops` | The AI components (Phase 2) |
    | `#rl-security` | Falco, Kyverno, audit alerts, GuardDuty and Security Hub findings |
    | `#rl-staging` | Staging runs and staging alerts |

    Create `#rl-security` as a **private** channel: its findings can include details worth keeping from anyone invited to the workspace later. The others can be public within the workspace. A private channel cannot be made public later.

5. **Phone notifications,** only for `#rl-critical`. Slack has no setting for no mobile notifications at all; the lowest level, **Mentions and direct messages**, is enough, since the bot mentions no one. In the Slack app on the phone:
    1. Select the profile picture, then **Preferences**, then **Notifications**: leave **Mobile notifications** on, and under "What to notify you about", choose **Mentions and direct messages**.
    2. In `#rl-critical`, select the channel name at the top, then **Settings & Details**, then **Notifications**, and choose **All new posts**.

    Everything else is read when convenient. **Pause notifications** (under the profile picture) is a temporary do-not-disturb, not this setting.

## Part 2: The bot (`russetleaf-bot`)

The clusters and workflows post through one custom Slack app, with a single permission: posting messages to channels it has been invited to.

1. **Create the app** from a manifest: signed in to the workspace in the browser, open `https://api.slack.com/apps?new_app=1`, choose to create the app from a manifest, pick the RussetLeaf workspace, and on the **YAML** tab replace the sample with the manifest below; select **Next**, check that the summary lists the one scope, `chat:write`, and select **Create**:

    ```yaml
    display_information:
      name: russetleaf-bot
      description: Alerts and notifications from the RussetLeaf clusters and workflows
    features:
      bot_user:
        display_name: russetleaf-bot
        always_online: true
    oauth_config:
      scopes:
        bot:
          - chat:write
    settings:
      org_deploy_enabled: false
      socket_mode_enabled: false
      token_rotation_enabled: false
    ```

2. **Install it** to the workspace from the app's settings page, and copy the **Bot token** (it starts with `xoxb-`) into a new Bitwarden item. It moves to AWS Secrets Manager in step 4.2; it is never committed or put in a shell profile. Add it to the credential inventory when that is written (step 4.2).
3. **Add the bot to every channel:** in each one, select the channel name in the header, open the **Agents & apps** tab, select **Add agents and apps**, and add `russetleaf-bot`. The bot can post only to channels it is a member of.
4. **Note each channel's ID** in the bot token's Bitwarden item: it is at the bottom of the first tab of the same channel details, and starts with `C`. The API addresses channels most reliably by ID, and private channels only by ID.

Incoming webhooks, which Falcosidekick and Policy Reporter use instead of the token, are added to this app when those tools are installed (Policy Reporter in step 6.1, Falcosidekick in step 7.1).

## Part 3: The GitHub app for Slack

`#rl-deploys` receives each repo's pull requests, releases and deployments from GitHub's app for Slack.

1. **Add the GitHub app** to the workspace: in the Slack sidebar, select **Agents & tools** (or, if it is not shown, **More** or **Tools**), then **Apps**; search for **GitHub**, select **Add**, then **Add to Slack** in the Slack Marketplace, and follow the prompts.
2. **Connect the operator's GitHub account** when Slack asks, or with `/github signin` in any channel; GitHub asks for a YubiKey.
3. **Subscribe `#rl-deploys`** to each repo, starting with this one. In `#rl-deploys`, send these three commands one at a time:

    ```text
    /github subscribe russetleaf/russetleaf-docs pulls releases deployments
    /github unsubscribe russetleaf/russetleaf-docs issues commits
    /github subscribe list features
    ```

    A subscription can start with event types the README lists as defaults (issues, pull requests, commits, releases and deployments), so the second command turns off issues and commits: every commit in a deploys channel is noise. The third must list exactly `pulls`, `releases` and `deployments` for the repo; if one is missing, subscribe to it again (`/github subscribe russetleaf/russetleaf-docs <type>`).

    The first subscription to a repo of the `russetleaf` organization asks to **install the GitHub app on the organization**; as its owner, approve it for **only select repositories**, and add each new repo there when it is subscribed. `#rl-deploys` is public, so the app needs no invitation to it; a private channel would need `/invite @github` first.

Each repo created later (Phase 1 step 1.1, Phase 2 step 1.1) is subscribed the same way, with its own name in the three commands.

## Part 4: The outside monitoring services

Two free services watch the platform from outside, so a dead cluster or a broken internet connection still raises an alert ([Alerting and notifications](../design.md#alerting-and-notifications-slack)). Their checks are created in step 4.4; this part creates the accounts and their Slack connections.

1. **The heartbeat service, healthchecks.io** (open source, BSD-3-Clause; the free **Hobbyist** plan has 20 checks and includes Slack): sign up with the Workspace address (it emails a sign-in link), set a password from Bitwarden, register **both YubiKeys** as its two-factor sign-in (it also offers authenticator codes, which are not used), and connect its **Slack integration** to `#rl-critical`. In step 4.4, Alertmanager's always-firing `Watchdog` alert pings a check here every few minutes; if the pings stop, this service posts to `#rl-critical`.
2. **The uptime checker, Better Stack** (free plan, for personal projects; Slack included; a different provider from the heartbeat, so one outage cannot silence both): sign up with the Workspace address, preferring Google sign-in (OIDC) if it is offered, turn on its strongest **two-factor authentication**, and connect its **Slack integration** to `#rl-critical` and `#rl-dev-alerts`. Step 4.4 adds the checks for `https://russetleaf.dev` (and Phase 3 for aws.russetleaf.dev).
3. **The break-glass kit** ([disaster recovery plan](../disaster-recovery.md#break-glass-kit)): add the logins for both services (and any recovery codes), and Slack's **backup codes**, which open the password fallback if the Workspace account is unavailable.

## Checks

The test for step 0.1:

- [ ] A test message from the bot appears in `#rl-dev-alerts`. Run it without saving the token in the shell history:

    ```bash
    read -rsp 'Bot token: ' SLACK_BOT_TOKEN && echo
    curl -sS -X POST https://slack.com/api/chat.postMessage \
      -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
      -H 'Content-type: application/json; charset=utf-8' \
      --data '{"channel":"<the #rl-dev-alerts channel ID>","text":"[dev] Test message from russetleaf-bot (Phase 1 step 0.1)"}'
    unset SLACK_BOT_TOKEN
    ```

    The response starts with `{"ok":true`; `not_in_channel` means the bot was not invited to that channel.

- [ ] A test message to `#rl-critical` raises a phone notification, and one to another channel does not.
- [ ] In a private window, Slack signs in with the Workspace account through "Continue with Google", asking for a YubiKey and then the authenticator code; the heartbeat service asks for a YubiKey; the uptime checker asks for its second factor.
- [ ] The heartbeat service and the uptime checker can each send a test notification to `#rl-critical`.
- [ ] The workspace has only invited members, `#rl-security` is private, and **Sign-in settings** require two-factor authentication with authenticator apps only.
- [ ] Bitwarden has both services' logins, and Slack's password and backup codes.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- Slack: ["Create a Slack workspace"](https://slack.com/help/articles/206845317-Create-a-Slack-workspace), checked 2026-11-12
- Slack: ["Require admin approval for invitations to Slack"](https://slack.com/help/articles/115004854783-Require-admin-approval-for-invitations-to-Slack), checked 2026-11-12
- Slack: ["Manage how people join your workspace"](https://slack.com/help/articles/115004856503-Manage-how-people-join-your-workspace), checked 2026-11-12
- Slack: ["Create a channel"](https://slack.com/help/articles/201402297-Create-a-channel), checked 2026-11-12
- Slack: ["Configure your Slack notifications"](https://slack.com/help/articles/201355156-Configure-your-Slack-notifications), checked 2026-11-12
- Slack: ["Manage notifications for specific channels and direct messages"](https://slack.com/help/articles/360056534254-Manage-notifications-for-specific-channels-and-direct-messages), checked 2026-11-12
- Slack: ["Configuring apps with app manifests"](https://docs.slack.dev/app-manifests/configuring-apps-with-app-manifests), checked 2026-11-16
- Slack: ["App manifest reference"](https://docs.slack.dev/reference/app-manifest) (the manifest's keys are current), checked 2026-11-16
- Slack: ["Guide to apps in Slack"](https://slack.com/help/articles/360001537467-Guide-to-apps-in-Slack) (adding an app to a channel from the **Agents & apps** tab), checked 2026-11-16
- Slack: ["chat.postMessage API method"](https://docs.slack.dev/reference/methods/chat.postMessage), checked 2026-11-12
- GitHub: ["GitHub integration for Slack (the integrations/slack repository: installing, signing in, subscribing and the default event types)"](https://github.com/integrations/slack), checked 2026-11-16
- Slack: ["Add apps to your Slack workspace"](https://slack.com/help/articles/202035138-Add-apps-to-your-Slack-workspace), checked 2026-11-16
- Healthchecks.io: ["Frequently Asked Questions (authentication mechanisms)"](https://healthchecks.io/faq/), checked 2026-11-16
- Healthchecks.io: ["Pricing"](https://healthchecks.io/pricing/) (the Hobbyist plan) and ["Configuring notifications"](https://healthchecks.io/docs/configuring_notifications/) (the Slack integration), checked 2026-11-16
- Better Stack: ["Pricing"](https://betterstack.com/pricing) (the free plan, with Slack alerts), checked 2026-11-16
- UptimeRobot: ["Pricing"](https://uptimerobot.com/pricing/) (Slack only on paid plans, so it is not used), checked 2026-11-16
