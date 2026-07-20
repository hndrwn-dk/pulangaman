/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('child_reminders', {
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
    parent_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    title: { type: 'text', notNull: true },
    body: { type: 'text', notNull: true },
    hour: { type: 'integer', notNull: true },
    minute: { type: 'integer', notNull: true },
    days_of_week: {
      type: 'integer[]',
      notNull: true,
      default: pgm.func('ARRAY[1,2,3,4,5,6,7]::integer[]'),
    },
    style: {
      type: 'text',
      notNull: true,
      default: 'fullscreen',
    },
    enabled: {
      type: 'boolean',
      notNull: true,
      default: true,
    },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
    updated_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });

  pgm.addConstraint('child_reminders', 'child_reminders_hour_check', {
    check: 'hour >= 0 AND hour <= 23',
  });
  pgm.addConstraint('child_reminders', 'child_reminders_minute_check', {
    check: 'minute >= 0 AND minute <= 59',
  });
  pgm.addConstraint('child_reminders', 'child_reminders_style_check', {
    check: "style IN ('fullscreen', 'notification')",
  });

  pgm.createIndex('child_reminders', ['child_id', 'enabled']);
  pgm.createIndex('child_reminders', 'parent_id');
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('child_reminders');
};
