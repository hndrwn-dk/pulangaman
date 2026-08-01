/**
 * Allow family-wide guardian invite codes: child_id NULL means
 * "all children the inviter can manage", resolved at redeem time.
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  pgm.alterColumn('guardian_invites', 'child_id', {
    notNull: false,
  });
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.sql(`
    DELETE FROM guardian_invites WHERE child_id IS NULL
  `);
  pgm.alterColumn('guardian_invites', 'child_id', {
    notNull: true,
  });
};
