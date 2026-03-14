const PDFDocument = require('pdfkit');
const csvStringify = require('csv-stringify/sync');
const db = require('./db');

class ExporterService {
  async exportScan(scanId, format) {
    const scan = db.getScan(scanId);
    if (!scan) {
      throw new Error('Scan not found');
    }

    const findings = db.getFindings(scanId, 1, 10000); // Get all findings

    switch (format.toLowerCase()) {
      case 'json':
        return this.exportJSON(scan, findings);
      case 'csv':
        return this.exportCSV(findings);
      case 'pdf':
        return this.exportPDF(scan, findings);
      default:
        throw new Error(`Unsupported export format: ${format}`);
    }
  }

  exportJSON(scan, findings) {
    const exportData = {
      scan: {
        id: scan.id,
        timestamp: scan.timestamp,
        engine: scan.engine,
        suiteRoot: scan.suite_root,
        checkCount: scan.check_count,
        findingCount: scan.finding_count,
        duration: scan.duration_ms,
        status: scan.status
      },
      findings: findings.map(f => ({
        id: f.id,
        checkId: f.check_id,
        checkName: f.check_name,
        category: f.category,
        severity: f.severity,
        riskScore: f.risk_score,
        mitre: f.mitre,
        name: f.name,
        distinguishedName: f.distinguished_name,
        details: JSON.parse(f.details_json || '{}'),
        createdAt: f.created_at
      })),
      exportedAt: new Date().toISOString()
    };

    return {
      filename: `ad-suite-scan-${scanId}.json`,
      mimeType: 'application/json',
      data: JSON.stringify(exportData, null, 2)
    };
  }

  exportCSV(findings) {
    const csvData = findings.map(f => ({
      'Check ID': f.check_id,
      'Check Name': f.check_name,
      'Category': f.category,
      'Severity': f.severity,
      'Risk Score': f.risk_score,
      'MITRE': f.mitre,
      'Name': f.name,
      'Distinguished Name': f.distinguished_name,
      'Created At': new Date(f.created_at).toISOString()
    }));

    const csv = csvStringify.stringify(csvData, {
      header: true,
      columns: [
        'Check ID', 'Check Name', 'Category', 'Severity', 'Risk Score',
        'MITRE', 'Name', 'Distinguished Name', 'Created At'
      ]
    });

    return {
      filename: `ad-suite-findings-${Date.now()}.csv`,
      mimeType: 'text/csv',
      data: csv
    };
  }

  async exportPDF(scan, findings) {
    return new Promise((resolve, reject) => {
      try {
        const doc = new PDFDocument();
        const chunks = [];

        doc.on('data', chunk => chunks.push(chunk));
        doc.on('end', () => {
          const pdfBuffer = Buffer.concat(chunks);
          resolve({
            filename: `ad-suite-report-${scanId}.pdf`,
            mimeType: 'application/pdf',
            data: pdfBuffer
          });
        });

        // Helper function to add a new page
        const addNewPage = () => {
          if (doc.y > 700) {
            doc.addPage();
          }
        };

        // Cover Page
        doc.fontSize(24).text('AD Security Suite', { align: 'center' });
        doc.fontSize(18).text('Security Scan Report', { align: 'center' });
        doc.moveDown();

        doc.fontSize(12);
        doc.text(`Generated: ${new Date(scan.timestamp).toLocaleString()}`);
        doc.text(`Scan ID: ${scan.id}`);
        doc.text(`Engine: ${scan.engine}`);
        doc.text(`Checks Run: ${scan.check_count}`);
        doc.text(`Total Findings: ${scan.finding_count}`);
        doc.text(`Duration: ${Math.round(scan.duration_ms / 1000)}s`);
        
        doc.addPage();

        // Executive Summary
        doc.fontSize(16).text('Executive Summary');
        doc.moveDown();

        const severityCounts = {};
        findings.forEach(f => {
          severityCounts[f.severity] = (severityCounts[f.severity] || 0) + 1;
        });

        doc.fontSize(12);
        Object.entries(severityCounts).forEach(([severity, count]) => {
          doc.text(`${severity}: ${count} findings`);
        });
        doc.moveDown();

        // Findings by Category
        const categoryCounts = {};
        findings.forEach(f => {
          categoryCounts[f.category] = (categoryCounts[f.category] || 0) + 1;
        });

        doc.fontSize(14).text('Findings by Category');
        doc.fontSize(12);
        Object.entries(categoryCounts).forEach(([category, count]) => {
          doc.text(`${category}: ${count} findings`);
        });
        doc.moveDown();

        // Detailed Findings
        doc.fontSize(16).text('Detailed Findings');
        doc.moveDown();

        findings.forEach((finding, index) => {
          addNewPage();
          
          doc.fontSize(12).font('Helvetica-Bold');
          doc.text(`${index + 1}. ${finding.check_name}`);
          doc.font('Helvetica');
          
          doc.text(`Check ID: ${finding.check_id}`);
          doc.text(`Category: ${finding.category}`);
          doc.text(`Severity: ${finding.severity}`);
          doc.text(`Risk Score: ${finding.risk_score}`);
          if (finding.mitre) {
            doc.text(`MITRE: ${finding.mitre}`);
          }
          if (finding.name) {
            doc.text(`Name: ${finding.name}`);
          }
          if (finding.distinguished_name) {
            doc.text(`Distinguished Name: ${finding.distinguished_name}`);
          }

          // Add details if available
          try {
            const details = JSON.parse(finding.details_json || '{}');
            if (Object.keys(details).length > 0) {
              doc.text('Details:');
              Object.entries(details).forEach(([key, value]) => {
                if (key !== 'checkId' && key !== 'checkName') {
                  doc.text(`  ${key}: ${JSON.stringify(value)}`);
                }
              });
            }
          } catch (e) {
            // Skip if details can't be parsed
          }

          doc.moveDown();
        });

        // Footer
        const pageCount = doc.bufferedPageRange().count;
        for (let i = 0; i < pageCount; i++) {
          doc.switchToPage(i);
          doc.fontSize(8);
          doc.text(`Generated by AD Security Suite - Page ${i + 1} of ${pageCount}`, 
                   { align: 'center' });
        }

        doc.end();

      } catch (error) {
        reject(error);
      }
    });
  }

  async exportMultipleScans(scanIds, format) {
    if (format === 'pdf') {
      // For PDF, create a merged report
      return this.exportMergedPDF(scanIds);
    } else {
      // For JSON and CSV, combine all data
      const allFindings = [];
      const scans = [];

      for (const scanId of scanIds) {
        const scan = db.getScan(scanId);
        if (scan) {
          scans.push(scan);
          const findings = db.getFindings(scanId, 1, 10000);
          allFindings.push(...findings);
        }
      }

      if (format === 'json') {
        return this.exportMergedJSON(scans, allFindings);
      } else {
        return this.exportCSV(allFindings);
      }
    }
  }

  exportMergedJSON(scans, findings) {
    const exportData = {
      scans: scans.map(scan => ({
        id: scan.id,
        timestamp: scan.timestamp,
        engine: scan.engine,
        checkCount: scan.check_count,
        findingCount: scan.finding_count,
        duration: scan.duration_ms,
        status: scan.status
      })),
      findings: findings.map(f => ({
        scanId: f.scan_id,
        checkId: f.check_id,
        checkName: f.check_name,
        category: f.category,
        severity: f.severity,
        riskScore: f.risk_score,
        mitre: f.mitre,
        name: f.name,
        distinguishedName: f.distinguished_name,
        details: JSON.parse(f.details_json || '{}'),
        createdAt: f.created_at
      })),
      exportedAt: new Date().toISOString()
    };

    return {
      filename: `ad-suite-merged-${Date.now()}.json`,
      mimeType: 'application/json',
      data: JSON.stringify(exportData, null, 2)
    };
  }

  async exportMergedPDF(scanIds) {
    return new Promise((resolve, reject) => {
      try {
        const doc = new PDFDocument();
        const chunks = [];

        doc.on('data', chunk => chunks.push(chunk));
        doc.on('end', () => {
          const pdfBuffer = Buffer.concat(chunks);
          resolve({
            filename: `ad-suite-merged-report-${Date.now()}.pdf`,
            mimeType: 'application/pdf',
            data: pdfBuffer
          });
        });

        // Cover Page
        doc.fontSize(24).text('AD Security Suite', { align: 'center' });
        doc.fontSize(18).text('Merged Security Report', { align: 'center' });
        doc.moveDown();

        doc.fontSize(12);
        doc.text(`Generated: ${new Date().toLocaleString()}`);
        doc.text(`Scans Included: ${scanIds.length}`);
        doc.moveDown();

        // Summary across all scans
        let totalFindings = 0;
        const severityCounts = {};
        const categoryCounts = {};

        for (const scanId of scanIds) {
          const scan = db.getScan(scanId);
          if (scan) {
            const findings = db.getFindings(scanId, 1, 10000);
            totalFindings += findings.length;

            findings.forEach(f => {
              severityCounts[f.severity] = (severityCounts[f.severity] || 0) + 1;
              categoryCounts[f.category] = (categoryCounts[f.category] || 0) + 1;
            });
          }
        }

        doc.fontSize(14).text('Summary');
        doc.fontSize(12);
        doc.text(`Total Findings: ${totalFindings}`);
        doc.moveDown();

        doc.fontSize(14).text('Severity Distribution');
        doc.fontSize(12);
        Object.entries(severityCounts).forEach(([severity, count]) => {
          doc.text(`${severity}: ${count}`);
        });
        doc.moveDown();

        doc.fontSize(14).text('Category Distribution');
        doc.fontSize(12);
        Object.entries(categoryCounts).forEach(([category, count]) => {
          doc.text(`${category}: ${count}`);
        });
        doc.moveDown();

        // Detailed findings per scan
        scanIds.forEach((scanId, scanIndex) => {
          const scan = db.getScan(scanId);
          if (!scan) return;

          doc.addPage();
          doc.fontSize(16).text(`Scan ${scanIndex + 1}: ${scan.id}`);
          doc.fontSize(12);
          doc.text(`Date: ${new Date(scan.timestamp).toLocaleString()}`);
          doc.text(`Engine: ${scan.engine}`);
          doc.text(`Findings: ${scan.finding_count}`);
          doc.moveDown();

          const findings = db.getFindings(scanId, 1, 10000);
          findings.forEach((finding, index) => {
            if (doc.y > 700) {
              doc.addPage();
            }

            doc.font('Helvetica-Bold');
            doc.text(`${index + 1}. ${finding.check_name}`);
            doc.font('Helvetica');
            
            doc.text(`${finding.check_id} | ${finding.severity} | ${finding.category}`);
            if (finding.name) {
              doc.text(`Name: ${finding.name}`);
            }
            doc.moveDown(0.5);
          });
        });

        doc.end();

      } catch (error) {
        reject(error);
      }
    });
  }
}

module.exports = new ExporterService();
