"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const checkController_1 = require("../controllers/checkController");
const router = express_1.default.Router();
const checkController = new checkController_1.CheckController();
router.use(auth_1.authenticate);
router.use((0, auth_1.authorize)('admin', 'analyst', 'viewer'));
router.get('/', checkController.getChecks);
router.get('/:id', checkController.getCheck);
exports.default = router;
//# sourceMappingURL=checks.js.map