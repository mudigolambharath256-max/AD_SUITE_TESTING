import express from 'express';
import rateLimit from 'express-rate-limit';
import { AuthController } from '../controllers/authController';
import { authenticate } from '../middleware/auth';

const router = express.Router();
const authController = new AuthController();

const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 50,
    standardHeaders: true,
    legacyHeaders: false,
    message: { message: 'Too many login attempts, try again later.' }
});

// Public routes
router.post('/register', authController.register);
router.post('/login', loginLimiter, authController.login);
router.post('/forgot-password', authController.forgotPassword);
router.post('/reset-password', authController.resetPassword);

// Protected routes
router.get('/me', authenticate, authController.getCurrentUser);
router.post('/logout', authenticate, authController.logout);
router.put('/change-password', authenticate, authController.changePassword);

export default router;
