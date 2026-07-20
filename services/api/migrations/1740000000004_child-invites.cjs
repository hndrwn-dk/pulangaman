/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createType('child_invite_status', ['pending', 'redeemed', 'revoked', 'expired']);

  pgm.createTable('child_invites', {
    id: { type: 'uuid', primaryKey: true, default: pgm.func('gen_random_uuid()') },
    parent_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    code: { type: 'text', notNull: true, unique: true },
    child_display_name: { type: 'text' },
    status: {
      type: 'child_invite_status',
      notNull: true,
      default: 'pending',
    },
    expires_at: { type: 'timestamptz', notNull: true },
    redeemed_by_child_id: {
      type: 'uuid',
      references: 'users',
      onDelete: 'SET NULL',
    },
    redeemed_at: { type: 'timestamptz' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  pgm.createIndex('child_invites', ['parent_id', 'status']);
  pgm.createIndex('child_invites', ['expires_at']);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('child_invites');
  pgm.dropType('child_invite_status');
};
