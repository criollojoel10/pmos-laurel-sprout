# Security Policy

## Reporting a vulnerability

If you find a security issue in this project's workflows, scripts or
documentation, please report it privately. Do NOT open a public issue that
exposes the details.

- Open a [Security Advisory](https://github.com/criollojoel10/pmos-laurel-sprout/security/advisories/new)
- Or contact the maintainer through the GitHub account associated with this
  repository.

## Scope

This repository is a build/integration project for a postmarketOS port. The
security-sensitive parts are:

- **Secrets handling**: no tokens, keys or credentials may ever be committed.
  The workflow `scripts/audit-public-repository.sh` blocks pushes with them.
- **Workflow permissions**: least privilege (`contents: read` by default,
  write only for prerelease).
- **Supply chain**: all external actions pinned by full SHA; sources pinned by
  commit in `sources.lock.json`; checksums validated on downloads.
- **Device safety**: no workflow may run destructive Fastboot commands. The
  device is strictly read-only until explicit per-operation authorization.

## Private data

Never commit or publish: serial numbers, IMEI, MAC addresses, Android
partition dumps, `persist`, `modemst*`, `fsg`, `fsc`, EFS, unit-specific
calibration files, unredacted `fastboot getvar all` output, device backups.

## PGP / secrets

No secrets should exist in this repository. If you ever find one, rotate it
immediately and report it.
