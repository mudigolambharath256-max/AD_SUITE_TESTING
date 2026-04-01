import express from 'express';
import { authenticate, authorize } from '../middleware/auth';
import { auditMutations } from '../middleware/auditMiddleware';
import { ScanController } from '../controllers/scanController';

const router = express.Router();
const scanController = new ScanController();

const readRoles = authorize('admin', 'analyst', 'viewer');
const writeRoles = authorize('admin', 'analyst');

router.use(authenticate);
router.use(auditMutations);

router.get('/', readRoles, scanController.getScans);
router.get('/:id', readRoles, scanController.getScan);
router.post('/', writeRoles, scanController.createScan);
router.post('/:id/execute', writeRoles, scanController.executeScan);
router.post('/:id/stop', writeRoles, scanController.stopScan);
router.delete('/:id', authorize('admin'), scanController.deleteScan);
router.get('/:id/results', readRoles, scanController.getScanResults);
router.get('/:id/findings', readRoles, scanController.getScanFindings);
router.get('/:id/export/:format', readRoles, scanController.exportScan);

export default router;
