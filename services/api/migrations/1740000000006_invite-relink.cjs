/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.addColumn('child_invites', {
    relink_child_id: {
      type: 'uuid',
      references: 'users',
      onDelete: 'CASCADE',
    },
  });
  pgm.createIndex('child_invites', ['relink_child_id']);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropIndex('child_invites', ['relink_child_id']);
  pgm.dropColumn('child_invites', 'relink_child_id');
};
