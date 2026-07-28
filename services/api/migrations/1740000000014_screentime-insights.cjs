/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('screentime_insights', {
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
    date: { type: 'date', notNull: true },
    trend_text: { type: 'text', notNull: true },
    // peakHour line — omitted when hour-level data does not clear thresholds
    pattern_text: { type: 'text' },
    // weekdayPattern line — omitted when no weekday clears the bar
    pattern_day_text: { type: 'text' },
    streak_text: { type: 'text', notNull: true },
    // only set for lateNight / evening peak categories
    suggested_reminder_time: { type: 'text' },
    suggested_reminder_label: { type: 'text' },
    days_under_limit: { type: 'integer', notNull: true, default: 0 },
    total_days: { type: 'integer', notNull: true, default: 7 },
    stats_snapshot: { type: 'jsonb', notNull: true, default: '{}' },
    source: { type: 'text', notNull: true, default: 'template' },
    locale: { type: 'text', notNull: true, default: 'id' },
    generated_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });

  pgm.addConstraint('screentime_insights', 'screentime_insights_child_date_uniq', {
    unique: ['child_id', 'date'],
  });

  pgm.createIndex('screentime_insights', ['child_id', 'date']);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('screentime_insights');
};
