# Contributing to Qubix

Thank you for your interest in contributing to Qubix! This document outlines the process for contributing to the repository.

## Development Workflow

1. **Branching**: Create a new branch for each feature or bug fix. Use conventional naming, such as `feat/my-feature` or `fix/issue-description`.
2. **Commit Messages**: We follow [Conventional Commits](https://www.conventionalcommits.org/). This means commit messages should be prefixed with `feat:`, `fix:`, `docs:`, `refactor:`, etc.
3. **Pull Requests**: Open a pull request against the `master` branch. Ensure that all tests pass and that your code is fully linted.

## Backend Development (`apps/server`)

- We use TypeScript and Express.
- Ensure any database changes include Prisma migrations (`npx prisma migrate dev`).
- Avoid exposing sensitive configurations. Use the established masking patterns for Agent connectors.
- Run `npm run lint` and `npm run test` (if applicable) before pushing.

## Mobile Development (`apps/mobile`)

- We use Flutter and Dart.
- State management relies heavily on `flutter_riverpod`. Please follow existing patterns for ViewModels.
- UI components should use the established design system in `core/theme/`.
- Ensure there are zero analyzer errors: run `flutter analyze`.

## Reporting Issues

If you find a bug or have a feature request, please open an issue in the repository describing the problem or the proposed feature in detail. Include steps to reproduce, logs, and any other relevant context.
