"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const auditMiddleware_1 = require("../middleware/auditMiddleware");
const scanController_1 = require("../controllers/scanController");
const router = express_1.default.Router();
const scanController = new scanController_1.ScanController();
const readRoles = (0, auth_1.authorize)('admin', 'analyst', 'viewer');
const writeRoles = (0, auth_1.authorize)('admin', 'analyst');
router.use(auth_1.authenticate);
router.use(auditMiddleware_1.auditMutations);
router.get('/', readRoles, scanController.getScans);
router.get('/:id', readRoles, scanController.getScan);
router.post('/', writeRoles, scanController.createScan);
router.post('/:id/execute', writeRoles, scanController.executeScan);
router.post('/:id/stop', writeRoles, scanController.stopScan);
router.delete('/:id', (0, auth_1.authorize)('admin'), scanController.deleteScan);
router.get('/:id/results', readRoles, scanController.getScanResults);
router.get('/:id/findings', readRoles, scanController.getScanFindings);
router.get('/:id/export/:format', readRoles, scanController.exportScan);
exports.default = router;
//# sourceMappingURL=scans.js.map