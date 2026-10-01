// Security-rule tests for DOCRS. Run with `npm test` in this folder (starts the
// Firestore emulator; needs Java). Writes mirror what the Flutter app sends:
// merge-sets, with counter increments in the same batch.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { test, describe, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';

const inc = (n) => firebase.firestore.FieldValue.increment(n);
const bytes = (n) => firebase.firestore.Blob.fromUint8Array(new Uint8Array(n));
const merge = { merge: true };

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-docrs',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('users/admin1').set({ role: 'admin' });
    await db.doc('users/doc1').set({ role: 'physician' });
    await db.doc('users/staff1').set({ role: 'staff' });
    await db.doc('users/badrole').set({ role: 'superuser' });
  });
});

const anon = () => env.unauthenticatedContext().firestore();
const as = (uid) => env.authenticatedContext(uid).firestore();
const seed = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));

const patient = (id, extra = {}) => ({
  id,
  mrn: `MRN-${id}`,
  fullName: 'Maria Clara Dela Cruz',
  middleName: 'Santos',
  dateOfBirth: '1958-03-12',
  gender: 'Female',
  phone: '+63 917 123 4567',
  address: 'Davao City',
  occupation: 'Teacher',
  phicNumber: '19-02581024-8',
  referringDoctor: null,
  medicalHistory: ['Hypertension'],
  allergies: ['Penicillin'],
  previousDiagnoses: ['H25.13'],
  previousPrescriptions: [],
  lastVisitDate: '2026-08-14',
  totalVisits: 1,
  lastModified: '2026-08-14T09:00:00.000',
  ...extra,
});

const exam = () => ({
  acuity: { uncorrected: '20/40', bestCorrected: '20/25', pinhole: '20/20', oldCc: '', ar: '', ak: '' },
  refraction: { sph: '-2.25', cyl: '-0.50', axis: '180', add: null },
  color: 'Normal',
  iop: '15',
  iopMethod: 'Goldmann',
  anglesGonioscopy: 'Open',
  cdrOn: '0.3',
  confrontationPeripheral: 'WNL',
  vanHerick: 'G4 Wide',
  slitLampNotes: 'Clear cornea.',
  fundoscopyNotes: 'Disc pink.',
});

const encounter = (pid, eid, extra = {}) => ({
  id: eid,
  patientId: pid,
  date: 'Aug 14, 2026',
  doctorName: 'Dr. Sigrid Robillos, MD',
  chiefComplaint: 'Blurred vision',
  examOD: exam(),
  examOS: exam(),
  diagnosis: 'H25.13',
  treatmentPlan: 'Return in 6 months',
  status: 'completed',
  lastModified: '2026-08-14T09:30:00.000',
  ...extra,
});

const rxItem = (i, extra = {}) => ({
  id: `it-${i}`,
  medicationName: 'Latanoprost',
  strength: '0.005%',
  dosage: '1 drop',
  frequency: 'QHS',
  duration: '30 days',
  instructions: 'Both eyes',
  ...extra,
});

const rx = (pid, rid, extra = {}) => ({
  id: rid,
  patientId: pid,
  encounterId: 'enc-1',
  doctorName: 'Dr. Test',
  date: '2026-08-14',
  items: [rxItem(0)],
  notes: '',
  lastModified: '2026-08-14T09:40:00.000',
  ...extra,
});

/** Creates a patient the way the app does: doc + counter bump in one batch. */
function createPatientBatch(db, id, extra = {}, bump = 1) {
  const b = db.batch();
  b.set(db.doc(`patients/${id}`), patient(id, extra), merge);
  if (bump !== 0) b.set(db.doc('meta/counters'), { patientCount: inc(bump) }, merge);
  return b.commit();
}

function createEncounterBatch(db, pid, eid, extra = {}, bump = 1) {
  const b = db.batch();
  b.set(db.doc(`patients/${pid}/encounters/${eid}`), encounter(pid, eid, extra), merge);
  b.set(db.doc(`patients/${pid}`), { totalVisits: 2, lastModified: '2026-08-14T09:30:00.000' }, merge);
  if (bump !== 0) b.set(db.doc('meta/counters'), { encounterCount: inc(bump) }, merge);
  return b.commit();
}

describe('access control', () => {
  test('anonymous users can do nothing anywhere', async () => {
    const db = anon();
    await assertFails(db.collection('patients').limit(10).get());
    await assertFails(db.doc('patients/p1').get());
    await assertFails(db.doc('users/doc1').get());
    await assertFails(db.doc('meta/counters').get());
    await assertFails(db.doc('calendarEvents/e1').set({ title: 'x' }));
    await assertFails(createPatientBatch(db, 'p1'));
  });

  test('a signed-in user with no users/ entry is refused everything', async () => {
    const db = as('stranger');
    await assertFails(db.collection('patients').limit(10).get());
    await assertFails(createPatientBatch(db, 'p1'));
    // Reading one's own (missing) role document is allowed: that is how the app learns it has no role.
    const own = await assertSucceeds(db.doc('users/stranger').get());
    assert.equal(own.exists, false);
  });

  test('a user whose role value is not recognised is refused', async () => {
    const db = as('badrole');
    await assertFails(db.collection('patients').limit(10).get());
    await assertFails(createPatientBatch(db, 'p1'));
  });

  test('users can read only their own role document and nobody can write it', async () => {
    await assertSucceeds(as('doc1').doc('users/doc1').get());
    await assertFails(as('doc1').doc('users/admin1').get());
    await assertFails(as('doc1').collection('users').limit(5).get());
    await assertFails(as('doc1').doc('users/doc1').set({ role: 'admin' }));
    await assertFails(as('admin1').doc('users/doc1').set({ role: 'admin' }));
  });

  test('unknown collections are denied even to admins', async () => {
    await assertFails(as('admin1').doc('secrets/s1').set({ a: 1 }));
    await assertFails(as('admin1').doc('secrets/s1').get());
  });
});

describe('list queries must be bounded', () => {
  test('patients: limit required, at most 1000', async () => {
    const db = as('staff1');
    await assertSucceeds(db.collection('patients').limit(1000).get());
    await assertSucceeds(db.collection('patients').limit(50).get());
    await assertFails(db.collection('patients').limit(1001).get());
    await assertFails(db.collection('patients').get());
  });

  test('encounters: limit required, at most 200, physicians only', async () => {
    const q = (db) => db.collection('patients/p1/encounters').orderBy('lastModified', 'desc');
    await assertSucceeds(q(as('doc1')).limit(200).get());
    await assertFails(q(as('doc1')).limit(201).get());
    await assertFails(q(as('doc1')).get());
    await assertFails(q(as('staff1')).limit(10).get());
  });

  test('calendar and notifications: limit required, at most 500', async () => {
    const db = as('staff1');
    await assertSucceeds(db.collection('calendarEvents').limit(500).get());
    await assertFails(db.collection('calendarEvents').limit(501).get());
    await assertFails(db.collection('calendarEvents').get());
    await assertFails(db.collection('notifications').get());
  });

  test('collection-group reads are not allowed', async () => {
    await assertFails(as('admin1').collectionGroup('encounters').limit(10).get());
  });
});

describe('patient cap (1000) and counters', () => {
  test('staff can register a patient with the counter bumped by 1', async () => {
    await assertSucceeds(createPatientBatch(as('staff1'), 'p1'));
  });

  test('creating a patient WITHOUT bumping the counter is refused', async () => {
    await assertFails(createPatientBatch(as('staff1'), 'p1', {}, 0));
  });

  test('bumping the counter by 2 for one patient is refused', async () => {
    await assertFails(createPatientBatch(as('staff1'), 'p1', {}, 2));
  });

  test('the 1000th patient is allowed, the 1001st is refused', async () => {
    await seed((db) => db.doc('meta/counters').set({ patientCount: 999 }));
    await assertSucceeds(createPatientBatch(as('doc1'), 'p1000'));
    await assertFails(createPatientBatch(as('doc1'), 'p1001'));
  });

  test('a full clinic cannot be exceeded by raising the counter directly', async () => {
    await seed((db) => db.doc('meta/counters').set({ patientCount: 1000 }));
    await assertFails(as('doc1').doc('meta/counters').set({ patientCount: inc(1) }, merge));
    await assertFails(as('doc1').doc('meta/counters').set({ patientCount: 5000 }, merge));
  });

  test('counters can only step by one, never decrease, and take no extra fields', async () => {
    await seed((db) => db.doc('meta/counters').set({ patientCount: 10 }));
    const c = as('doc1').doc('meta/counters');
    await assertFails(c.set({ patientCount: inc(2) }, merge));
    await assertFails(c.set({ patientCount: inc(-1) }, merge));
    await assertFails(c.set({ hacked: 1 }, merge));
    await assertSucceeds(c.set({ patientCount: inc(1) }, merge));
  });

  test('editing an existing patient must not touch the counter', async () => {
    await seed((db) => db.doc('patients/p1').set(patient('p1')));
    const db = as('staff1');
    await assertSucceeds(db.doc('patients/p1').set({ phone: '+63 900 111 2222' }, merge));
    const b = db.batch();
    b.set(db.doc('patients/p1'), { phone: '+63 900 111 3333' }, merge);
    b.set(db.doc('meta/counters'), { patientCount: inc(1) }, merge);
    await assertFails(b.commit());
  });
});

describe('patient document validation', () => {
  test('rejects unknown fields (so encounters/prescriptions cannot be embedded)', async () => {
    await assertFails(createPatientBatch(as('staff1'), 'p1', { encounters: [{ id: 'x' }] }));
    await assertFails(createPatientBatch(as('staff1'), 'p1', { prescriptions: [] }));
    await assertFails(createPatientBatch(as('staff1'), 'p1', { isAdmin: true }));
  });

  test('rejects wrong types and over-long strings', async () => {
    await assertFails(createPatientBatch(as('staff1'), 'p1', { fullName: 'x'.repeat(301) }));
    await assertFails(createPatientBatch(as('staff1'), 'p1', { fullName: 42 }));
    await assertFails(createPatientBatch(as('staff1'), 'p1', { totalVisits: 'many' }));
    await assertFails(createPatientBatch(as('staff1'), 'p1', { totalVisits: -1 }));
    await assertFails(createPatientBatch(as('staff1'), 'p1', { allergies: 'Penicillin' }));
  });

  test('bounds the total text held in a list (rules cannot loop, so the sum is capped)', async () => {
    await assertFails(createPatientBatch(as('staff1'), 'p1', { allergies: ['ok', 'x'.repeat(4700)] }));
    await assertFails(createPatientBatch(as('staff1'), 'p2', { previousDiagnoses: ['x'.repeat(3200)] }));
    await assertSucceeds(createPatientBatch(as('staff1'), 'p3', { allergies: ['x'.repeat(300), 'y'.repeat(300)] }));
  });

  test('a list holding a non-list value or a map is refused', async () => {
    await assertFails(createPatientBatch(as('staff1'), 'p4', { allergies: { a: 1 } }));
    await assertFails(createPatientBatch(as('staff1'), 'p5', { allergies: 'Penicillin' }));
  });

  test('a fully populated patient (every field at its limit) still fits the rule budget', async () => {
    const long = 'p'.repeat(300);
    await assertSucceeds(createPatientBatch(as('staff1'), 'pmax', {
      mrn: long, fullName: long, middleName: long, dateOfBirth: long, gender: long, phone: long,
      address: long, occupation: long, phicNumber: long, referringDoctor: long, lastVisitDate: long,
      notes: 'n'.repeat(1000),
      medicalHistory: Array(15).fill('m'.repeat(300)),
      allergies: Array(15).fill('a'.repeat(300)),
      previousDiagnoses: Array(10).fill('d'.repeat(300)),
      previousPrescriptions: Array(10).fill('r'.repeat(300)),
      totalVisits: 100000,
    }));
  });

  test('general notes: accepted up to 1000 characters, refused when longer or not text', async () => {
    await assertSucceeds(createPatientBatch(as('staff1'), 'pn1', { notes: 'n'.repeat(1000) }));
    await assertFails(createPatientBatch(as('staff1'), 'pn2', { notes: 'n'.repeat(1001) }));
    await assertFails(createPatientBatch(as('staff1'), 'pn3', { notes: 42 }));
  });

  test('rejects too many list entries', async () => {
    await assertFails(createPatientBatch(as('staff1'), 'p1', { allergies: Array(16).fill('a') }));
    await assertFails(createPatientBatch(as('staff1'), 'p1', { previousDiagnoses: Array(11).fill('a') }));
    await assertSucceeds(createPatientBatch(as('staff1'), 'p1', { allergies: Array(15).fill('a'), previousDiagnoses: Array(10).fill('a') }));
  });

  test('rejects a stored id that differs from the document id, and missing required fields', async () => {
    const db = as('staff1');
    const b = db.batch();
    b.set(db.doc('patients/p1'), patient('someone-else'), merge);
    b.set(db.doc('meta/counters'), { patientCount: inc(1) }, merge);
    await assertFails(b.commit());

    const b2 = db.batch();
    const { fullName, ...missing } = patient('p2');
    b2.set(db.doc('patients/p2'), missing, merge);
    b2.set(db.doc('meta/counters'), { patientCount: inc(1) }, merge);
    await assertFails(b2.commit());
  });

  test('patients can never be deleted from the app, even by an admin', async () => {
    await seed((db) => db.doc('patients/p1').set(patient('p1')));
    await assertFails(as('admin1').doc('patients/p1').delete());
    await assertFails(as('doc1').doc('patients/p1').delete());
  });
});

describe('encounters', () => {
  beforeEach(async () => {
    await seed((db) => db.doc('patients/p1').set(patient('p1')));
  });

  test('a physician can save a visit + summary update + counter in one batch', async () => {
    await assertSucceeds(createEncounterBatch(as('doc1'), 'p1', 'enc-1'));
  });

  test('staff (non-physician) cannot write or read clinical data', async () => {
    await assertFails(createEncounterBatch(as('staff1'), 'p1', 'enc-1'));
    await seed((db) => db.doc('patients/p1/encounters/enc-9').set(encounter('p1', 'enc-9')));
    await assertFails(as('staff1').doc('patients/p1/encounters/enc-9').get());
  });

  test('requires the encounter counter to be bumped by exactly 1', async () => {
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-1', {}, 0));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-1', {}, 3));
  });

  test('the 20000th visit is allowed, the 20001st is refused', async () => {
    await seed((db) => db.doc('meta/counters').set({ encounterCount: 19999 }));
    await assertSucceeds(createEncounterBatch(as('doc1'), 'p1', 'enc-a'));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-b'));
  });

  test('ids in the body must match the path', async () => {
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-1', { patientId: 'p2' }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-1', { id: 'other' }));
  });

  test('drawing byte fields are capped (20 KB sheet, 8 KB per eye)', async () => {
    await assertSucceeds(createEncounterBatch(as('doc1'), 'p1', 'enc-1', { paperSheet: bytes(20480) }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-2', { paperSheet: bytes(20481) }));
    await assertSucceeds(createEncounterBatch(as('doc1'), 'p1', 'enc-3', { drawOD: bytes(8192), drawOS: bytes(8192) }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-4', { drawOD: bytes(8193) }));
  });

  test('drawings must be bytes, not big arrays of points', async () => {
    const points = Array.from({ length: 50 }, (_, i) => ({ x: i, y: i }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-1', { paperSheet: points }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-2', { strokes: points }));
  });

  test('text limits: 2000 for complaint/diagnosis/plan, 1000 for exam notes, 300 for short fields', async () => {
    await assertSucceeds(createEncounterBatch(as('doc1'), 'p1', 'enc-1', { chiefComplaint: 'c'.repeat(2000) }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-2', { chiefComplaint: 'c'.repeat(2001) }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-3', { diagnosis: 'd'.repeat(2001) }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-4', { examOD: { ...exam(), slitLampNotes: 'n'.repeat(1001) } }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-5', { examOD: { ...exam(), iop: 'i'.repeat(301) } }));
  });

  test('a fully populated visit (every field at its limit) still fits the rule budget', async () => {
    const t = (n) => 't'.repeat(n);
    const fullExam = () => ({
      acuity: { uncorrected: t(300), bestCorrected: t(300), pinhole: t(300), oldCc: t(300), ar: t(300), ak: t(300) },
      refraction: { sph: t(300), cyl: t(300), axis: t(300), add: t(300) },
      color: t(300), iop: t(300), iopMethod: t(300), anglesGonioscopy: t(300), cdrOn: t(300),
      confrontationPeripheral: t(300), vanHerick: t(300), slitLampNotes: t(1000), fundoscopyNotes: t(1000),
    });
    await assertSucceeds(createEncounterBatch(as('doc1'), 'p1', 'enc-max', {
      doctorName: t(300), status: t(300), date: t(300),
      chiefComplaint: t(2000), diagnosis: t(2000), treatmentPlan: t(2000),
      examOD: fullExam(), examOS: fullExam(),
      paperSheet: bytes(20480), drawOD: bytes(8192), drawOS: bytes(8192),
    }));
  });

  test('exam sub-maps only accept known keys', async () => {
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-6', { examOS: { ...exam(), acuity: { ...exam().acuity, scan: 'x' } } }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-7', { examOS: { ...exam(), refraction: { sph: '1', dioptre: '2' } } }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-8', { examOS: 'not a map' }));
  });

  test('unknown fields inside a visit or an exam are refused', async () => {
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-1', { extra: 'x' }));
    await assertFails(createEncounterBatch(as('doc1'), 'p1', 'enc-2', { examOD: { ...exam(), scan: 'x' } }));
  });

  test('visits can never be deleted from the app', async () => {
    await seed((db) => db.doc('patients/p1/encounters/enc-9').set(encounter('p1', 'enc-9')));
    await assertFails(as('admin1').doc('patients/p1/encounters/enc-9').delete());
  });

  test('editing an existing visit is allowed but may not change the counter', async () => {
    await seed((db) => db.doc('patients/p1/encounters/enc-9').set(encounter('p1', 'enc-9')));
    const db = as('doc1');
    await assertSucceeds(db.doc('patients/p1/encounters/enc-9').set({ diagnosis: 'Updated' }, merge));
    const b = db.batch();
    b.set(db.doc('patients/p1/encounters/enc-9'), { diagnosis: 'Again' }, merge);
    b.set(db.doc('meta/counters'), { encounterCount: inc(1) }, merge);
    await assertFails(b.commit());
  });
});

describe('prescriptions', () => {
  beforeEach(async () => {
    await seed((db) => db.doc('patients/p1').set(patient('p1')));
  });

  const createRx = (db, rid, extra = {}, bump = 1) => {
    const b = db.batch();
    b.set(db.doc(`patients/p1/prescriptions/${rid}`), rx('p1', rid, extra), merge);
    if (bump) b.set(db.doc('meta/counters'), { prescriptionCount: inc(bump) }, merge);
    return b.commit();
  };

  test('a physician can save a prescription with its counter bump', async () => {
    await assertSucceeds(createRx(as('doc1'), 'rx-1'));
  });

  test('staff cannot; missing counter bump is refused', async () => {
    await assertFails(createRx(as('staff1'), 'rx-1'));
    await assertFails(createRx(as('doc1'), 'rx-1', {}, 0));
  });

  test('at most 10 medications, and field lengths are bounded', async () => {
    await assertSucceeds(createRx(as('doc1'), 'rx-1', { items: Array.from({ length: 10 }, (_, i) => rxItem(i)) }));
    await assertFails(createRx(as('doc1'), 'rx-2', { items: Array.from({ length: 11 }, (_, i) => rxItem(i)) }));
    await assertFails(createRx(as('doc1'), 'rx-3', { items: [rxItem(0, { medicationName: 'm'.repeat(201) })] }));
    await assertFails(createRx(as('doc1'), 'rx-4', { items: [rxItem(0, { instructions: 'i'.repeat(301) })] }));
    await assertFails(createRx(as('doc1'), 'rx-5', { items: [rxItem(0, { extra: 'x' })] }));
    await assertFails(createRx(as('doc1'), 'rx-6', { notes: 'n'.repeat(1001) }));
  });

  test('a fully populated prescription (10 medications at their limits) fits the rule budget', async () => {
    const t = (n) => 't'.repeat(n);
    const items = Array.from({ length: 10 }, (_, i) => rxItem(i, {
      id: t(300), medicationName: t(200), strength: t(200), dosage: t(200), frequency: t(200), duration: t(200), instructions: t(300),
    }));
    await assertSucceeds(createRx(as('doc1'), 'rx-max', { items, notes: t(1000), doctorName: t(300), date: t(300), encounterId: t(300) }));
  });

  test('the 20001st prescription is refused', async () => {
    await seed((db) => db.doc('meta/counters').set({ prescriptionCount: 20000 }));
    await assertFails(createRx(as('doc1'), 'rx-1'));
  });

  test('prescriptions can never be deleted from the app', async () => {
    await seed((db) => db.doc('patients/p1/prescriptions/rx-9').set(rx('p1', 'rx-9')));
    await assertFails(as('admin1').doc('patients/p1/prescriptions/rx-9').delete());
  });
});

describe('calendar events and notifications', () => {
  const event = (id, extra = {}) => ({
    id,
    title: 'Cataract post-op check',
    eventType: 'Follow-up',
    location: 'Exam Room 1',
    dateTime: '2026-08-14T09:30:00.000',
    patientName: 'Maria Clara Dela Cruz',
    patientId: null,
    notes: '',
    reminderMinutes: 30,
    isCompleted: false,
    lastModified: '2026-08-14T09:00:00.000',
    ...extra,
  });

  test('staff can create, update, toggle and delete events', async () => {
    const db = as('staff1');
    await assertSucceeds(db.doc('calendarEvents/e1').set(event('e1'), merge));
    await assertSucceeds(db.doc('calendarEvents/e1').set({ id: 'e1', isCompleted: true }, merge));
    await assertSucceeds(db.doc('calendarEvents/e1').delete());
  });

  test('a partial update for an event that only exists locally is accepted (app toggles seed events)', async () => {
    await assertSucceeds(as('staff1').doc('calendarEvents/seed-1').set({ id: 'seed-1', isCompleted: true }, merge));
  });

  test('events reject unknown fields, wrong types and oversize text', async () => {
    const db = as('staff1');
    await assertFails(db.doc('calendarEvents/e1').set(event('e1', { admin: true }), merge));
    await assertFails(db.doc('calendarEvents/e1').set(event('e1', { reminderMinutes: 'soon' }), merge));
    await assertFails(db.doc('calendarEvents/e1').set(event('e1', { reminderMinutes: 999999 }), merge));
    await assertFails(db.doc('calendarEvents/e1').set(event('e1', { title: 't'.repeat(301) }), merge));
    await assertFails(db.doc('calendarEvents/e1').set(event('e1', { notes: 'n'.repeat(1001) }), merge));
    await assertFails(db.doc('calendarEvents/e1').set(event('other'), merge));
  });

  test('notifications: staff can create and dismiss; bad fields refused', async () => {
    const db = as('staff1');
    const n = { id: 'n1', title: 'Refill', message: 'Requested', category: 'Refill', severity: 'warning', timestamp: '2026-08-14T09:00:00.000', patientName: null, patientId: null, isRead: false };
    await assertSucceeds(db.doc('notifications/n1').set(n, merge));
    await assertSucceeds(db.doc('notifications/n1').set({ id: 'n1', isRead: true }, merge));
    await assertFails(db.doc('notifications/n1').set({ ...n, message: 'm'.repeat(1001) }, merge));
    await assertFails(db.doc('notifications/n1').set({ ...n, rogue: 1 }, merge));
    await assertSucceeds(db.doc('notifications/n1').delete());
  });

  test('anonymous and role-less users cannot touch them', async () => {
    await assertFails(anon().doc('calendarEvents/e1').set(event('e1'), merge));
    await assertFails(as('stranger').doc('notifications/n1').set({ id: 'n1' }, merge));
  });
});

describe('Teams multi-tenancy and permission levels', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      // Seed Team A
      await db.doc('teams/teamA').set({
        id: 'teamA',
        name: 'Metro Ophthalmology Team',
        ownerId: 'ownerA',
        inviteCode: 'CODE-A',
        createdAt: '2026-10-01T10:00:00.000',
      });
      await db.doc('teams/teamA/members/ownerA').set({ uid: 'ownerA', email: 'ownerA@docrs.app', displayName: 'Dr. Owner A', role: 'owner', joinedAt: '2026-10-01T10:00:00.000' });
      await db.doc('teams/teamA/members/editorA').set({ uid: 'editorA', email: 'editorA@docrs.app', displayName: 'Dr. Editor A', role: 'editor', joinedAt: '2026-10-01T10:00:00.000' });
      await db.doc('teams/teamA/members/assistantA').set({ uid: 'assistantA', email: 'assistantA@docrs.app', displayName: 'Assistant A', role: 'assistant', joinedAt: '2026-10-01T10:00:00.000' });
      await db.doc('teams/teamA/members/viewerA').set({ uid: 'viewerA', email: 'viewerA@docrs.app', displayName: 'Viewer A', role: 'viewer', joinedAt: '2026-10-01T10:00:00.000' });

      // Seed Team B
      await db.doc('teams/teamB').set({
        id: 'teamB',
        name: 'Davao Vision Clinic',
        ownerId: 'ownerB',
        inviteCode: 'CODE-B',
        createdAt: '2026-10-01T10:00:00.000',
      });
      await db.doc('teams/teamB/members/ownerB').set({ uid: 'ownerB', email: 'ownerB@docrs.app', displayName: 'Dr. Owner B', role: 'owner', joinedAt: '2026-10-01T10:00:00.000' });

      // Seed Patient in Team A
      await db.doc('patients/p-teamA').set(patient('p-teamA', { teamId: 'teamA' }));
      await db.doc('patients/p-teamA/encounters/enc-teamA').set(encounter('p-teamA', 'enc-teamA', { teamId: 'teamA' }));
    });
  });

  test('Owner can manage members and update team properties', async () => {
    const db = as('ownerA');
    await assertSucceeds(db.doc('teams/teamA/members/newMember').set({ uid: 'newMember', email: 'new@docrs.app', displayName: 'New', role: 'viewer', joinedAt: '2026-10-01T12:00:00.000' }));
    await assertSucceeds(db.doc('teams/teamA/members/editorA').update({ role: 'assistant' }));
  });

  test('Editor cannot manage team members', async () => {
    const db = as('editorA');
    await assertFails(db.doc('teams/teamA/members/newMember').set({ uid: 'newMember', email: 'new@docrs.app', displayName: 'New', role: 'viewer', joinedAt: '2026-10-01T12:00:00.000' }));
  });

  test('Editor can view and create patients and visits in Team A', async () => {
    const db = as('editorA');
    await assertSucceeds(db.doc('patients/p-teamA').get());
    await assertSucceeds(db.doc('patients/p2-teamA').set(patient('p2-teamA', { teamId: 'teamA' }), merge));
    await assertSucceeds(db.doc('patients/p-teamA/encounters/enc-2').set(encounter('p-teamA', 'enc-2', { teamId: 'teamA' }), merge));
  });

  test('Assistant can create/edit patients but CANNOT view or write visits/encounters', async () => {
    const db = as('assistantA');
    // Assistant can edit patients
    await assertSucceeds(db.doc('patients/p-teamA').get());
    await assertSucceeds(db.doc('patients/p3-teamA').set(patient('p3-teamA', { teamId: 'teamA' }), merge));

    // Assistant CANNOT read or write encounters
    await assertFails(db.doc('patients/p-teamA/encounters/enc-teamA').get());
    await assertFails(db.doc('patients/p-teamA/encounters/enc-3').set(encounter('p-teamA', 'enc-3', { teamId: 'teamA' }), merge));
  });

  test('Viewer can view patients and visits, but CANNOT edit or write', async () => {
    const db = as('viewerA');
    await assertSucceeds(db.doc('patients/p-teamA').get());
    await assertSucceeds(db.doc('patients/p-teamA/encounters/enc-teamA').get());

    // Viewer cannot write patients or encounters
    await assertFails(db.doc('patients/p4-teamA').set(patient('p4-teamA', { teamId: 'teamA' }), merge));
    await assertFails(db.doc('patients/p-teamA/encounters/enc-4').set(encounter('p-teamA', 'enc-4', { teamId: 'teamA' }), merge));
  });

  test('Cross-team isolation: Member of Team B CANNOT read or write Team A patient data', async () => {
    const db = as('ownerB');
    await assertFails(db.doc('patients/p-teamA').get());
    await assertFails(db.doc('patients/p-teamA/encounters/enc-teamA').get());
    await assertFails(db.doc('patients/p-teamA').update({ fullName: 'Hacked Name' }));
  });
});

