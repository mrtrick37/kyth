# Release Support

KythOS publishes a stable channel and a testing channel.

## Channels

| Channel | Tag | Support expectation |
| --- | --- | --- |
| Stable | `latest` | Supported for daily use. Security fixes and important regressions are prioritized here. |
| Testing | `testing` | Development preview. May contain incomplete features or regressions. |

## Update Model

KythOS uses atomic `bootc` deployments. Updates are staged before reboot and the
previous deployment remains available from the boot menu. This means a bad
update should usually be recoverable without reinstalling.

## Security Fixes

Security fixes are provided for the current stable channel. Testing receives
fixes as part of normal development and may receive them before stable while a
change is being validated.

## End of Support

KythOS does not maintain long-term old release lines. Channel releases move
forward. Users who need security fixes should update to the current stable
channel unless a specific advisory says otherwise.

Immutable release artifacts remain useful for audit and rollback, but old
timestamped artifacts should not be assumed to receive new security updates.

## Reinstall vs. Upgrade

Most changes should be delivered through `bootc upgrade`. A reinstall should be
required only for installer-specific defects, disk layout choices, or documented
breaking changes that cannot be safely migrated in place.
