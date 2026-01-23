# CLAUDE.md - AI Assistant Guidelines

> This file provides context and guidelines for AI assistants working with this repository.

## Repository Overview

**Project Name:** Test
**Status:** New/Empty Repository
**Last Updated:** 2026-01-23

This is a newly initialized repository. Update this section as the project develops with:
- Project purpose and goals
- Target audience/users
- Key features

## Project Structure

```
/home/user/Test/
├── .git/              # Git version control
├── CLAUDE.md          # This file - AI assistant guidelines
└── (empty)            # Add project files here
```

### Directory Conventions (To Be Established)

As the project grows, document the directory structure here. Common patterns:

| Directory | Purpose |
|-----------|---------|
| `src/` | Source code |
| `tests/` | Test files |
| `docs/` | Documentation |
| `scripts/` | Utility scripts |
| `config/` | Configuration files |

## Technology Stack

> Update this section when technologies are added to the project.

- **Language:** TBD
- **Framework:** TBD
- **Package Manager:** TBD
- **Build System:** TBD
- **Testing Framework:** TBD

## Development Workflow

### Getting Started

```bash
# Clone the repository
git clone <repository-url>
cd Test

# Install dependencies (update when package manager is chosen)
# npm install / pip install -r requirements.txt / etc.
```

### Common Commands

> Add project-specific commands as they are established.

| Command | Description |
|---------|-------------|
| TBD | Build the project |
| TBD | Run tests |
| TBD | Start development server |
| TBD | Lint/format code |

### Git Workflow

1. **Branch Naming:**
   - Feature branches: `feature/<description>`
   - Bug fixes: `fix/<description>`
   - AI-assisted branches: `claude/<description>`

2. **Commit Messages:** Use clear, descriptive messages
   - Format: `<type>: <description>`
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

3. **Pull Requests:**
   - Provide clear description of changes
   - Reference related issues
   - Ensure tests pass before merging

## Code Conventions

> Establish and document coding standards here as the project develops.

### General Guidelines

- Write clean, readable, self-documenting code
- Follow language-specific best practices
- Keep functions/methods focused and small
- Add comments only when logic is not self-evident
- Avoid over-engineering - implement only what's needed

### File Naming

- Use consistent naming conventions (to be established)
- Keep file names descriptive and concise

### Documentation

- Maintain up-to-date README.md
- Document public APIs
- Include usage examples where helpful

## Testing Guidelines

> Update when testing framework is established.

- Write tests for new features
- Ensure existing tests pass before committing
- Aim for meaningful test coverage
- Test edge cases and error conditions

## AI Assistant Instructions

### When Working on This Repository

1. **Always read before modifying:** Understand existing code before making changes
2. **Maintain consistency:** Follow established patterns and conventions
3. **Keep changes focused:** Make only the requested changes, avoid over-engineering
4. **Test your changes:** Run existing tests and add new ones as appropriate
5. **Document significant changes:** Update relevant documentation

### Things to Avoid

- Don't introduce security vulnerabilities (XSS, SQL injection, etc.)
- Don't add unnecessary dependencies
- Don't make breaking changes without explicit approval
- Don't commit sensitive data (API keys, passwords, etc.)
- Don't ignore existing code patterns without good reason

### Helpful Context

- This repository uses Git for version control
- The main development branch is tracked via Git
- Check `.gitignore` for files that should not be committed

## Environment Setup

> Document environment requirements and setup steps here.

### Prerequisites

- Git installed
- (Add language runtime requirements)
- (Add other dependencies)

### Environment Variables

> List required environment variables here.

| Variable | Description | Required |
|----------|-------------|----------|
| TBD | TBD | TBD |

## Troubleshooting

> Document common issues and solutions here.

### Common Issues

1. **Issue:** TBD
   - **Solution:** TBD

## Resources

- Repository: [ulucky-coder/Test](https://github.com/ulucky-coder/Test)
- (Add documentation links)
- (Add related resources)

---

*This CLAUDE.md file should be updated as the project evolves to reflect current structure, conventions, and workflows.*
