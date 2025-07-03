# Contributing to Kubernetes AKC Infrastructure

Thank you for your interest in contributing to the Kubernetes AKC Infrastructure project! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues
- Use the GitHub issue tracker to report bugs or request features
- Provide detailed information about your environment and the issue
- Include logs and configuration files (sanitized of sensitive information)

### Submitting Changes
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly with the setup script
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Create a Pull Request

## 🧪 Testing

### Local Testing
Before submitting a PR, test your changes:

```bash
# Test the setup script
./setup.sh --dry-run

# Test specific components
terraform plan -var-file="terraform.tfvars.example"
helm lint helm/akc-controller/
kubectl apply --dry-run=client -f manifests/
```

### Required Tests
- All Terraform configurations must pass `terraform validate`
- All Helm charts must pass `helm lint`
- All Kubernetes manifests must pass `kubectl apply --dry-run`
- Setup script must work in both interactive and non-interactive modes

## 📝 Documentation

### Code Documentation
- Document all configuration variables
- Include inline comments for complex logic
- Update README.md for new features
- Add examples for new functionality

### Commit Messages
Use conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
- `feat(terraform): add support for custom VM sizes`
- `fix(helm): resolve AKC controller startup issue`
- `docs(readme): update installation instructions`

## 🏗️ Development Environment

### Prerequisites
- RHEL 9 or compatible system
- Terraform >= 1.5.0
- Helm >= 3.8.0
- kubectl >= 1.25.0
- Docker or Podman

### Setting Up Development Environment
```bash
# Clone the repository
git clone https://github.com/0xGuyG/k8s-akc.git
cd k8s-akc

# Create configuration files
cp config/deployment.conf.example config/deployment.conf
cp terraform/clusters/terraform.tfvars.example terraform/clusters/terraform.tfvars

# Edit configuration files with your settings
```

## 🔍 Code Style

### Bash Scripts
- Use `#!/bin/bash` shebang
- Set `set -e` for error handling
- Use descriptive variable names
- Include logging functions
- Add error handling and cleanup

### Terraform
- Use consistent naming conventions
- Include variable descriptions
- Add output descriptions
- Use modules for reusable components

### Kubernetes YAML
- Use consistent labeling
- Include resource limits
- Add security contexts
- Document annotations

### Helm Charts
- Follow Helm best practices
- Include comprehensive values.yaml
- Add chart documentation
- Use template helpers

## 🔒 Security Guidelines

### Sensitive Information
- Never commit passwords, keys, or certificates
- Use example files for configuration templates
- Sanitize logs and documentation
- Use Kubernetes secrets for sensitive data

### Security Best Practices
- Implement least-privilege access
- Use Pod Security Standards
- Enable network policies
- Regular security updates

## 📋 Pull Request Checklist

Before submitting a PR, ensure:

- [ ] Code follows project style guidelines
- [ ] All tests pass locally
- [ ] Documentation is updated
- [ ] Commit messages follow convention
- [ ] No sensitive information is included
- [ ] Changes are backward compatible (or noted)
- [ ] Setup script works with changes

## 🏷️ Release Process

### Versioning
We use [Semantic Versioning](https://semver.org/):
- MAJOR.MINOR.PATCH
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

### Release Steps
1. Update version numbers
2. Update CHANGELOG.md
3. Create release tag
4. Update documentation
5. Test release thoroughly

## 💬 Community

### Communication
- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: General questions and ideas
- Pull Requests: Code contributions

### Code of Conduct
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Follow the Golden Rule

## 📚 Resources

### Documentation
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://terraform.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Calico Documentation](https://docs.projectcalico.org/)

### Radware Resources
- [Alteon Documentation](https://portals.radware.com/)
- [AKC Documentation](https://github.com/radware/akc-controller)

## ❓ Getting Help

If you need help:
1. Check existing documentation
2. Search existing issues
3. Create a new issue with detailed information
4. Be patient and respectful

Thank you for contributing to the Kubernetes AKC Infrastructure project! 🚀