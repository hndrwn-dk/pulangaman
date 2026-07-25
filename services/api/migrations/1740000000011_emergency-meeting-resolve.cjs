/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.addColumns('emergency_meeting_activations', {
    resolved_at: { type: 'timestamptz' },
  });
  pgm.createIndex('emergency_meeting_activations', ['parent_id', 'activated_at'], {
    name: 'idx_emergency_meeting_activations_open',
    where: 'resolved_at IS NULL',
  });
};

exports.down = (pgm) => {
  pgm.dropIndex('emergency_meeting_activations', ['parent_id', 'activated_at'], {
    name: 'idx_emergency_meeting_activations_open',
  });
  pgm.dropColumns('emergency_meeting_activations', ['resolved_at']);
};
