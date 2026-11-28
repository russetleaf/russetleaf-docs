# Setup guide: Bitwarden on the workstation (desktop app and CLI)

The step-by-step procedure for setting up **Bitwarden**, the project's password manager, on the Ubuntu workstation ([local workstation setup](../plan.md#4-configuration)): the **desktop app**, signed in to the project's own account, and the **`bw` CLI**, signed in with the account's API key in its own data folder. The account itself, its two-step login with both YubiKeys and its API key are created by the [account sign-in setup guide](account-sign-in.md#part-1-the-personal-google-account-microsoft-and-bitwarden). The same procedure sets up a new or replacement workstation.

**Note:** the click paths in this guide are those the services showed when the procedure was last carried out. Providers change their consoles without notice, and their own documentation can lag behind the console. Before following a path, check the provider's current documentation, linked in each part; where the screen still differs, follow what it shows and fix this guide to match.

## Before starting

Have these ready:

- **The setup script run** ([`setup-ubuntu.sh`](https://github.com/russetleaf/russetleaf-docs/blob/main/scripts/workstation/setup-ubuntu.sh)), which installs the desktop app (the official snap, connected to the desktop's secret service) and the CLI, `bw`, with mise.
- **The project's Bitwarden account** (`<name>@russetleaf.dev`, on Bitwarden's cloud in the United States, `bitwarden.com`) and its **memorized master password**.
- **Both YubiKeys**, for the account's two-step login.
- The account's **API key** (`client_id` and `client_secret`), in the vault item `Bitwarden - RussetLeaf API key`; it is read from the desktop app in Part 2.

## Part 1: The desktop app

1. **Check the install:** the setup script installs the official snap, published by Bitwarden, and connects it to the desktop's secret service, as Bitwarden's documentation asks for every Linux distribution. Where its output said `snapd is not running: skipped`, run the two `sudo snap` lines by hand once `snapd` runs:

    ```bash
    snap list bitwarden          # the publisher shows as bitwarden✓ (bitwarden** when not printed to a terminal)
    snap connections bitwarden | grep password-manager-service   # connected: a slot is shown
    # Only if the setup script skipped the snap:
    sudo snap install bitwarden
    sudo snap connect bitwarden:password-manager-service
    ```

2. **Log in:** open **Bitwarden** with the Super key. On the login screen, check that the server shown is `bitwarden.com`, enter the Workspace address, select **Continue**, and enter the master password. For the two-step login, select the security key method if another is offered, then plug in `yubikey-primary`, enter its PIN and touch it.
3. **Settings:** in the menu bar, select **File → Settings**:
    - Under **Preferences**, set **Clear clipboard** to **2 minutes**, so a copied password does not stay on the clipboard ([account sign-in setup guide](account-sign-in.md#the-rule)).
    - Under **Security**, set the session timeout (the setting above **Timeout action**) to **15 minutes**, so the vault locks after 15 minutes without use in the app, and **Timeout action** to **Lock**, so a timed-out vault stays signed in but needs the master password again, rather than logging out.
4. **A personal Bitwarden account, if the operator has one** (optional): select the account in the top-right of the app, then **Add account**, and log in to it. The app keeps both signed in and switches between them; the `Shared accounts` items appear in both.
5. **Test the second key:** select the account in the top-right, then **Log out**; log in again with only `yubikey-backup` plugged in.

## Part 2: The CLI

The CLI keeps the project's sign-in in its **own data folder**, so it never mixes with a personal one ([workstation configuration](../plan.md#4-configuration)). Each project repo's `.envrc` sets the folder; until those exist, export it in the terminal first.

1. **Point the CLI at its data folder** and confirm the server:

    ```bash
    export BITWARDENCLI_APPDATA_DIR="${HOME}/.config/Bitwarden CLI RussetLeaf"
    bw config server             # shows https://bitwarden.com (the default)
    ```

2. **Log in with the API key:** in the desktop app, open the item `Bitwarden - RussetLeaf API key`, then run:

    ```bash
    bw login --apikey            # asks for client_id and client_secret; paste each from the app
    ```

3. **Unlock and sync:** the API key only signs in; reading items still needs the master password. Sync after each unlock, since the CLI works from its own copy of the vault:

    ```bash
    export BW_SESSION="$(bw unlock --raw)"
    bw sync
    bw status | jq -r '.userEmail, .status'      # the Workspace address, then "unlocked"
    bw lock
    ```

## Checks

- [ ] `snap list bitwarden` shows the snap, published by `bitwarden✓` (`bitwarden**` when not printed to a terminal), and `snap connections bitwarden` shows `password-manager-service` connected.
- [ ] The desktop app is signed in to the project's account, and a log-in with each YubiKey on its own succeeded.
- [ ] **File → Settings → Preferences** shows **Clear clipboard** at **2 minutes**; a copied password is gone from the clipboard after 2 minutes.
- [ ] **File → Settings → Security** shows the session timeout at **15 minutes** and **Timeout action** at **Lock**.
- [ ] With `BITWARDENCLI_APPDATA_DIR` set, `bw status` shows the Workspace address; after `bw unlock` and `bw sync`, `bw get item 'Bitwarden - RussetLeaf API key'` finds the item.
- [ ] Without `BITWARDENCLI_APPDATA_DIR` set, `bw status` shows `unauthenticated` (or the personal account, if one is signed in there), so the project's sign-in stays in its own folder.

## If something goes wrong

- **The desktop app does not offer the security key:** select **Use another two-step login method** and choose the security key; if the key is still not offered, log in through the web app (`https://vault.bitwarden.com`) to confirm the key works there, and check the snap's version against Bitwarden's release notes.
- **`bw` reports an item as `Not found`, or shows an old password:** run `bw sync`.
- **The API key item is missing:** create a new key in the web app under **Settings → Security → Keys → View API key** (it asks for the master password), and save it in the vault item before logging the CLI in.

## References

The official pages these steps follow, each checked on the date shown. When a page has moved or changed, find the current one, update the step if needed, and change the date.

- Bitwarden: ["Password Manager desktop apps"](https://bitwarden.com/help/getting-started-desktop/) (Snap's `password-manager-service` connection, **File → Settings**, adding an account), checked 2026-11-27
- Bitwarden: ["Client app settings"](https://bitwarden.com/help/app-settings/) (**Clear clipboard**), checked 2026-11-27
- Bitwarden: ["Session timeout"](https://bitwarden.com/help/vault-timeout/) (the timeout and its action on the desktop app), checked 2026-11-27
- Bitwarden: ["Password Manager CLI"](https://bitwarden.com/help/cli/) (`login --apikey`, `BITWARDENCLI_APPDATA_DIR`, `config server`, `unlock`, `sync`, `status`, `lock`), checked 2026-11-27
- Bitwarden: ["Two-step login via FIDO2 WebAuthn"](https://bitwarden.com/help/setup-two-step-login-fido/) (supported on the Linux desktop app), checked 2026-11-27
