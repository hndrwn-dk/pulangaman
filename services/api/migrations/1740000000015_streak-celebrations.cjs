/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('streak_celebrations', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    // First Jakarta calendar day of this consecutive under-limit run.
    streak_start_date: { type: 'date', notNull: true },
    milestone_days: { type: 'integer', notNull: true },
    points_awarded: { type: 'integer', notNull: true, default: 0 },
    title_id: { type: 'text', notNull: true },
    body_id: { type: 'text', notNull: true },
    title_en: { type: 'text', notNull: true },
    body_en: { type: 'text', notNull: true },
    celebrated_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
    // Null until the child device shows / acks the full-screen moment.
    shown_at: { type: 'timestamptz' },
  });

  pgm.addConstraint(
    'streak_celebrations',
    'streak_celebrations_milestone_check',
    {
      check: 'milestone_days IN (3, 7, 14, 30)',
    },
  );

  pgm.addConstraint(
    'streak_celebrations',
    'streak_celebrations_child_run_milestone_uniq',
    {
      unique: ['child_id', 'streak_start_date', 'milestone_days'],
    },
  );

  pgm.createIndex('streak_celebrations', ['child_id', 'shown_at']);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('streak_celebrations');
};
