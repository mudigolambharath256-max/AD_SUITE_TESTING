import express from 'express';
import { authenticate, authorize } from '../middleware/auth';

const router = express.Router();
router.use(authenticate);

router.get('/', authorize('admin'), (req, res) => res.json({ users: [] }));
router.post('/', authorize('admin'), (req, res) => res.json({ message: 'User created' }));
router.put('/:id', authorize('admin'), (req, res) => res.json({ message: 'User updated' }));
router.delete('/:id', authorize('admin'), (req, res) => res.json({ message: 'User deleted' }));

export default router;
