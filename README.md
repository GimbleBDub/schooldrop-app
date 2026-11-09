# SchoolDrop app

One Flutter app for every side of SchoolDrop:

| Who | Where | What they get |
|---|---|---|
| Parent | Android / iOS / web | Children, school link, find & book drivers, pay, impromptu pickups, live trip timeline + map, family members (partner, helper) confirming handovers, pay in-app or directly to the driver, pair a kid's phone |
| Driver | Android / iOS | Verification onboarding (details, schools, vehicles, documents), offers, today's trips (handovers confirmed by family/school, location sharing, SOS), monthly listing fee, adverts, impromptu pickup feed, earnings |
| Kid | Android / iOS | Today's rides, "I'm in the car" / "I've arrived", SOS |
| School | web (works on phones too) | Gate list (any staff: release to driver, confirm arrivals), staff invites, enrollment confirmations (admins), school profile |
| SchoolDrop staff | **web only** | Dashboard, driver & school verification (document viewer), advert review, incidents, live trips map, users, bookings, payments/refunds, payouts, school terms, staff & permissions, audit log |

The backend is [schooldrop-be](https://github.com/GimbleBDub/schooldrop-be) (Spring Boot). Its OpenAPI spec is at `docs/openapi.json` there and live at `/api/swagger-ui.html`.

How the app is built and why: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Open work: [issues](https://github.com/GimbleBDub/schooldrop-app/issues).

## Run

Flutter 3.29 / Dart 3.7 (via fvm).

```bash
flutter pub get
flutter run -d chrome                           # web: admin, school, parent
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8097/api/v1   # Android emulator
```

- `API_BASE_URL` defaults to `http://localhost:8097/api/v1`. On a real phone, use your computer's LAN address.
- Start the backend first: in a clone of schooldrop-be, `docker compose --profile app up -d --build` (or see its README). Demo logins: `parent@`, `driver@`, `school@schooldrop.local` / `Demo-Pass-123`, admin `admin@schooldrop.local` / `ChangeMe-Local-123`.
- Locally the backend accepts browser calls from any `localhost` port; in production set `CORS_ORIGINS`.
- `SANDBOX_PAYMENTS` (default `true`) shows "Simulate success/decline" buttons when the backend runs the sandbox gateway. Build production with `--dart-define=SANDBOX_PAYMENTS=false`.

## Accounts

Sign-up asks only for the account type (parent, driver or school), email, phone and password. Right after, an
onboarding screen collects names and the details each type needs (a driver's Omang, a school's name and address);
the backend keeps parent/driver/school features locked until that's done.

## Code layout

```
lib/
  core/       config, API client (auth + token refresh), session, router, theme (design tokens), brand, shared widgets
  models/     JSON models mirroring the backend DTOs
  data/api.dart   one class per area: CommonApi, ParentApi, DriverApi, SchoolApi, KidApi, AdminApi
  features/   auth (+ onboarding), parent, driver, school, kid, admin,
              shared (app shell with sidebar/bottom nav, notifications, SOS, map, school picker)
```

State: Riverpod 3 (`FutureProvider`s per screen, invalidated after actions). Navigation: go_router picks the home for the signed-in role; screens inside a role are pushed with `Navigator`. Tokens are kept in secure storage, with one refresh token per device (`deviceId`), so web and phone sessions don't sign each other out.

## Tests

```bash
flutter analyze && flutter test
```
