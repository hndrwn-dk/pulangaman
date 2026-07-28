/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  pgm.addColumn('child_reminders', {
    template_key: { type: 'text' },
  });
  pgm.addConstraint('child_reminders', 'child_reminders_template_key_check', {
    check: "template_key IS NULL OR template_key IN ('study', 'bedtime')",
  });

  // Backfill known quick-template rows created before template_key existed.
  pgm.sql(`
    UPDATE child_reminders
    SET template_key = 'study'
    WHERE template_key IS NULL
      AND title IN ('Waktunya Belajar', 'Study Time')
  `);
  pgm.sql(`
    UPDATE child_reminders
    SET template_key = 'bedtime'
    WHERE template_key IS NULL
      AND title IN ('Waktunya Tidur', 'Bedtime')
  `);
};

/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.down = (pgm) => {
  pgm.dropConstraint('child_reminders', 'child_reminders_template_key_check');
  pgm.dropColumn('child_reminders', 'template_key');
};
