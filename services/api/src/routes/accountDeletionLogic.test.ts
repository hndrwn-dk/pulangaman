import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  accountDeletionUserIds,
  selfDeletionError,
} from './accountDeletionLogic.js';

describe('selfDeletionError', () => {
  it('blocks child-role self deletion', () => {
    assert.equal(selfDeletionError(['child']), 'child_deletion_requires_parent');
    assert.equal(selfDeletionError(['child', 'parent']), 'child_deletion_requires_parent');
  });

  it('allows parent and guardian self deletion', () => {
    assert.equal(selfDeletionError(['parent']), null);
    assert.equal(selfDeletionError(['guardian']), null);
    assert.equal(selfDeletionError(['parent', 'guardian']), null);
  });
});

describe('accountDeletionUserIds', () => {
  it('includes actor plus cascaded primary children', () => {
    assert.deepEqual(
      accountDeletionUserIds('parent-1', [
        { id: 'child-a' },
        { id: 'child-b' },
      ]),
      ['parent-1', 'child-a', 'child-b'],
    );
  });

  it('deletes only the actor when there are no primary children', () => {
    assert.deepEqual(accountDeletionUserIds('guardian-1', []), ['guardian-1']);
  });
});
