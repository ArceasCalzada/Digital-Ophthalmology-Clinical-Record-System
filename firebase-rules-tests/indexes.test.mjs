// Guards firestore.indexes.json. Automatic indexes made up ~85% of the stored bytes per
// visit, so every collection has automatic indexing switched off ("*" override) and only
// the index the app really queries is switched back on. If the app gains a query that
// filters or sorts on another field, add that field here (and this test) on purpose.
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const cfg = JSON.parse(readFileSync(new URL('../firestore.indexes.json', import.meta.url), 'utf8'));
const overrides = cfg.fieldOverrides;

const collections = ['patients', 'encounters', 'prescriptions', 'calendarEvents', 'notifications', 'users', 'meta'];

test('automatic indexing is switched off for every collection', () => {
  for (const c of collections) {
    const o = overrides.find((x) => x.collectionGroup === c && x.fieldPath === '*');
    assert.ok(o, `missing "*" exemption for ${c}`);
    assert.deepEqual(o.indexes, [], `${c} "*" override must have no indexes`);
  }
});

test('only lastModified (descending, collection scope) is re-enabled, on visits and prescriptions', () => {
  const reenabled = overrides.filter((o) => o.fieldPath !== '*');
  assert.deepEqual(
    reenabled.map((o) => `${o.collectionGroup}.${o.fieldPath}`).sort(),
    ['encounters.lastModified', 'prescriptions.lastModified'],
  );
  for (const o of reenabled) {
    assert.deepEqual(o.indexes, [{ order: 'DESCENDING', queryScope: 'COLLECTION' }]);
  }
});

test('no composite indexes are defined (the app has no multi-field queries)', () => {
  assert.deepEqual(cfg.indexes, []);
});
