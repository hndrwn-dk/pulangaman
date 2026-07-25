/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('home_by_settings', {
    child_id: {
      type: 'uuid',
      primaryKey: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    parent_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    mode: {
      type: 'text',
      notNull: true,
      default: 'off',
    },
    custom_hour: { type: 'integer' },
    custom_minute: { type: 'integer' },
    grace_period_minutes: {
      type: 'integer',
      notNull: true,
      default: 30,
    },
    home_zone_id: {
      type: 'uuid',
      references: 'zones',
      onDelete: 'SET NULL',
    },
    weekend_mode: {
      type: 'text',
      notNull: true,
      default: 'off',
    },
    weekend_hour: { type: 'integer' },
    weekend_minute: { type: 'integer' },
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

  pgm.addConstraint('home_by_settings', 'home_by_settings_mode_check', {
    check: "mode IN ('off', 'maghrib', 'custom')",
  });
  pgm.addConstraint('home_by_settings', 'home_by_settings_weekend_mode_check', {
    check: "weekend_mode IN ('off', 'same', 'custom')",
  });
  pgm.addConstraint('home_by_settings', 'home_by_settings_custom_hour_check', {
    check: 'custom_hour IS NULL OR (custom_hour >= 0 AND custom_hour <= 23)',
  });
  pgm.addConstraint('home_by_settings', 'home_by_settings_custom_minute_check', {
    check: 'custom_minute IS NULL OR (custom_minute >= 0 AND custom_minute <= 59)',
  });
  pgm.addConstraint('home_by_settings', 'home_by_settings_weekend_hour_check', {
    check: 'weekend_hour IS NULL OR (weekend_hour >= 0 AND weekend_hour <= 23)',
  });
  pgm.addConstraint('home_by_settings', 'home_by_settings_weekend_minute_check', {
    check: 'weekend_minute IS NULL OR (weekend_minute >= 0 AND weekend_minute <= 59)',
  });
  pgm.addConstraint('home_by_settings', 'home_by_settings_grace_check', {
    check: 'grace_period_minutes >= 5 AND grace_period_minutes <= 120',
  });

  pgm.createIndex('home_by_settings', 'parent_id');
  pgm.createIndex('home_by_settings', ['enabled', 'mode']);

  pgm.createTable('home_by_skip_dates', {
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
    skip_date: { type: 'date', notNull: true },
    note: { type: 'text' },
    created_by: {
      type: 'uuid',
      notNull: true,
      references: 'users',
    },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });

  pgm.addConstraint('home_by_skip_dates', 'home_by_skip_dates_unique', {
    unique: ['child_id', 'skip_date'],
  });
  pgm.createIndex('home_by_skip_dates', ['child_id', 'skip_date']);

  pgm.createTable('home_by_events', {
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
    event_date: { type: 'date', notNull: true },
    target_time: { type: 'timestamptz', notNull: true },
    effective_deadline: { type: 'timestamptz', notNull: true },
    status: {
      type: 'text',
      notNull: true,
      default: 'pending',
    },
    pre_notified_at: { type: 'timestamptz' },
    target_notified_at: { type: 'timestamptz' },
    grace_notified_at: { type: 'timestamptz' },
    resolved_at: { type: 'timestamptz' },
    child_ack_at: { type: 'timestamptz' },
    child_ack_reason: { type: 'text' },
    child_ack_note: { type: 'text' },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });

  pgm.addConstraint('home_by_events', 'home_by_events_status_check', {
    check:
      "status IN ('pending', 'pre_notified', 'target_notified', 'grace_notified', 'resolved', 'skipped')",
  });
  pgm.addConstraint('home_by_events', 'home_by_events_ack_reason_check', {
    check:
      "child_ack_reason IS NULL OR child_ack_reason IN ('in_transit', 'stopped_by', 'school_activity', 'other')",
  });
  pgm.addConstraint('home_by_events', 'home_by_events_unique_day', {
    unique: ['child_id', 'event_date'],
  });

  pgm.createIndex('home_by_events', ['child_id', 'event_date'], {
    name: 'idx_home_by_events_pending',
    where: "status NOT IN ('resolved', 'skipped')",
  });
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('home_by_events');
  pgm.dropTable('home_by_skip_dates');
  pgm.dropTable('home_by_settings');
};
