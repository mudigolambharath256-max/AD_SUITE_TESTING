"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getRepoRoot = getRepoRoot;
const path_1 = __importDefault(require("path"));
/**
 * AD_SUITE repository root (parent of AD-Suite-Web), where checks*.json and Invoke-ADSuiteScan.ps1 live.
 * Set AD_SUITE_REPO_ROOT if the backend runs from a layout where __dirname resolution is wrong.
 */
function getRepoRoot() {
    const env = process.env.AD_SUITE_REPO_ROOT?.trim();
    if (env) {
        return path_1.default.isAbsolute(env) ? path_1.default.normalize(env) : path_1.default.resolve(process.cwd(), env);
    }
    return path_1.default.resolve(__dirname, '../../../../');
}
//# sourceMappingURL=repoRoot.js.map