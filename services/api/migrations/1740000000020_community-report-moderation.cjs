/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createTable('community_report_flags', {
    report_id: {
      type: 'uuid',
      notNull: true,
      references: 'community_reports',
      onDelete: 'CASCADE',
    },
    user_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    reason: { type: 'text' },
    created_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.addConstraint('community_report_flags', 'community_report_flags_pk', {
    primaryKey: ['report_id', 'user_id'],
  });

  pgm.createTable('community_report_hides', {
    report_id: {
      type: 'uuid',
      notNull: true,
      references: 'community_reports',
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
  pgm.addConstraint('community_report_hides', 'community_report_hides_pk', {
    primaryKey: ['report_id', 'user_id'],
  });
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('community_report_hides');
  pgm.dropTable('community_report_flags');
};
