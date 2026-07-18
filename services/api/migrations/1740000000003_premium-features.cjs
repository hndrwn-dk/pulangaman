/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createType('attendance_event_type', ['check_in', 'check_out']);
  pgm.createType('attendance_source', ['geofence', 'manual']);

  pgm.createTable('attendance_events', {
    id: { type: 'uuid', primaryKey: true, default: pgm.func('gen_random_uuid()') },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    school_id: {
      type: 'uuid',
      notNull: true,
      references: 'schools',
      onDelete: 'CASCADE',
    },
    zone_id: { type: 'uuid', references: 'zones', onDelete: 'SET NULL' },
    event_type: { type: 'attendance_event_type', notNull: true },
    source: { type: 'attendance_source', notNull: true, default: 'geofence' },
    client_event_id: { type: 'text' },
    recorded_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });
  pgm.createIndex('attendance_events', ['child_id', 'recorded_at']);
  pgm.createIndex('attendance_events', ['school_id', 'recorded_at']);
  pgm.addConstraint('attendance_events', 'attendance_events_client_unique', {
    unique: ['child_id', 'client_event_id'],
  });

  pgm.createTable('reward_balances', {
    child_id: {
      type: 'uuid',
      primaryKey: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    points: { type: 'integer', notNull: true, default: 0 },
    current_streak: { type: 'integer', notNull: true, default: 0 },
    longest_streak: { type: 'integer', notNull: true, default: 0 },
    last_award_date: { type: 'date' },
    updated_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  pgm.createTable('reward_ledger', {
    id: { type: 'uuid', primaryKey: true, default: pgm.func('gen_random_uuid()') },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    actor_id: { type: 'uuid', references: 'users', onDelete: 'SET NULL' },
    delta: { type: 'integer', notNull: true },
    reason: { type: 'text', notNull: true },
    reference_key: { type: 'text', notNull: true, unique: true },
    metadata: { type: 'jsonb', notNull: true, default: '{}' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });
  pgm.createIndex('reward_ledger', ['child_id', 'created_at']);

  pgm.createTable('child_devices', {
    id: { type: 'uuid', primaryKey: true, default: pgm.func('gen_random_uuid()') },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    installation_id: { type: 'text', notNull: true, unique: true },
    device_name: { type: 'text' },
    app_version: { type: 'text' },
    usage_access_granted: { type: 'boolean', notNull: true, default: false },
    accessibility_enabled: { type: 'boolean', notNull: true, default: false },
    last_policy_version: { type: 'integer', notNull: true, default: 0 },
    last_seen_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });

  pgm.createTable('device_policies', {
    id: { type: 'uuid', primaryKey: true, default: pgm.func('gen_random_uuid()') },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    created_by_parent_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    version: { type: 'integer', notNull: true },
    enabled: { type: 'boolean', notNull: true, default: true },
    daily_limit_minutes: { type: 'integer', notNull: true, default: 120 },
    blocked_packages: { type: 'jsonb', notNull: true, default: '[]' },
    schedules: { type: 'jsonb', notNull: true, default: '[]' },
    emergency_allowlist: { type: 'jsonb', notNull: true, default: '[]' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });
  pgm.addConstraint('device_policies', 'device_policies_child_version_unique', {
    unique: ['child_id', 'version'],
  });

  pgm.createTable('device_policy_acks', {
    device_id: {
      type: 'uuid',
      notNull: true,
      references: 'child_devices',
      onDelete: 'CASCADE',
    },
    policy_id: {
      type: 'uuid',
      notNull: true,
      references: 'device_policies',
      onDelete: 'CASCADE',
    },
    version: { type: 'integer', notNull: true },
    acked_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });
  pgm.addConstraint('device_policy_acks', 'device_policy_acks_pk', {
    primaryKey: ['device_id', 'policy_id'],
  });

  pgm.createTable('usage_telemetry', {
    id: { type: 'uuid', primaryKey: true, default: pgm.func('gen_random_uuid()') },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    device_id: {
      type: 'uuid',
      references: 'child_devices',
      onDelete: 'SET NULL',
    },
    client_event_id: { type: 'text', notNull: true },
    kind: { type: 'text', notNull: true },
    package_name: { type: 'text' },
    duration_seconds: { type: 'integer' },
    recorded_at: { type: 'timestamptz', notNull: true },
    payload: { type: 'jsonb', notNull: true, default: '{}' },
    created_at: { type: 'timestamptz', notNull: true, default: pgm.func('now()') },
  });
  pgm.addConstraint('usage_telemetry', 'usage_telemetry_client_unique', {
    unique: ['child_id', 'client_event_id'],
  });
  pgm.createIndex('usage_telemetry', ['child_id', 'recorded_at']);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('usage_telemetry');
  pgm.dropTable('device_policy_acks');
  pgm.dropTable('device_policies');
  pgm.dropTable('child_devices');
  pgm.dropTable('reward_ledger');
  pgm.dropTable('reward_balances');
  pgm.dropTable('attendance_events');
  pgm.dropType('attendance_source');
  pgm.dropType('attendance_event_type');
};
