"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthController = void 0;
const bcrypt_1 = __importDefault(require("bcrypt"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const errorHandler_1 = require("../middleware/errorHandler");
class AuthController {
    async register(req, res, next) {
        try {
            const { email, password, name, organizationName } = req.body;
            if (!email || !password || !name) {
                throw new errorHandler_1.AppError('Email, password, and name are required', 400);
            }
            // TODO: Check if user exists in database
            const hashedPassword = await bcrypt_1.default.hash(password, 10);
            // TODO: Save user to database
            const user = {
                id: Date.now(),
                email,
                name,
                role: 'admin',
                organizationId: Date.now()
            };
            const token = jsonwebtoken_1.default.sign({ id: user.id, email: user.email, role: user.role, organizationId: user.organizationId }, process.env.JWT_SECRET, { expiresIn: '7d' });
            res.status(201).json({ user, token });
        }
        catch (error) {
            next(error);
        }
    }
    async login(req, res, next) {
        try {
            const { email, password } = req.body;
            if (!email || !password) {
                throw new errorHandler_1.AppError('Email and password are required', 400);
            }
            // TODO: Get user from database
            const user = {
                id: 1,
                email: 'admin@example.com',
                password: await bcrypt_1.default.hash('password123', 10),
                name: 'Admin User',
                role: 'admin',
                organizationId: 1
            };
            const isValidPassword = await bcrypt_1.default.compare(password, user.password);
            if (!isValidPassword) {
                throw new errorHandler_1.AppError('Invalid credentials', 401);
            }
            const token = jsonwebtoken_1.default.sign({ id: user.id, email: user.email, role: user.role, organizationId: user.organizationId }, process.env.JWT_SECRET, { expiresIn: '7d' });
            res.json({
                user: {
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    role: user.role
                },
                token
            });
        }
        catch (error) {
            next(error);
        }
    }
    async getCurrentUser(req, res, next) {
        try {
            // TODO: Get full user details from database
            res.json({ user: req.user });
        }
        catch (error) {
            next(error);
        }
    }
    async logout(req, res, next) {
        try {
            // TODO: Invalidate token (add to blacklist)
            res.json({ message: 'Logged out successfully' });
        }
        catch (error) {
            next(error);
        }
    }
    async forgotPassword(req, res, next) {
        try {
            const { email } = req.body;
            // TODO: Generate reset token and send email
            res.json({ message: 'Password reset email sent' });
        }
        catch (error) {
            next(error);
        }
    }
    async resetPassword(req, res, next) {
        try {
            const { token, newPassword } = req.body;
            // TODO: Verify token and update password
            res.json({ message: 'Password reset successful' });
        }
        catch (error) {
            next(error);
        }
    }
    async changePassword(req, res, next) {
        try {
            const { currentPassword, newPassword } = req.body;
            // TODO: Verify current password and update
            res.json({ message: 'Password changed successfully' });
        }
        catch (error) {
            next(error);
        }
    }
}
exports.AuthController = AuthController;
//# sourceMappingURL=authController.js.map