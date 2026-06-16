```markdown
# MindVault Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches you the core development patterns used in the MindVault repository, a TypeScript codebase with no detected framework. You'll learn the project's file naming conventions, import/export styles, commit message patterns, and how to write and organize tests. This guide is ideal for contributors aiming for consistency and maintainability in MindVault.

## Coding Conventions

### File Naming
- Use **PascalCase** for file names.
  - Example: `UserService.ts`, `DataManager.test.ts`

### Import Style
- Use **relative imports** for referencing modules.
  - Example:
    ```typescript
    import { fetchData } from './DataFetcher';
    ```

### Export Style
- Use **named exports** exclusively.
  - Example:
    ```typescript
    // DataFetcher.ts
    export function fetchData() { /* ... */ }
    ```

### Commit Messages
- Follow **conventional commit** style.
- Use the `chore` prefix for maintenance commits.
- Keep commit messages concise (average ~40 characters).
  - Example:  
    ```
    chore: update dependencies
    ```

## Workflows

### Code Contribution
**Trigger:** When adding or updating code  
**Command:** `/contribute`

1. Create or update TypeScript files using PascalCase naming.
2. Use relative imports and named exports.
3. Write or update corresponding test files (`*.test.ts`).
4. Stage your changes.
5. Commit using the conventional commit style (e.g., `chore: add UserService`).
6. Push your branch and open a pull request.

### Writing Tests
**Trigger:** When adding new features or fixing bugs  
**Command:** `/write-test`

1. Create a test file named `ComponentName.test.ts` alongside the code.
2. Write tests using your preferred testing framework (framework not enforced).
3. Ensure tests cover all new or changed logic.
4. Run tests to verify correctness.

## Testing Patterns

- Test files follow the `*.test.ts` naming pattern.
- Place test files near the code they test.
- No specific testing framework is enforced; choose one as appropriate.
- Example test file:
  ```typescript
  // UserService.test.ts
  import { getUser } from './UserService';

  describe('getUser', () => {
    it('returns user data', () => {
      // test implementation
    });
  });
  ```

## Commands
| Command        | Purpose                                      |
|----------------|----------------------------------------------|
| /contribute    | Guide for contributing code                  |
| /write-test    | Steps for writing and organizing tests       |
```
