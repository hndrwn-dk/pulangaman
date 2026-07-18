/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.addConstraint('panic_alert_recipients', 'panic_alert_recipients_unique', {
    unique: ['alert_id', 'user_id', 'channel'],
  });

  pgm.createType('zone_presence', ['unknown', 'inside', 'outside']);

  pgm.createTable('zone_states', {
    child_id: {
      type: 'uuid',
      notNull: true,
      references: 'users',
      onDelete: 'CASCADE',
    },
    zone_id: {
      type: 'uuid',
      notNull: true,
      references: 'zones',
      onDelete: 'CASCADE',
    },
    presence: {
      type: 'zone_presence',
      notNull: true,
      default: 'unknown',
    },
    last_event_at: { type: 'timestamptz' },
    updated_at: {
      type: 'timestamptz',
      notNull: true,
      default: pgm.func('now()'),
    },
  });
  pgm.addConstraint('zone_states', 'zone_states_pk', {
    primaryKey: ['child_id', 'zone_id'],
  });
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropTable('zone_states');
  pgm.dropType('zone_presence');
  pgm.dropConstraint('panic_alert_recipients', 'panic_alert_recipients_unique');
};
