# Contributing to Perjury App

Thank you for your interest in contributing!

## Getting Started

Fork & clone:

```bash
git clone git@github.com:<you>/perjury.git
```

### Branching

```bash
git checkout -b feature/my-change
```

---

## Development Environment

Install:

```bash
pip install -r requirements.txt
pip install pre-commit
pre-commit install
```

Run:

```bash
python main.py
```

---

## Code Style

- Black
- isort
- Flake8
- pre-commit hooks

---

## Security Requirements

All contributions must:
- Not expose secrets
- Not weaken token or IP-blocking logic
- Avoid persistent debug logging
- Maintain fail-closed behaviour

---

## Submitting PRs

Provide:
- What changed
- Why
- How to test
- Security considerations

PRs must pass pre-commit hooks.
