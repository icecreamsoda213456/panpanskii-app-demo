# Panpanskii Portfolio Demo

This is the public, fictional **Alex + Sam** demo. The original private app is
not modified. `lib/demo_config.dart` keeps `isPortfolioDemo` enabled.

## Local Demo Data

- Five chat messages, reactions, three love letters, comments, thoughts,
  three journal entries, two moods, and three upcoming plans.
- A Daily Question response and a simulated partner's Daily Duo answer.
- A 90% sunflower garden, watering history, two harvests, and earned unlocks.
- Three photo-strip albums with bundled sample artwork and a sample note.

Dates are relative to the first launch or the last reset. The toolbar identifies
the fictional profiles and offers a confirmed reset of this demo's data only.

## Working Interactions

Chat, reactions, love letters, comments, journal edits, mood updates, questions,
and date creation/editing/deletion save locally. Own-entry permissions still
apply. Drawings can be created and viewed in Saved Drawings. Photo Booth offers
frame previews, saving sample strips, album details, and gallery filters.

Garden growth follows the existing Phase 2 rewards: watering +8, shared watering
+2, Daily Duo completion +2, and matching +1. Rewards cannot be claimed twice.
At 100%, harvest and choose an unlocked seed. Magnetic Hearts reuses the existing
rules and renderer with a labeled local practice partner, countdown, dragging,
completion, replay, and a PNG memory download. Its practice room code is `DEMO01`.
Journal and thought drafts are also browser-local and cleared by demo reset.

## Boundaries

- No Supabase initialization, backend credentials, SQL setup, Firebase push,
  real partner communication, or LiveKit connection is needed.
- Camera calls and native device alarms/widgets are not simulated as successful
  real actions. Their original native code remains separate from the demo paths.
- Photo albums use bundled sample artwork, not private couple photographs.
- Browser storage is not a database or secure vault. Do not enter private data.
- Changes persist in the current browser under
  `panpanskii_portfolio_demo_v1`. Use one active demo tab; this is not multiuser
  synchronization. Clearing site data or resetting removes demo edits.
- Uploaded letter images and drawings are limited to 750 KB each. Browser quota
  errors are reported without publishing partial changes.

## Verify And Run

```sh
flutter pub get
flutter test --concurrency=1
flutter analyze
flutter run -d chrome
flutter build web --release --no-wasm-dry-run
```

Deploy `build/web` as the static output. The supplied `vercel.json` preserves
Flutter's route fallback. No real app credentials should be added to this repo.
This repository tracks `build/web`; rebuild and commit that output when updating
the source so the static deployment receives the same version.
