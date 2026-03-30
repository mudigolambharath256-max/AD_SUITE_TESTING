"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const router = express_1.default.Router();
router.use(auth_1.authenticate);
router.get('/', (0, auth_1.authorize)('admin'), (req, res) => res.json({ users: [] }));
router.post('/', (0, auth_1.authorize)('admin'), (req, res) => res.json({ message: 'User created' }));
router.put('/:id', (0, auth_1.authorize)('admin'), (req, res) => res.json({ message: 'User updated' }));
router.delete('/:id', (0, auth_1.authorize)('admin'), (req, res) => res.json({ message: 'User deleted' }));
exports.default = router;
//# sourceMappingURL=users.js.map