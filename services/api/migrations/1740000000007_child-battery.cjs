/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.addColumn('child_profiles', {
    last_battery_level: { type: 'smallint' },
    last_battery_charging: { type: 'boolean' },
  });
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropColumn('child_profiles', 'last_battery_charging');
  pgm.dropColumn('child_profiles', 'last_battery_level');
};
