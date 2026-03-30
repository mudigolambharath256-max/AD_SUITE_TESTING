"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const scanController_1 = require("../controllers/scanController");
const router = express_1.default.Router();
const scanController = new scanController_1.ScanController();
// All routes require authentication
router.use(auth_1.authenticate);
// Get all scans for organization
router.get('/', scanController.getScans);
// Get single scan
router.get('/:id', scanController.getScan);
// Create new scan
router.post('/', (0, auth_1.authorize)('admin', 'analyst'), scanController.createScan);
// Start scan execution
router.post('/:id/execute', (0, auth_1.authorize)('admin', 'analyst'), scanController.executeScan);
// Stop running scan
router.post('/:id/stop', (0, auth_1.authorize)('admin', 'analyst'), scanController.stopScan);
// Delete scan
router.delete('/:id', (0, auth_1.authorize)('admin'), scanController.deleteScan);
// Get scan results
router.get('/:id/results', scanController.getScanResults);
// Get scan findings
router.get('/:id/findings', scanController.getScanFindings);
// Export scan results
router.get('/:id/export/:format', scanController.exportScan);
exports.default = router;
//# sourceMappingURL=scans.js.map