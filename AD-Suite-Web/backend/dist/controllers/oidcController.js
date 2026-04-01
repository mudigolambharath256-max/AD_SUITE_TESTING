"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OidcController = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const openid_client_1 = require("openid-client");
const errorHandler_1 = require("../middleware/errorHandler");
const stateStore = new Map();
setInterval(() => {
    const now = Date.now();
    for (const [k, v] of stateStore) {
        if (now - v.created > 15 * 60 * 1000) {
            stateStore.delete(k);
        }
    }
}, 60 * 1000);
let clientPromise = null;
async function getOidcClient() {
    const issuerUrl = process.env.OIDC_ISSUER;
    const clientId = process.env.OIDC_CLIENT_ID;
    const redirectUri = process.env.OIDC_REDIRECT_URI;
    if (!issuerUrl || !clientId || !redirectUri) {
        throw new errorHandler_1.AppError('OIDC is not configured (set OIDC_ISSUER, OIDC_CLIENT_ID, OIDC_REDIRECT_URI)', 503);
    }
    if (!clientPromise) {
        clientPromise = (async () => {
            const issuer = await openid_client_1.Issuer.discover(issuerUrl);
            return new issuer.Client({
                client_id: clientId,
                client_secret: process.env.OIDC_CLIENT_SECRET,
                redirect_uris: [redirectUri],
                response_types: ['code']
            });
        })();
    }
    return clientPromise;
}
class OidcController {
    constructor() {
        this.startLogin = async (req, res, next) => {
            try {
                const client = await getOidcClient();
                const state = openid_client_1.generators.state();
                const nonce = openid_client_1.generators.nonce();
                stateStore.set(state, { nonce, created: Date.now() });
                const url = client.authorizationUrl({
                    scope: process.env.OIDC_SCOPE || 'openid profile email',
                    state,
                    nonce
                });
                res.redirect(url);
            }
            catch (e) {
                next(e);
            }
        };
        this.callback = async (req, res, next) => {
            try {
                const client = await getOidcClient();
                const redirectUri = process.env.OIDC_REDIRECT_URI;
                const params = client.callbackParams(req);
                const state = params.state;
                if (!state || !stateStore.has(state)) {
                    throw new errorHandler_1.AppError('Invalid or expired OIDC state', 400);
                }
                const { nonce } = stateStore.get(state);
                stateStore.delete(state);
                const tokenSet = await client.callback(redirectUri, params, { nonce, state: state });
                const claims = tokenSet.claims();
                const email = claims.email ||
                    claims.preferred_username ||
                    'unknown@oidc.local';
                const sub = claims.sub || email;
                const role = process.env.OIDC_DEFAULT_ROLE || 'analyst';
                const token = jsonwebtoken_1.default.sign({
                    id: sub,
                    email,
                    role,
                    organizationId: 1
                }, process.env.JWT_SECRET, { expiresIn: '8h' });
                const front = process.env.FRONTEND_URL || 'http://localhost:5173';
                const safeToken = encodeURIComponent(token);
                res.redirect(`${front}/#/oidc-callback?token=${safeToken}`);
            }
            catch (e) {
                next(e);
            }
        };
        this.status = (_req, res) => {
            const ok = Boolean(process.env.OIDC_ISSUER && process.env.OIDC_CLIENT_ID && process.env.OIDC_REDIRECT_URI);
            res.json({ oidcConfigured: ok });
        };
    }
}
exports.OidcController = OidcController;
//# sourceMappingURL=oidcController.js.map