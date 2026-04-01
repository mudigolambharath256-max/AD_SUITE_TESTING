"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const oidcController_1 = require("../controllers/oidcController");
const router = express_1.default.Router();
const oidc = new oidcController_1.OidcController();
router.get('/status', oidc.status);
router.get('/login', oidc.startLogin);
router.get('/callback', oidc.callback);
exports.default = router;
//# sourceMappingURL=oidcAuth.js.map