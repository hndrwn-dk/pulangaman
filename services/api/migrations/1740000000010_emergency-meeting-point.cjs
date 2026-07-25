/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('emergency_meeting_points', {
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
    name: { type: 'text', notNull: true },
    center: { type: 'geography(Point, 4326)', notNull: true },
    is_primary: {
      type: 'boolean',
      notNull: true,
      default: true,
    },
    instructions: { type: 'text' },
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

  pgm.createIndex('emergency_meeting_points', 'child_id', {
    name: 'idx_emergency_meeting_points_child',
  });
  pgm.createIndex('emergency_meeting_points', 'child_id', {
    name: 'idx_emergency_meeting_points_one_primary',
    unique: true,
    where: 'is_primary',
  });
  pgm.createIndex('emergency_meeting_points', 'parent_id');

  pgm.createTable('emergency_meeting_activations', {
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
    note: { type: 'text' },
    activated_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
    targets: { type: 'jsonb', notNull: true },
  });

  pgm.createIndex('emergency_meeting_activations', 'parent_id');
  pgm.createIndex('emergency_meeting_activations', 'activated_at');
};

exports.down = (pgm) => {
  pgm.dropTable('emergency_meeting_activations');
  pgm.dropTable('emergency_meeting_points');
};
