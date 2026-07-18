/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('schools', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    name: { type: 'text', notNull: true },
    address: { type: 'text' },
    panic_contact_phone: { type: 'text' },
    panic_contact_name: { type: 'text' },
    center: { type: 'geography(POINT)' },
    radius_m: { type: 'integer', notNull: true, default: 200 },
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

  pgm.createTable('school_admins', {
    school_id: {
      type: 'uuid',
      notNull: true,
      references: 'schools',
      onDelete: 'CASCADE',
    },
    user_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.addConstraint('school_admins', 'school_admins_pk', {
    primaryKey: ['school_id', 'user_id'],
  });

  pgm.createTable('school_roster', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    school_id: {
      type: 'uuid',
      notNull: true,
      references: 'schools',
      onDelete: 'CASCADE',
    },
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    grade: { type: 'integer' },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.addConstraint('school_roster', 'school_roster_unique_child', {
    unique: ['school_id', 'child_id'],
  });
  pgm.createIndex('school_roster', 'school_id');

  pgm.createType('report_status', ['active', 'verified', 'expired', 'removed']);

  pgm.createTable('community_reports', {
    id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
    },
    reporter_id: {
      type: 'uuid',
      references: 'users',
      onDelete: 'SET NULL',
    },
    category: { type: 'text', notNull: true },
    note: { type: 'text' },
    location: { type: 'geography(POINT)', notNull: true },
    status: {
      type: 'report_status',
      notNull: true,
      default: 'active',
    },
    expires_at: { type: 'timestamptz', notNull: true },
    verified_at: { type: 'timestamptz' },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.createIndex('community_reports', 'expires_at');
  pgm.createIndex('community_reports', 'status');

  pgm.sql(`
    ALTER TABLE child_profiles
      ADD CONSTRAINT child_profiles_school_id_fkey
      FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE SET NULL
  `);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.sql('ALTER TABLE child_profiles DROP CONSTRAINT IF EXISTS child_profiles_school_id_fkey');
  pgm.dropTable('community_reports');
  pgm.dropType('report_status');
  pgm.dropTable('school_roster');
  pgm.dropTable('school_admins');
  pgm.dropTable('schools');
};
