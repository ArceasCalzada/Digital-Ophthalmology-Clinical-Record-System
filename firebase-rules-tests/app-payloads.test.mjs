// Replays the exact writes the Flutter app produces (captured by
// test/rules_fixtures_test.dart) against the security rules. If the app's data
// shape and the rules ever drift apart, this test fails.
import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/app_payloads.json', import.meta.url), 'utf8'));

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-docrs',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('users/doc1').set({ role: 'physician' });
    await db.doc('users/staff1').set({ role: 'staff' });
  });
});

// Turns {"$bytes": "<base64>"} back into Firestore bytes.
function revive(v) {
  if (Array.isArray(v)) return v.map(revive);
  if (v && typeof v === 'object') {
    if (typeof v.$bytes === 'string') return firebase.firestore.Blob.fromUint8Array(Buffer.from(v.$bytes, 'base64'));
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, revive(x)]));
  }
  return v;
}

/** Commits one app mutation exactly as OfflineSyncService does (merge sets + increments). */
function commit(db, mutation) {
  const batch = db.batch();
  for (const op of mutation.ops) {
    const ref = db.doc(op.path);
    if (op.kind === 'delete') batch.delete(ref);
    else if (op.kind === 'increment') {
      batch.set(ref, Object.fromEntries(Object.entries(op.data).map(([k, n]) => [k, firebase.firestore.FieldValue.increment(n)])), { merge: true });
    } else batch.set(ref, revive(op.data), { merge: true });
  }
  return batch.commit();
}

test('fixture captured all kinds of app writes', () => {
  const kinds = new Set(fixture.map((m) => m.entityType));
  for (const k of ['Patient', 'Encounter', 'Prescription', 'CalendarEvent', 'Notification']) {
    if (!kinds.has(k)) throw new Error(`fixture is missing ${k}; regenerate with DOCRS_WRITE_FIXTURES=1 flutter test test/rules_fixtures_test.dart`);
  }
});

test('every write the app produces is accepted for a physician, in order', async () => {
  const db = env.authenticatedContext('doc1').firestore();
  for (const m of fixture) {
    await assertSucceeds(commit(db, m));
  }
  // Counters ended up exactly as the app intended.
  let c;
  await env.withSecurityRulesDisabled(async (ctx) => {
    c = (await ctx.firestore().doc('meta/counters').get()).data();
  });
  if (c.patientCount !== 1 || c.encounterCount !== 1 || c.prescriptionCount !== 1) {
    throw new Error(`unexpected counters ${JSON.stringify(c)}`);
  }
});

test('front-desk staff can register patients and use the calendar, but not write visits or prescriptions', async () => {
  const db = env.authenticatedContext('staff1').firestore();
  for (const m of fixture) {
    const allowedForStaff = ['Patient', 'CalendarEvent', 'Notification'].includes(m.entityType);
    if (allowedForStaff) await assertSucceeds(commit(db, m));
    else await assertFails(commit(db, m));
  }
});

test('the app payloads are refused without a role, and when the same patient is created twice over the cap', async () => {
  const stranger = env.authenticatedContext('nobody').firestore();
  for (const m of fixture) await assertFails(commit(stranger, m));

  // At 1000 patients the app's own patient write is refused.
  await env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc('meta/counters').set({ patientCount: 1000 }));
  const db = env.authenticatedContext('doc1').firestore();
  await assertFails(commit(db, fixture.find((m) => m.entityType === 'Patient')));
});
