import { Router } from 'express';

export const PUBLIC_ACCOUNT_DELETION_URL =
  'https://www.tursinalabs.com/pulangaman/account-deletion';

export const accountDeletionPageRouter = Router();

accountDeletionPageRouter.get('/account-deletion', (_req, res) => {
  res.redirect(302, PUBLIC_ACCOUNT_DELETION_URL);
});
