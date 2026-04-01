import express from 'express';
import { authenticate, authorize } from '../middleware/auth';
import { CheckController } from '../controllers/checkController';

const router = express.Router();
const checkController = new CheckController();

router.use(authenticate);
router.use(authorize('admin', 'analyst', 'viewer'));

router.get('/', checkController.getChecks);
router.get('/:id', checkController.getCheck);

export default router;
