import express from 'express';
import { authenticate, authorize } from '../middleware/auth';
import { ScanController } from '../controllers/scanController';

const router = express.Router();
const scanController = new ScanController();

// All routes require authentication
router.use(authenticate);

// Get all scans for organization
router.get('/', scanController.getScans);

// Get single scan
router.get('/:id', scanController.getScan);

// Create new scan
router.post('/', authorize('admin', 'analyst'), scanController.createScan);

// Start scan execution
router.post('/:id/execute', authorize('admin', 'analyst'), scanController.executeScan);

// Stop running scan
router.post('/:id/stop', authorize('admin', 'analyst'), scanController.stopScan);

// Delete scan
router.delete('/:id', authorize('admin'), scanController.deleteScan);

// Get scan results
router.get('/:id/results', scanController.getScanResults);

// Get scan findings
router.get('/:id/findings', scanController.getScanFindings);

// Export scan results
router.get('/:id/export/:format', scanController.exportScan);

export default router;
