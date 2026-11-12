# Setup guide: Slack and the outside monitoring services

The step-by-step procedure for the Slack workspace, the bot that posts alerts, and the two outside services that watch the platform from beyond it (Phase 1 [step 0.1](../plan.md#step-01-accounts-tools-and-budget-alert)). What goes to which channel, and why, is in the Phase 1 design's [Alerting and notifications](../design.md#alerting-and-notifications-slack).

**Note:** the click paths in this guide are those the services showed when the procedure was last carried out. Providers change their consoles without notice, and their own documentation can lag behind the console. Before following a path, check the provider's current documentation, linked in each part; where the screen still differs, follow what it shows and fix this guide to match.

## Before starting

- **Bitwarden** (the project's password manager) open, with entries ready for Slack, the bot token, the heartbeat service and the uptime checker.
- The **Slack app** on the operator's phone, for the `#rl-critical` notifications.
- The two **YubiKeys** and the operator's **Google Account** (in Advanced Protection), for each account's sign-in ([account sign-in setup guide](account-sign-in.md)).

## Part 1: The Slack workspace

1. **Create the workspace** on Slack's "create a new workspace" page, with the operator's Workspace address (`<name>@russetleaf.dev`): name it **RussetLeaf**, with a workspace URL such as `russetleaf.slack.com`. The **free plan** is enough (90 days of history, up to 10 apps; the project uses about five).
2. **Secure the owner account:** follow Part 4 of the [account sign-in setup guide](account-sign-in.md#part-4-slack-and-the-outside-monitoring-services): daily sign-in with **Continue with Google** (the Workspace account, in Advanced Protection), and the owner's password from Bitwarden protected by an authenticator code, with the **backup codes** in Bitwarden. Slack accepts no security keys.
3. **Keep the workspace closed:** in the workspace settings, make sure people can join **only by invitation**.
4. **Create the eight channels:**

    | Channel | Used for |
    |---|---|
    | `#rl-critical` | Critical alerts from both sites; the only channel with phone notifications |
    | `#rl-dev-alerts` | russetleaf.dev warning and critical alerts |
    | `#rl-aws-alerts` | aws.russetleaf.dev warning and critical alerts (Phase 3) |
    | `#rl-deploys` | Syncs, rollouts, rollbacks and version bumps |
    | `#rl-security` | Falco, Kyverno, audit alerts, GuardDuty and Security Hub findings |
    | `#rl-mlops` | The AI components (Phase 2) |
    | `#rl-costs` | Budgets, cost anomalies and cost reports |
    | `#rl-staging` | Staging runs and staging alerts |

    Create `#rl-security` as a **private** channel: its findings can include details worth keeping from anyone invited to the workspace later. The others can be public within the workspace.

5. **Phone notifications:** in the Slack app's notification preferences, set mobile notifications to **nothing** by default, then set `#rl-critical` to notify on **every new message**. Everything else is read when convenient.

## Part 2: The bot (`russetleaf-bot`)

The clusters and workflows post through one custom Slack app, with a single permission: posting messages to channels it has been invited to.

1. **Create the app** on Slack's API site ("Your apps" → **Create New App** → **From an app manifest**), choose the RussetLeaf workspace, and paste:

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

2. **Install it** to the workspace (**Install App**), and copy the **Bot User OAuth Token** (it starts with `xoxb-`) into the password manager. It moves to AWS Secrets Manager in step 4.2; it is never committed or put in a shell profile. Add it to the credential inventory when that is written (step 4.2).
3. **Invite the bot** to every channel: in each one, run `/invite @russetleaf-bot`. The bot can post only to channels it is a member of.
4. **Note each channel's ID** (in the channel's details, at the bottom) in the password manager entry: the API addresses channels most reliably by ID, and private channels only by ID.

Incoming webhooks, which Falcosidekick and Policy Reporter use instead of the token, are added to this app when those tools are installed (Policy Reporter in step 6.1, Falcosidekick in step 7.1).

## Part 3: The GitHub app for Slack

1. **Add the GitHub app** to the workspace from Slack's app directory, and connect the operator's GitHub account when it asks.
2. **Subscribe `#rl-deploys`** to the project's repos, starting with this one:

    ```text
    /github subscribe smscully/russetleaf-docs pulls releases deployments
    ```

    Each code repo is subscribed the same way when step 1.1 creates it.

## Part 4: The outside monitoring services

Two free services watch the platform from outside, so a dead cluster or a broken internet connection still raises an alert ([Alerting and notifications](../design.md#alerting-and-notifications-slack)). Their checks are created in step 4.4; this part creates the accounts and their Slack connections.

1. **The heartbeat service** (for example healthchecks.io): sign up, register **both YubiKeys** as its two-factor sign-in (security keys are its only second factor), and connect its **Slack integration** to `#rl-critical`. In step 4.4, Alertmanager's always-firing `Watchdog` alert pings a check here every few minutes; if the pings stop, this service posts to `#rl-critical`.
2. **The uptime checker** (for example UptimeRobot or Better Stack): prefer one that offers security keys or Google sign-in (UptimeRobot offers only authenticator codes); sign up, turn on its strongest **two-factor authentication**, and connect its **Slack integration** to `#rl-critical` and `#rl-dev-alerts`. Step 4.4 adds the checks for `https://russetleaf.dev` (and Phase 3 for aws.russetleaf.dev).
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
- Slack: ["Configuring apps with app manifests"](https://docs.slack.dev/app-manifests/configuring-apps-with-app-manifests), checked 2026-11-12
- Slack: ["chat.postMessage API method"](https://docs.slack.dev/reference/methods/chat.postMessage), checked 2026-11-12
- GitHub: ["GitHub integration for Slack (the integrations/slack repository: /github subscribe)"](https://github.com/integrations/slack), checked 2026-11-12
- Healthchecks.io: ["Frequently Asked Questions (authentication mechanisms)"](https://healthchecks.io/faq/), checked 2026-11-12
- UptimeRobot: ["Set Up Two-Factor Authentication (2FA) in UptimeRobot"](https://help.uptimerobot.com/en/articles/11588518-set-up-two-factor-authentication-2fa-in-uptimerobot), checked 2026-11-12
