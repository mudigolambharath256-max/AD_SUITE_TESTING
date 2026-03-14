# Contributing to AD Security Suite

Thank you for your interest in contributing to AD Security Suite! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites
- Node.js 18+ and npm 8+
- Windows 10/11 or Windows Server 2016+
- Git for version control
- Basic knowledge of React, Node.js, and Active Directory

### Development Setup
1. Fork the repository
2. Clone your fork locally
3. Run `npm run setup` to install dependencies
4. Run `npm run dev` to start development servers
5. Make your changes and test thoroughly

## Project Structure

```
ad-suite-web/
├── backend/                 # Node.js/Express backend
│   ├── routes/             # API route handlers
│   ├── services/           # Business logic services
│   └── server.js           # Main server file
├── frontend/               # React frontend
│   ├── src/
│   │   ├── pages/          # Page components
│   │   ├── components/     # Reusable components
│   │   ├── hooks/          # Custom React hooks
│   │   └── lib/            # Utilities and API client
│   └── public/             # Static assets
└── docs/                   # Documentation
```

## Coding Standards

### JavaScript/React
- Use ES6+ features and modern syntax
- Follow React best practices and hooks patterns
- Use meaningful variable and function names
- Add JSDoc comments for complex functions
- Keep components small and focused

### CSS/Tailwind
- Use Tailwind utility classes primarily
- Create custom CSS only when necessary
- Follow mobile-first responsive design
- Maintain consistent spacing and color usage

### File Naming
- Use PascalCase for React components
- Use camelCase for JavaScript files
- Use kebab-case for CSS files
- Keep filenames descriptive and concise

## Contribution Guidelines

### Before Contributing
1. Check existing issues and pull requests
2. Discuss major changes in an issue first
3. Ensure your changes align with project goals
4. Test your changes thoroughly

### Making Changes
1. Create a new branch for your feature
2. Make your changes following coding standards
3. Add tests if applicable
4. Update documentation if needed
5. Commit with clear, descriptive messages

### Pull Request Process
1. Update README.md if new features were added
2. Ensure your PR description clearly describes the changes
3. Link any relevant issues in your PR
4. Wait for code review and address feedback
5. Ensure CI/CD checks pass before merge

## Types of Contributions

### Bug Fixes
- Describe the bug and how to reproduce it
- Explain the fix and why it works
- Add tests to prevent regression
- Update documentation if needed

### New Features
- Open an issue to discuss the feature first
- Explain the use case and benefits
- Design the API/UI before implementation
- Consider backwards compatibility
- Add comprehensive tests

### Documentation
- Fix typos and grammatical errors
- Improve clarity and organization
- Add examples and tutorials
- Update API documentation
- Translate content if applicable

### Security
- Report security issues privately
- Follow responsible disclosure
- Explain security implications
- Suggest mitigation strategies
- Update security documentation

## Testing

### Unit Tests
- Test individual functions and components
- Mock external dependencies
- Cover edge cases and error conditions
- Aim for high code coverage

### Integration Tests
- Test API endpoints and database operations
- Test component interactions
- Test error handling and recovery
- Test with realistic data

### Manual Testing
- Test all user workflows
- Test on different screen sizes
- Test with various browsers
- Test with real AD environments if possible

## Code Review Guidelines

### For Reviewers
- Check code quality and standards
- Verify functionality and performance
- Ensure security best practices
- Test the changes if possible
- Provide constructive feedback

### For Contributors
- Address all review feedback
- Explain complex design decisions
- Update tests and documentation
- Re-run tests after changes
- Be responsive to reviewer comments

## Release Process

### Version Bumping
- Follow semantic versioning
- Update package.json versions
- Update CHANGELOG.md
- Create git tag for release

### Deployment
- Test in staging environment first
- Create backup of current version
- Deploy during low-traffic periods
- Monitor for issues after deployment
- Roll back if necessary

## Community Guidelines

### Code of Conduct
- Be respectful and professional
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Avoid personal attacks or criticism
- Report issues to maintainers

### Communication
- Use clear and descriptive titles
- Provide context and background
- Include screenshots for UI issues
- Use appropriate channels for discussions
- Follow issue templates when available

## Recognition

### Contributors
- All contributors are credited in README.md
- Significant contributions may be added to core team
- Feature requests from contributors are prioritized
- Community feedback is valued and appreciated

### Attribution
- Maintain original author attribution
- Credit all contributors appropriately
- Follow license requirements for third-party code
- Document external dependencies and licenses

## Getting Help

### Resources
- Read the documentation thoroughly
- Search existing issues and discussions
- Check the troubleshooting guide
- Review code examples and patterns

### Support Channels
- Create an issue for bugs or questions
- Join community discussions
- Contact maintainers for security issues
- Refer to documentation for common issues

## License

By contributing to this project, you agree that your contributions will be licensed under the same MIT License as the project itself.

---

Thank you for contributing to AD Security Suite! Your help makes this project better for everyone.
