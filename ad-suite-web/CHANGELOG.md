# Changelog

All notable changes to AD Security Suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-12

### Added
- **Complete web application** for AD Security Suite
- **775 security checks** across 27 categories
- **5 execution engines** (ADSI, PowerShell, C#, CMD, Combined)
- **Real-time scanning** with Server-Sent Events
- **6 complete pages** with professional UI
- **Dashboard** with charts and statistics
- **Run Scans** interface with category selection
- **Attack Path Analysis** with LLM integration
- **External Integrations** (BloodHound, Neo4j, MCP)
- **Reports** with filtering and bulk operations
- **Settings** for configuration and preferences
- **Export functionality** (JSON, CSV, PDF)
- **Scheduled scanning** with cron-based automation
- **Responsive design** for mobile/tablet/desktop
- **Claude.ai color palette** with dark theme
- **SQLite database** for scan history and findings
- **PowerShell/C#/CMD execution** service
- **AI-powered attack path visualization** with ReactFlow
- **Professional documentation** and installation guides

### Security
- **Read-only LDAP queries** - no AD modifications
- **Sandboxed script execution** with timeout protection
- **Local storage only** for API keys and credentials
- **Bypass execution policy** for safety
- **Error handling** and input validation

### Technical
- **React 18** with modern hooks and patterns
- **Node.js + Express** backend
- **Server-Sent Events** for real-time updates
- **Tailwind CSS** with custom color system
- **Better-sqlite3** for database operations
- **PDF generation** with pdfkit
- **CSV export** with csv-stringify
- **Cron scheduling** with node-cron
- **LLM integration** for multiple providers

### Documentation
- **Comprehensive README** with installation guide
- **API documentation** with examples
- **Troubleshooting section** for common issues
- **Security considerations** and best practices
- **Development guidelines** and architecture overview

### Installation
- **Windows batch files** for easy startup
- **Development and production modes**
- **Automated dependency installation**
- **Database initialization** and setup
- **Configuration validation**

### Performance
- **Exponential backoff retry** for SSE connections
- **Lazy loading** for findings data
- **Efficient database indexing**
- **Optimized React rendering**
- **Memory management** for large datasets

### Integrations
- **BloodHound** v4 format compatibility
- **Neo4j** direct graph database storage
- **MCP Server** external platform support
- **LLM providers**: Anthropic Claude, OpenAI GPT, Ollama
- **Connection testing** and validation

### UI/UX
- **Professional dark theme** with Claude.ai colors
- **Responsive design** for all screen sizes
- **Real-time animations** and transitions
- **Loading states** and error handling
- **Accessibility features** and keyboard navigation
- **Collapsible sidebars** and adaptive layouts

---

## [Unreleased]

### Planned
- **Mobile app** companion
- **Additional LLM providers**
- **Advanced reporting templates**
- **Role-based access control**
- **Multi-domain support**
- **Audit logging**
- **API rate limiting**
- **Automated remediation suggestions
