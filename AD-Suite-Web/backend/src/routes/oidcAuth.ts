import express from 'express';
import { OidcController } from '../controllers/oidcController';

const router = express.Router();
const oidc = new OidcController();

router.get('/status', oidc.status);
router.get('/login', oidc.startLogin);
router.get('/callback', oidc.callback);

export default router;
