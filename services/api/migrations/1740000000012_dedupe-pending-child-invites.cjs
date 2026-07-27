/** @type {import('node-pg-migrate').MigrationBuilder} */
exports.up = (pgm) => {
  // Mark time-expired pending invites.
  pgm.sql(`
    UPDATE child_invites
    SET status = 'expired'
    WHERE status = 'pending' AND expires_at < now()
  `);

  // Keep newest pending invite per parent + relink_child_id; revoke the rest.
  pgm.sql(`
    UPDATE child_invites ci
    SET status = 'revoked'
    WHERE ci.status = 'pending'
      AND ci.relink_child_id IS NOT NULL
      AND ci.id NOT IN (
        SELECT DISTINCT ON (parent_id, relink_child_id) id
        FROM child_invites
        WHERE status = 'pending' AND relink_child_id IS NOT NULL
        ORDER BY parent_id, relink_child_id, created_at DESC
      )
  `);

  // Keep newest pending "new child" invite per parent + display name; revoke the rest.
  pgm.sql(`
    UPDATE child_invites ci
    SET status = 'revoked'
    WHERE ci.status = 'pending'
      AND ci.relink_child_id IS NULL
      AND ci.child_display_name IS NOT NULL
      AND ci.id NOT IN (
        SELECT DISTINCT ON (parent_id, lower(child_display_name)) id
        FROM child_invites
        WHERE status = 'pending'
          AND relink_child_id IS NULL
          AND child_display_name IS NOT NULL
        ORDER BY parent_id, lower(child_display_name), created_at DESC
      )
  `);
};

exports.down = () => {
  // Irreversible data cleanup.
};
