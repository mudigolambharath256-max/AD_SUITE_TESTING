"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const multer_1 = __importDefault(require("multer"));
const path_1 = __importDefault(require("path"));
const promises_1 = __importDefault(require("fs/promises"));
const auth_1 = require("../middleware/auth");
const scanService_1 = require("../services/scanService");
const router = express_1.default.Router();
router.use(auth_1.authenticate);
const uploadDir = path_1.default.resolve('./uploads/analysis');
// Ensure upload directory exists
promises_1.default.mkdir(uploadDir, { recursive: true }).catch(() => { });
const storage = multer_1.default.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (_req, file, cb) => {
        const ts = Date.now();
        const safe = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
        cb(null, `${ts}-${safe}`);
    }
});
const upload = (0, multer_1.default)({
    storage,
    limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB
    fileFilter: (_req, file, cb) => {
        if (file.mimetype === 'application/json' || file.originalname.endsWith('.json')) {
            cb(null, true);
        }
        else {
            cb(new Error('Only JSON files are allowed'));
        }
    }
});
// Upload a scan-results.json
router.post('/upload', upload.single('file'), async (req, res, next) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }
        // Validate JSON structure
        const raw = await promises_1.default.readFile(req.file.path, 'utf-8');
        const safeRaw = raw.replace(/^\uFEFF/, '');
        const doc = JSON.parse(safeRaw);
        if (!doc.results && !doc.aggregate) {
            await promises_1.default.unlink(req.file.path);
            return res.status(400).json({ message: 'Invalid scan-results JSON (missing results or aggregate)' });
        }
        res.json({
            filename: req.file.filename,
            originalName: req.file.originalname,
            size: req.file.size,
            uploadedAt: new Date().toISOString()
        });
    }
    catch (error) {
        // Clean up invalid file
        if (req.file) {
            await promises_1.default.unlink(req.file.path).catch(() => { });
        }
        if (error instanceof SyntaxError) {
            return res.status(400).json({ message: 'Uploaded file is not valid JSON' });
        }
        next(error);
    }
});
// List uploaded and generated scan files
router.get('/scans', async (_req, res, next) => {
    try {
        const scans = await scanService_1.ScanService.listAvailableScans();
        res.json({ scans });
    }
    catch (error) {
        next(error);
    }
});
// Serve a specific scan file
router.get('/scans/:filename', async (req, res, next) => {
    try {
        const filename = req.params.filename;
        const data = await scanService_1.ScanService.getScanContent(filename);
        if (!data) {
            return res.status(404).json({ message: 'Scan file not found' });
        }
        res.json(data);
    }
    catch (error) {
        next(error);
    }
});
exports.default = router;
//# sourceMappingURL=analysis.js.map