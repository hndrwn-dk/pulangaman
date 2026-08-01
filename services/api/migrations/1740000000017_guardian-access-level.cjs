/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.createType('guardian_access_level', ['view', 'co_parent']);
  pgm.addColumn('child_approved_guardians', {
    access_level: {
      type: 'guardian_access_level',
      notNull: true,
      default: 'view',
    },
  });
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropColumn('child_approved_guardians', 'access_level');
  pgm.dropType('guardian_access_level');
};
