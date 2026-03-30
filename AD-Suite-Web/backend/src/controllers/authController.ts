import { Request, Response, NextFunction } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { AppError } from '../middleware/errorHandler';
import { AuthRequest } from '../middleware/auth';

export class AuthController {
    async register(req: Request, res: Response, next: NextFunction) {
        try {
            const { email, password, name, organizationName } = req.body;

            if (!email || !password || !name) {
                throw new AppError('Email, password, and name are required', 400);
            }

            // TODO: Check if user exists in database

            const hashedPassword = await bcrypt.hash(password, 10);

            // TODO: Save user to database
            const user = {
                id: Date.now(),
                email,
                name,
                role: 'admin',
                organizationId: Date.now()
            };

            const token = jwt.sign(
                { id: user.id, email: user.email, role: user.role, organizationId: user.organizationId },
                process.env.JWT_SECRET!,
                { expiresIn: '7d' }
            );

            res.status(201).json({ user, token });
        } catch (error) {
            next(error);
        }
    }

    async login(req: Request, res: Response, next: NextFunction) {
        try {
            const { email, password } = req.body;

            if (!email || !password) {
                throw new AppError('Email and password are required', 400);
            }

            // TODO: Get user from database
            const user = {
                id: 1,
                email: 'admin@example.com',
                password: await bcrypt.hash('password123', 10),
                name: 'Admin User',
                role: 'admin',
                organizationId: 1
            };

            const isValidPassword = await bcrypt.compare(password, user.password);

            if (!isValidPassword) {
                throw new AppError('Invalid credentials', 401);
            }

            const token = jwt.sign(
                { id: user.id, email: user.email, role: user.role, organizationId: user.organizationId },
                process.env.JWT_SECRET!,
                { expiresIn: '7d' }
            );

            res.json({
                user: {
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    role: user.role
                },
                token
            });
        } catch (error) {
            next(error);
        }
    }

    async getCurrentUser(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            // TODO: Get full user details from database
            res.json({ user: req.user });
        } catch (error) {
            next(error);
        }
    }

    async logout(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            // TODO: Invalidate token (add to blacklist)
            res.json({ message: 'Logged out successfully' });
        } catch (error) {
            next(error);
        }
    }

    async forgotPassword(req: Request, res: Response, next: NextFunction) {
        try {
            const { email } = req.body;

            // TODO: Generate reset token and send email
            res.json({ message: 'Password reset email sent' });
        } catch (error) {
            next(error);
        }
    }

    async resetPassword(req: Request, res: Response, next: NextFunction) {
        try {
            const { token, newPassword } = req.body;

            // TODO: Verify token and update password
            res.json({ message: 'Password reset successful' });
        } catch (error) {
            next(error);
        }
    }

    async changePassword(req: AuthRequest, res: Response, next: NextFunction) {
        try {
            const { currentPassword, newPassword } = req.body;

            // TODO: Verify current password and update
            res.json({ message: 'Password changed successfully' });
        } catch (error) {
            next(error);
        }
    }
}
