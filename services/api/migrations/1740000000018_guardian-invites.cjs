/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createType('guardian_invite_status', [
    'pending',
    'redeemed',
    'revoked',
    'expired',
  ]);

  pgm.createTable('guardian_invites', {
    id: { type: 'uuid', primaryKey: true, default: pgm.func('gen_random_uuid()') },
    parent_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    code: { type: 'text', notNull: true, unique: true },
    guardian_display_name: { type: 'text' },
    access_level: {
      type: 'guardian_access_level',
      notNull: true,
      default: 'view',
    },
    status: {
      type: 'guardian_invite_status',
      notNull: true,
      default: 'pending',
    },
    expires_at: { type: 'timestamptz', notNull: true },
    redeemed_by_guardian_id: {
      type: 'uuid',
      references: 'users',
      onDelete: 'SET NULL',
    },
    redeemed_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  pgm.createIndex('guardian_invites', ['parent_id', 'status']);
  pgm.createIndex('guardian_invites', ['child_id', 'status']);
  pgm.createIndex('guardian_invites', ['expires_at']);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('guardian_invites');
  pgm.dropType('guardian_invite_status');
};
