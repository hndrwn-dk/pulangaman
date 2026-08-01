/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('weekly_digest_log', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    parent_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    // Jakarta Sunday date that identifies the digest week.
    week_start_date: { type: 'date', notNull: true },
    // Child summaries included in this batched send.
    payload: { type: 'jsonb', notNull: true, default: '{}' },
    // Primary child for deep-link (first child with data).
    primary_child_id: {
      type: 'uuid',
      references: 'users',
      onDelete: 'SET NULL',
    },
    sent_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
    opened_at: { type: 'timestamptz' },
  });

  pgm.addConstraint('weekly_digest_log', 'weekly_digest_log_parent_week_uniq', {
    unique: ['parent_id', 'week_start_date'],
  });

  pgm.createIndex('weekly_digest_log', ['parent_id', 'sent_at']);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('weekly_digest_log');
};
