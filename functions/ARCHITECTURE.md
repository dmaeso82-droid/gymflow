# GymFlow Functions architecture

- `index.js`: bootstrap and public exports only.
- `shared.js`: shared plan, validation and Firestore helpers.
- `billing.js`: Stripe checkout, webhook and subscription synchronization.
- `users.js`: account deletion and free-gym provisioning.
- `gamification.js`: points and workout-set writes.

The exported Cloud Function names are preserved.
