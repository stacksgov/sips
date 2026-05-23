# Contributing to CPM-c/sips

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the Stacks Improvement Proposals (SIPs) repository.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Submission Process](#submission-process)
- [Commit Signoff Requirement](#commit-signoff-requirement)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

All contributors are expected to:

- Be respectful and inclusive
- Assume good intentions
- Provide constructive feedback
- Report violations to the project maintainers

## Getting Started

1. **Fork the Repository**
   ```bash
   git clone https://github.com/CPM-c/sips.git
   cd sips
   ```

2. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Follow the existing code style and formatting
   - Keep commits focused and atomic
   - Write clear commit messages

## Submission Process

### 1. Prepare Your Contribution

- Ensure your changes are well-documented
- Test your changes thoroughly
- Update relevant documentation or README sections
- Verify code formatting and style consistency

### 2. Commit with Sign-off

All commits **must** be signed off using the Developer Certificate of Origin (DCO):

```bash
git commit -s -m "Your descriptive commit message"
```

The `-s` flag adds a sign-off line to your commit:
```
Signed-off-by: Your Name <your.email@example.com>
```

This certifies that you have the right to submit this work under the repository's license.

### 3. Push Your Branch

```bash
git push origin feature/your-feature-name
```

### 4. Create a Pull Request

When you create a PR:

- Use a clear, descriptive title
- Reference any related issues (e.g., "Closes #123")
- Provide a detailed description of your changes
- List any breaking changes or migration steps
- Ensure all commits are signed off

## Commit Signoff Requirement

By signing off your commits with `-s`, you certify that:

1. You have the right to submit this work under the MIT License
2. Your work does not violate any third-party intellectual property rights
3. You understand the terms of the [Individual Contributor License Agreement](INDIVIDUAL_CLA.md)

### DCO (Developer Certificate of Origin)

```
Developer Certificate of Origin
Version 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

## Pull Request Guidelines

### Before Submitting

- [ ] All commits are signed off with `-s`
- [ ] Branch is up to date with `main`
- [ ] Code follows repository style guidelines
- [ ] Documentation is updated if needed
- [ ] No merge conflicts

### PR Description Template

```markdown
## Description
Brief description of what this PR does.

## Related Issues
Closes #123

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Code refactoring
- [ ] Other (please describe)

## Changes Made
- Detailed change 1
- Detailed change 2

## Testing
How have you tested these changes?

## Breaking Changes
Any breaking changes? If yes, describe migration path.
```

### Review Process

1. Automated checks will run (linting, tests, signoff verification)
2. At least one maintainer will review your PR
3. Address feedback and push updates to your branch
4. PR will be merged once approved

## Reporting Issues

Found a bug or have a suggestion?

1. Check existing issues to avoid duplicates
2. Provide clear, descriptive titles
3. Include:
   - Steps to reproduce (for bugs)
   - Expected behavior
   - Actual behavior
   - Environment details (OS, version, etc.)
   - Screenshots or logs if applicable

## Questions?

- Review existing documentation
- Check closed issues and PRs
- Ask in the repository discussions (if enabled)

---

**Thank you for contributing! We appreciate your help in improving the Stacks ecosystem.**

*Last Updated: May 23, 2026*
