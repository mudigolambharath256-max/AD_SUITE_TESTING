const express = require('express');
const router = express.Router();
const cron = require('node-cron');
const { v4: uuidv4 } = require('uuid');
const executor = require('../services/executor');
const db = require('../services/db');

// Store active cron jobs
const activeJobs = new Map();

// GET /api/schedules - Get all schedules
router.get('/', (req, res) => {
  try {
    const schedules = db.getSchedules();
    res.json(schedules);
  } catch (error) {
    console.error('Error getting schedules:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/schedules - Create new schedule
router.post('/', (req, res) => {
  try {
    const { name, checkIds, engine, cronExpression, autoExport, autoPush } = req.body;

    if (!name || !checkIds || !Array.isArray(checkIds) || !engine || !cronExpression) {
      return res.status(400).json({ 
        error: 'Missing required parameters: name, checkIds, engine, cronExpression' 
      });
    }

    if (checkIds.length === 0) {
      return res.status(400).json({ error: 'No checks selected' });
    }

    // Validate cron expression
    if (!cron.validate(cronExpression)) {
      return res.status(400).json({ error: 'Invalid cron expression' });
    }

    const schedule = {
      id: uuidv4(),
      name,
      checkIds,
      engine,
      cron: cronExpression,
      autoExport: autoExport || null,
      autoPush: autoPush || null,
      enabled: 1,
      lastRun: null,
      nextRun: this.calculateNextRun(cronExpression),
      createdAt: Date.now()
    };

    db.createSchedule(schedule);

    // Start the cron job if enabled
    if (schedule.enabled) {
      this.startCronJob(schedule);
    }

    res.json(schedule);
  } catch (error) {
    console.error('Error creating schedule:', error);
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/schedules/:id - Update schedule
router.put('/:id', (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    // Validate cron expression if provided
    if (updates.cron && !cron.validate(updates.cron)) {
      return res.status(400).json({ error: 'Invalid cron expression' });
    }

    // Stop existing cron job
    this.stopCronJob(id);

    // Update next run time if cron changed
    if (updates.cron) {
      updates.nextRun = this.calculateNextRun(updates.cron);
    }

    db.updateSchedule(id, updates);

    // Get updated schedule
    const schedules = db.getSchedules();
    const updatedSchedule = schedules.find(s => s.id === id);

    if (updatedSchedule && updatedSchedule.enabled) {
      this.startCronJob(updatedSchedule);
    }

    res.json(updatedSchedule);
  } catch (error) {
    console.error('Error updating schedule:', error);
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/schedules/:id - Delete schedule
router.delete('/:id', (req, res) => {
  try {
    const { id } = req.params;

    // Stop cron job
    this.stopCronJob(id);

    // Delete from database
    db.deleteSchedule(id);

    res.json({ deleted: true });
  } catch (error) {
    console.error('Error deleting schedule:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/schedules/:id/run - Trigger schedule manually
router.post('/:id/run', async (req, res) => {
  try {
    const { id } = req.params;

    const schedules = db.getSchedules();
    const schedule = schedules.find(s => s.id === id);

    if (!schedule) {
      return res.status(404).json({ error: 'Schedule not found' });
    }

    // Get suite root from settings
    const suiteRoot = db.getSetting('suiteRoot');
    if (!suiteRoot) {
      return res.status(400).json({ error: 'Suite root not configured' });
    }

    // Start scan
    const scanId = await executor.runScan({
      suiteRoot,
      checkIds: JSON.parse(schedule.check_ids),
      engine: schedule.engine,
      sequential: true
    });

    // Update last run time
    db.updateSchedule(id, { lastRun: Date.now() });

    res.json({ scanId, message: 'Scan started' });
  } catch (error) {
    console.error('Error running schedule:', error);
    res.status(500).json({ error: error.message });
  }
});

// Helper functions
function calculateNextRun(cronExpression) {
  try {
    const task = cron.schedule(cronExpression, () => {}, { scheduled: false });
    // This is a simplified calculation - in production you might want a more robust solution
    const nextRun = new Date(Date.now() + 60000); // Default to 1 minute from now
    return nextRun.getTime();
  } catch (error) {
    return Date.now() + 60000;
  }
}

function startCronJob(schedule) {
  try {
    const task = cron.schedule(schedule.cron, async () => {
      try {
        console.log(`Running scheduled scan: ${schedule.name}`);
        
        const suiteRoot = db.getSetting('suiteRoot');
        if (!suiteRoot) {
          console.error('Suite root not configured for scheduled scan');
          return;
        }

        const scanId = await executor.runScan({
          suiteRoot,
          checkIds: JSON.parse(schedule.check_ids),
          engine: schedule.engine,
          sequential: true
        });

        // Update last run time
        db.updateSchedule(schedule.id, { lastRun: Date.now() });

        // Wait for scan to complete, then handle auto-export/push
        const checkCompletion = setInterval(async () => {
          const progress = executor.getScanProgress(scanId);
          
          if (!progress || progress.status === 'completed' || progress.status === 'aborted') {
            clearInterval(checkCompletion);
            
            if (progress && progress.status === 'completed') {
              // Handle auto-export
              if (schedule.auto_export) {
                try {
                  const exporter = require('../services/exporter');
                  await exporter.exportScan(scanId, schedule.auto_export);
                  console.log(`Auto-exported scan ${scanId} as ${schedule.auto_export}`);
                } catch (exportError) {
                  console.error('Auto-export failed:', exportError);
                }
              }

              // Handle auto-push
              if (schedule.auto_push) {
                try {
                  const integrations = require('./integrations');
                  const config = getIntegrationConfig(schedule.auto_push);
                  
                  if (config) {
                    await integrations.pushToIntegration(schedule.auto_push, scanId, config);
                    console.log(`Auto-pushed scan ${scanId} to ${schedule.auto_push}`);
                  }
                } catch (pushError) {
                  console.error('Auto-push failed:', pushError);
                }
              }
            }
          }
        }, 5000);

      } catch (error) {
        console.error(`Scheduled scan failed: ${schedule.name}`, error);
      }
    }, { scheduled: true });

    activeJobs.set(schedule.id, task);
    console.log(`Started cron job for schedule: ${schedule.name}`);
  } catch (error) {
    console.error(`Failed to start cron job for schedule ${schedule.name}:`, error);
  }
}

function stopCronJob(scheduleId) {
  const task = activeJobs.get(scheduleId);
  if (task) {
    task.stop();
    activeJobs.delete(scheduleId);
    console.log(`Stopped cron job for schedule: ${scheduleId}`);
  }
}

function getIntegrationConfig(integrationType) {
  // Get integration config from database settings
  const config = {};
  
  switch (integrationType) {
    case 'bloodhound':
      config.url = db.getSetting('integration_bh_url');
      config.username = db.getSetting('integration_bh_username');
      config.password = db.getSetting('integration_bh_password');
      config.version = db.getSetting('integration_bh_version') || 'CE';
      break;
    case 'neo4j':
      config.boltUri = db.getSetting('integration_neo4j_boltUri');
      config.username = db.getSetting('integration_neo4j_username');
      config.password = db.getSetting('integration_neo4j_password');
      config.database = db.getSetting('integration_neo4j_database') || 'neo4j';
      break;
    case 'mcp':
      config.serverUrl = db.getSetting('integration_mcp_serverUrl');
      config.apiKey = db.getSetting('integration_mcp_apiKey');
      config.workspaceId = db.getSetting('integration_mcp_workspaceId');
      break;
    default:
      return null;
  }

  // Check if required fields are present
  const hasRequiredFields = Object.values(config).every(value => value !== null && value !== '');
  return hasRequiredFields ? config : null;
}

// Initialize existing schedules on startup
function initializeSchedules() {
  try {
    const schedules = db.getSchedules();
    
    schedules.forEach(schedule => {
      if (schedule.enabled) {
        startCronJob(schedule);
      }
    });

    console.log(`Initialized ${schedules.length} schedules`);
  } catch (error) {
    console.error('Error initializing schedules:', error);
  }
}

// Initialize on module load
initializeSchedules();

module.exports = router;
