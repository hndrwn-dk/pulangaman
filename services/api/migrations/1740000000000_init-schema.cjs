/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.sql('CREATE EXTENSION IF NOT EXISTS "pgcrypto"');
  pgm.sql('CREATE EXTENSION IF NOT EXISTS "postgis"');

  pgm.createType('user_role', ['parent', 'child', 'guardian', 'school_admin']);
  pgm.createType('commute_status', ['home', 'school', 'commuting', 'unknown']);
  pgm.createType('guardian_status', ['pending', 'active', 'suspended', 'banned']);
  pgm.createType('approval_status', ['invited', 'active', 'revoked']);
  pgm.createType('zone_type', ['home', 'school', 'custom']);
  pgm.createType('panic_type', ['normal']);
  pgm.createType('panic_status', [
    'active',
    'parent_responded',
    'guardian_notified',
    'resolved',
    'false_alarm',
  ]);
  pgm.createType('notify_channel', ['fcm', 'sms']);

  pgm.createTable('users', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    firebase_uid: { type: 'text', notNull: true, unique: true },
    phone: { type: 'text', notNull: true },
    email: { type: 'text' },
    name: { type: 'text', notNull: true },
    avatar_url: { type: 'text' },
    is_active: { type: 'boolean', notNull: true, default: true },
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
  pgm.createIndex('users', 'phone');

  pgm.createTable('user_roles', {
    user_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    role: { type: 'user_role', notNull: true },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.addConstraint('user_roles', 'user_roles_pk', {
    primaryKey: ['user_id', 'role'],
  });

  pgm.createTable('parent_children', {
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
      unique: true,
    },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.addConstraint('parent_children', 'parent_children_pk', {
    primaryKey: ['parent_id', 'child_id'],
  });

  pgm.createTable('child_profiles', {
    user_id: {
      type: 'uuid',
      primaryKey: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    school_id: { type: 'uuid' },
    grade: { type: 'integer' },
    commute_status: {
      type: 'commute_status',
      notNull: true,
      default: 'unknown',
    },
    last_seen_at: { type: 'timestamptz' },
  });

  pgm.createTable('guardian_profiles', {
    user_id: {
      type: 'uuid',
      primaryKey: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    status: {
      type: 'guardian_status',
      notNull: true,
      default: 'pending',
    },
    ktp_object_key: { type: 'text' },
    background_check_passed: {
      type: 'boolean',
      notNull: true,
      default: false,
    },
    home_location: { type: 'geography(Point, 4326)' },
    service_radius_m: { type: 'integer', notNull: true, default: 500 },
  });

  pgm.createTable('child_approved_guardians', {
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    guardian_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    approved_by_parent_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    status: {
      type: 'approval_status',
      notNull: true,
      default: 'invited',
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
  pgm.addConstraint('child_approved_guardians', 'child_approved_guardians_pk', {
    primaryKey: ['child_id', 'guardian_id'],
  });

  pgm.createTable('emergency_contacts', {
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
    name: { type: 'text', notNull: true },
    phone: { type: 'text', notNull: true },
    priority: { type: 'integer', notNull: true, default: 1 },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.createIndex('emergency_contacts', 'child_id');

  pgm.createTable('devices', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    user_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    fcm_token: { type: 'text', notNull: true },
    platform: { type: 'text', notNull: true },
    last_seen_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.createIndex('devices', 'user_id');
  pgm.createIndex('devices', 'fcm_token', { unique: true });

  pgm.createTable('zones', {
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
    type: { type: 'zone_type', notNull: true },
    center: { type: 'geography(Point, 4326)', notNull: true },
    radius_m: { type: 'integer', notNull: true },
    name: { type: 'text' },
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
  pgm.createIndex('zones', 'child_id');

  pgm.createTable('location_history', {
    id: {
      type: 'bigserial',
      primaryKey: true,
    },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    recorded_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
    location: { type: 'geography(Point, 4326)', notNull: true },
    accuracy_m: { type: 'double precision' },
    source: { type: 'text', notNull: true, default: 'device' },
  });
  pgm.createIndex('location_history', ['child_id', 'recorded_at']);

  pgm.createTable('panic_alerts', {
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
    type: { type: 'panic_type', notNull: true, default: 'normal' },
    triggered_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
    triggered_location: { type: 'geography(Point, 4326)', notNull: true },
    status: { type: 'panic_status', notNull: true, default: 'active' },
    resolved_at: { type: 'timestamptz' },
    resolution_notes: { type: 'text' },
  });
  pgm.createIndex('panic_alerts', ['child_id', 'status']);

  pgm.createTable('panic_alert_recipients', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    alert_id: {
      type: 'uuid',
      notNull: true,
      references: 'panic_alerts',
      onDelete: 'CASCADE',
    },
    user_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    channel: { type: 'notify_channel', notNull: true },
    sent_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
    ack_at: { type: 'timestamptz' },
  });
  pgm.createIndex('panic_alert_recipients', 'alert_id');

  pgm.createTable('audit_events', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    actor_id: { type: 'uuid' },
    subject_child_id: { type: 'uuid' },
    action: { type: 'text', notNull: true },
    payload: { type: 'jsonb', notNull: true, default: '{}' },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.createIndex('audit_events', 'created_at');
  pgm.createIndex('audit_events', 'subject_child_id');

  pgm.sql(`
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pulangaman_app') THEN
        REVOKE UPDATE, DELETE ON TABLE audit_events FROM pulangaman_app;
      END IF;
    END
    $$;
  `);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('audit_events');
  pgm.dropTable('panic_alert_recipients');
  pgm.dropTable('panic_alerts');
  pgm.dropTable('location_history');
  pgm.dropTable('zones');
  pgm.dropTable('devices');
  pgm.dropTable('emergency_contacts');
  pgm.dropTable('child_approved_guardians');
  pgm.dropTable('guardian_profiles');
  pgm.dropTable('child_profiles');
  pgm.dropTable('parent_children');
  pgm.dropTable('user_roles');
  pgm.dropTable('users');

  pgm.dropType('notify_channel');
  pgm.dropType('panic_status');
  pgm.dropType('panic_type');
  pgm.dropType('zone_type');
  pgm.dropType('approval_status');
  pgm.dropType('guardian_status');
  pgm.dropType('commute_status');
  pgm.dropType('user_role');
};
