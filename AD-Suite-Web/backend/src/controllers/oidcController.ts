import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { Issuer, generators, Client } from 'openid-client';
import { AppError } from '../middleware/errorHandler';

const stateStore = new Map<string, { nonce: string; created: number }>();

setInterval(() => {
    const now = Date.now();
    for (const [k, v] of stateStore) {
        if (now - v.created > 15 * 60 * 1000) {
            stateStore.delete(k);
        }
    }
}, 60 * 1000);

let clientPromise: Promise<Client> | null = null;

async function getOidcClient(): Promise<Client> {
    const issuerUrl = process.env.OIDC_ISSUER;
    const clientId = process.env.OIDC_CLIENT_ID;
    const redirectUri = process.env.OIDC_REDIRECT_URI;
    if (!issuerUrl || !clientId || !redirectUri) {
        throw new AppError('OIDC is not configured (set OIDC_ISSUER, OIDC_CLIENT_ID, OIDC_REDIRECT_URI)', 503);
    }
    if (!clientPromise) {
        clientPromise = (async () => {
            const issuer = await Issuer.discover(issuerUrl);
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

export class OidcController {
    startLogin = async (req: Request, res: Response, next: NextFunction) => {
        try {
            const client = await getOidcClient();
            const state = generators.state();
            const nonce = generators.nonce();
            stateStore.set(state, { nonce, created: Date.now() });
            const url = client.authorizationUrl({
                scope: process.env.OIDC_SCOPE || 'openid profile email',
                state,
                nonce
            });
            res.redirect(url);
        } catch (e) {
            next(e);
        }
    };

    callback = async (req: Request, res: Response, next: NextFunction) => {
        try {
            const client = await getOidcClient();
            const redirectUri = process.env.OIDC_REDIRECT_URI!;
            const params = client.callbackParams(req);
            const state = params.state;
            if (!state || !stateStore.has(state)) {
                throw new AppError('Invalid or expired OIDC state', 400);
            }
            const { nonce } = stateStore.get(state)!;
            stateStore.delete(state);

            const tokenSet = await client.callback(redirectUri, params, { nonce, state: state as string });
            const claims = tokenSet.claims();
            const email =
                (claims.email as string) ||
                (claims.preferred_username as string) ||
                'unknown@oidc.local';
            const sub = (claims.sub as string) || email;
            const role =
                (process.env.OIDC_DEFAULT_ROLE as 'admin' | 'analyst' | 'viewer') || 'analyst';

            const token = jwt.sign(
                {
                    id: sub,
                    email,
                    role,
                    organizationId: 1
                },
                process.env.JWT_SECRET!,
                { expiresIn: '8h' }
            );

            const front = process.env.FRONTEND_URL || 'http://localhost:5173';
            const safeToken = encodeURIComponent(token);
            res.redirect(`${front}/#/oidc-callback?token=${safeToken}`);
        } catch (e) {
            next(e);
        }
    };

    status = (_req: Request, res: Response) => {
        const ok = Boolean(
            process.env.OIDC_ISSUER && process.env.OIDC_CLIENT_ID && process.env.OIDC_REDIRECT_URI
        );
        res.json({ oidcConfigured: ok });
    };
}
