# Agrimore

Agricultural e-commerce platform — a Flutter/Firebase monorepo (managed with [melos](https://melos.invertase.dev/)) containing four apps that share a common core.

## Apps

- [apps/marketplace](apps/marketplace) — customer-facing shopping app
- [apps/seller](apps/seller) — seller/vendor app
- [apps/admin](apps/admin) — admin panel
- [apps/delivery](apps/delivery) — delivery partner app

## Shared packages

- [packages/agrimore_core](packages/agrimore_core) — models, config, constants, utils
- [packages/agrimore_services](packages/agrimore_services) — Firebase/auth/payment/data services
- [packages/agrimore_ui](packages/agrimore_ui) — shared theme, widgets, responsive helpers

## Backend

- [functions](functions) — Firebase Cloud Functions (TypeScript)
- [firestore.rules](firestore.rules) / [storage.rules](storage.rules) — security rules

## Docs

See [docs/](docs) for architecture and feature documentation.

## Getting started

```bash
melos bootstrap
melos run:marketplace   # or run:admin, etc.
```

Build scripts live in [scripts/](scripts).
