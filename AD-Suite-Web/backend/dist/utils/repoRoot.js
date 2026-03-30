"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getRepoRoot = getRepoRoot;
const path_1 = __importDefault(require("path"));
/** AD_SUITE repository root (parent of AD-Suite-Web). */
function getRepoRoot() {
    return path_1.default.resolve(__dirname, '../../../../');
}
//# sourceMappingURL=repoRoot.js.map