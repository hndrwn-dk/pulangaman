/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('safe_trips', {
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
    from_zone_id: {
      type: 'uuid',
      notNull: true,
      references: 'zones',
      onDelete: 'CASCADE',
    },
    to_zone_id: {
      type: 'uuid',
      notNull: true,
      references: 'zones',
      onDelete: 'CASCADE',
    },
    status: {
      type: 'text',
      notNull: true,
      default: 'planned',
    },
    mode: {
      type: 'text',
      notNull: true,
      default: 'walking',
    },
    distance_m: { type: 'integer' },
    duration_sec: { type: 'integer' },
    polyline: { type: 'text' },
    path: { type: 'jsonb' },
    progress: {
      type: 'double precision',
      notNull: true,
      default: 0,
    },
    started_at: { type: 'timestamptz' },
    arrived_at: { type: 'timestamptz' },
    created_by: {
      type: 'text',
      notNull: true,
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

  pgm.addConstraint('safe_trips', 'safe_trips_status_check', {
    check: "status IN ('planned', 'active', 'arrived', 'cancelled')",
  });
  pgm.addConstraint('safe_trips', 'safe_trips_mode_check', {
    check: "mode IN ('walking', 'driving')",
  });
  pgm.addConstraint('safe_trips', 'safe_trips_created_by_check', {
    check: "created_by IN ('parent', 'child')",
  });
  pgm.addConstraint('safe_trips', 'safe_trips_progress_check', {
    check: 'progress >= 0 AND progress <= 1',
  });
  pgm.addConstraint('safe_trips', 'safe_trips_zones_distinct', {
    check: 'from_zone_id <> to_zone_id',
  });

  // One planned/active trip per child.
  pgm.createIndex('safe_trips', 'child_id', {
    name: 'safe_trips_one_open_per_child',
    unique: true,
    where: "status IN ('planned', 'active')",
  });
  pgm.createIndex('safe_trips', 'parent_id');
  pgm.createIndex('safe_trips', ['child_id', 'status']);
};

exports.down = (pgm) => {
  pgm.dropTable('safe_trips');
};
