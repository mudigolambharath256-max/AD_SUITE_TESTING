# Run Scans Feature - User Guide

## Overview

The Run Scans page allows you to configure and execute custom Active Directory security scans directly from the web interface. You can select specific categories and checks, monitor real-time progress, and visualize results in an interactive graph.

---

## 🚀 Quick Start

### 1. Navigate to Run Scans
- Click "New Scan" in the sidebar
- Or click "Run Full Suite" from the Dashboard

### 2. Configure Your Scan

#### Step 1: Name Your Scan (Optional)
```
Enter a descriptive name like:
- "Weekly Security Audit"
- "Kerberos Security Check"
- "Privileged Access Review"
```

#### Step 2: Select Categories
- Click on category buttons to select/deselect
- Selected categories show orange border and checkmark
- Available categories include:
  - Access_Control
  - Kerberos_Security
  - Group_Policy
  - Privileged_Access
  - Certificate_Services
  - And more...

#### Step 3: Select Individual Checks
- Use the search bar to filter checks by:
  - Check ID (e.g., "ACC-001")
  - Check name
  - Description keywords
- Click on any check to toggle selection
- Selecting a category auto-selects all checks in that category
- Deselecting a category removes all checks in that category

### 3. Run the Scan
- Click the "Run Scan" button
- Progress bar appears showing real-time status
- Status messages update as scan progresses
- Wait for completion (typically 2-5 minutes)

### 4. View Results
- Graph visualization appears automatically
- Shows nodes (Users, Computers, Groups, OUs)
- Shows relationships (MemberOf, AdminTo, etc.)
- Use controls to zoom, pan, and explore

---

## 📊 Understanding the Interface

### Category Selection Grid
```
┌─────────────────┬─────────────────┬─────────────────┐
│ Access_Control  │ Kerberos_Sec... │ Group_Policy    │
│ ✓ Selected      │   Not Selected  │   Not Selected  │
└─────────────────┴─────────────────┴─────────────────┘
```

### Check List
```
┌──────────────────────────────────────────────────────┐
│ Search: [kerberos                              ] 🔍  │
├──────────────────────────────────────────────────────┤
│ ☑ ACC-001  [high]  Access_Control               │
│   Unconstrained Delegation Enabled                   │
│   Identifies accounts with unconstrained...          │
├──────────────────────────────────────────────────────┤
│ ☐ ACC-002  [medium]  Access_Control             │
│   Weak Password Policy                               │
│   Checks for weak password requirements...           │
└──────────────────────────────────────────────────────┘
```

### Progress Bar
```
Status: running                                    75%
████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░
⟳ Executing checks... Processing Kerberos_Security
```

### Graph Visualization
```
┌──────────────────────────────────────────────────────┐
│  [Zoom In] [Zoom Out] [Full Screen]                 │
│                                                      │
│     👤 User1 ──MemberOf──> 👥 Domain Admins         │
│                                  │                   │
│                              AdminTo                 │
│                                  ↓                   │
│                            💻 DC01                   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 🎨 Visual Indicators

### Severity Colors
- 🔴 **Critical**: Red - Immediate action required
- 🟠 **High**: Orange - High priority
- 🟡 **Medium**: Yellow - Moderate priority
- 🔵 **Low**: Blue - Low priority
- ⚪ **Info**: Gray - Informational

### Node Colors (Graph)
- 🔵 **Blue**: Users
- 🟢 **Green**: Computers
- 🟣 **Purple**: Groups
- 🟡 **Yellow**: Organizational Units (OUs)

### Status Icons
- ✓ **CheckCircle**: Scan completed successfully
- ✗ **XCircle**: Scan failed
- ⟳ **Loader**: Scan in progress

---

## 💡 Tips & Best Practices

### Efficient Scanning
1. **Start Small**: Select 1-2 categories for your first scan
2. **Use Search**: Filter checks by keywords to find specific tests
3. **Category Focus**: Select entire categories for comprehensive audits
4. **Custom Scans**: Mix and match checks from different categories

### Performance
- **Large Domains**: Scans may take 5-10 minutes for 1000+ objects
- **Network Speed**: Faster networks = faster scans
- **Check Count**: More checks = longer scan time
- **Concurrent Scans**: Only one scan can run at a time

### Interpreting Results
1. **Graph Nodes**: Larger nodes = more connections
2. **Edge Labels**: Show relationship types
3. **Colors**: Indicate object types
4. **Zoom**: Use zoom controls to focus on specific areas

---

## 🔧 Common Workflows

### Weekly Security Audit
```
1. Select all categories
2. Click "Run Scan"
3. Review critical findings
4. Export results
5. Schedule remediation
```

### Kerberos Security Check
```
1. Select "Kerberos_Security" category
2. Add "Privileged_Access" category
3. Run scan
4. Focus on high/critical findings
5. Review delegation issues
```

### Quick Privileged Access Review
```
1. Search for "admin" or "privilege"
2. Select relevant checks
3. Run scan
4. Review graph for unexpected admin paths
5. Document findings
```

### Custom Compliance Scan
```
1. Search for specific compliance keywords
2. Select matching checks
3. Add related categories
4. Run scan
5. Generate report for auditors
```

---

## 🐛 Troubleshooting

### Scan Won't Start
- **Issue**: "Run Scan" button disabled
- **Solution**: Select at least one check

### No Results Displayed
- **Issue**: Scan completes but no graph appears
- **Solution**: Check browser console for errors, refresh page

### WebSocket Connection Failed
- **Issue**: Progress updates not appearing
- **Solution**: 
  1. Check backend is running on port 3000
  2. Check WebSocket server on port 3001
  3. Refresh the page

### Scan Takes Too Long
- **Issue**: Scan running for 10+ minutes
- **Solution**:
  1. Check PowerShell process in Task Manager
  2. Verify network connectivity to domain controller
  3. Reduce number of selected checks

### Graph Not Rendering
- **Issue**: Graph area is blank
- **Solution**:
  1. Clear browser cache (Ctrl+Shift+R)
  2. Check for JavaScript errors in console
  3. Verify Sigma.js loaded correctly

---

## 📋 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl + F` | Focus search box |
| `Escape` | Clear search |
| `Space` | Toggle selected check (when focused) |
| `Enter` | Run scan (when button focused) |

---

## 🔐 Security Notes

### Authentication Required
- All scan operations require valid JWT token
- Token expires after 24 hours
- Re-login if you see authentication errors

### Permissions
- Backend must have access to domain controller
- PowerShell execution policy must allow scripts
- Service account needs read access to AD

### Data Privacy
- Scan results stored locally in `./uploads/scans/`
- No data sent to external services
- Graph data generated from scan results only

---

## 📊 Example Scan Configurations

### Configuration 1: Full Security Audit
```yaml
Name: "Monthly Security Audit"
Categories:
  - Access_Control
  - Kerberos_Security
  - Group_Policy
  - Privileged_Access
  - Certificate_Services
Checks: All (661 checks)
Expected Duration: 5-10 minutes
```

### Configuration 2: Quick Kerberos Check
```yaml
Name: "Kerberos Quick Scan"
Categories:
  - Kerberos_Security
Checks: 45 checks
Expected Duration: 1-2 minutes
```

### Configuration 3: Privileged Access Review
```yaml
Name: "Admin Access Audit"
Categories:
  - Privileged_Access
  - Access_Control
Checks: 89 checks
Expected Duration: 2-3 minutes
```

### Configuration 4: Certificate Services Audit
```yaml
Name: "ADCS Security Check"
Categories:
  - Certificate_Services
Checks: 156 checks
Expected Duration: 3-5 minutes
```

---

## 🎯 Next Steps After Scanning

1. **Review Findings**: Check critical and high severity issues
2. **Export Results**: Download JSON for documentation
3. **Analyze Graph**: Identify unexpected privilege paths
4. **Remediate**: Address critical findings first
5. **Re-scan**: Verify fixes with another scan
6. **Document**: Save results for compliance/audit trail

---

## 📞 Support

### Getting Help
- Check `TROUBLESHOOTING.md` for common issues
- Review `DASHBOARD_DOCUMENTATION.md` for technical details
- Check backend logs in `./logs/combined.log`
- Review browser console for frontend errors

### Reporting Issues
Include the following information:
1. Scan configuration (categories, check count)
2. Error messages from console
3. Backend log entries
4. Browser and version
5. Steps to reproduce

---

**Last Updated**: March 29, 2026
**Version**: 1.0.0
