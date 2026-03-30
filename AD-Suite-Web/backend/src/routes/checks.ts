import express from 'express';
import { authenticate } from '../middleware/auth';
import { CheckController } from '../controllers/checkController';

const router = express.Router();
const checkController = new CheckController();

router.use(authenticate);

router.get('/', checkController.getChecks);
router.get('/:id', checkController.getCheck);

export default router;
