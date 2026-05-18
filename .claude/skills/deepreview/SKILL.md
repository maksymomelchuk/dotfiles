---
name: deepreview
description: Reviews code using multiple deepdive agents to analyze git diff for correctness, security, code quality, and tech stack compliance, followed by automated fixes using deepcode agents.
---

# Code Review Command

Comprehensive code review using multiple deep dive agents to analyze git diff for correctness, security, code quality, and tech stack compliance, followed by automated fixes using deepcode agents.

## Usage

This command analyzes all changes in the git diff and verifies:

1. **Invalid code based on tech stack** (HIGHEST PRIORITY)
2. Security vulnerabilities
3. Code quality issues (dirty code)
4. Implementation correctness

Then automatically fixes any issues found.

### Optional Arguments

- **Target branch**: Optional branch name to compare against (defaults to `dev` for Evora repo)
  - Example: `/deepreview main` - compares current branch against `main`
  - If not provided, automatically detects `dev`, `main`, or `master` (in that order)

## Instructions

### Phase 1: Get Git Diff

1. **Determine the current branch and target branch**

   ```bash
   # Get current branch name
   CURRENT_BRANCH=$(git branch --show-current)
   echo "Current branch: $CURRENT_BRANCH"

   # Get target branch from user argument or detect default
   # If user provided a target branch as argument, use it
   # Otherwise, detect dev, main, or master (in that order)
   TARGET_BRANCH="${1:-}"  # First argument if provided

   if [ -z "$TARGET_BRANCH" ]; then
     # Check if dev exists (primary for Evora repo)
     if git show-ref --verify --quiet refs/heads/dev || git show-ref --verify --quiet refs/remotes/origin/dev; then
       TARGET_BRANCH="dev"
     # Check if main exists
     elif git show-ref --verify --quiet refs/heads/main || git show-ref --verify --quiet refs/remotes/origin/main; then
       TARGET_BRANCH="main"
     # Check if master exists
     elif git show-ref --verify --quiet refs/heads/master || git show-ref --verify --quiet refs/remotes/origin/master; then
       TARGET_BRANCH="master"
     else
       echo "Error: Could not find dev, main, or master branch. Please specify target branch."
       exit 1
     fi
   fi

   echo "Target branch: $TARGET_BRANCH"

   # Verify target branch exists
   if ! git show-ref --verify --quiet refs/heads/$TARGET_BRANCH && ! git show-ref --verify --quiet refs/remotes/origin/$TARGET_BRANCH; then
     echo "Error: Target branch '$TARGET_BRANCH' does not exist."
     exit 1
   fi
   ```

   **Note:** The target branch can be provided as an optional argument. If not provided, the command will automatically detect and use `dev`, `main`, or `master` (in that order). For Evora repo, `dev` is the default main branch.

2. **Compare current branch against target branch**

   ```bash
   # Fetch latest changes from remote (optional but recommended)
   git fetch origin

   # Try local branch first, fallback to remote if local doesn't exist
   if git show-ref --verify --quiet refs/heads/$TARGET_BRANCH; then
     TARGET_REF=$TARGET_BRANCH
   elif git show-ref --verify --quiet refs/remotes/origin/$TARGET_BRANCH; then
     TARGET_REF=origin/$TARGET_BRANCH
   else
     echo "Error: Target branch '$TARGET_BRANCH' not found locally or remotely."
     exit 1
   fi

   # Get diff between current branch and target branch
   git diff $TARGET_REF...HEAD
   ```

   **Note:** Use `...` (three dots) to show changes between the common ancestor and HEAD, or `..` (two dots) to show changes between the branches directly. The command uses `$TARGET_BRANCH` variable set in step 1.

3. **Get list of changed files between branches**

   ```bash
   # List files changed between current branch and target branch
   git diff --name-only $TARGET_REF...HEAD

   # Get detailed file status
   git diff --name-status $TARGET_REF...HEAD

   # Show file changes with statistics
   git diff --stat $TARGET_REF...HEAD
   ```

4. **Get the current working directory diff** (uncommitted changes)

   ```bash
   # Uncommitted changes in working directory
   git diff HEAD

   # Staged changes
   git diff --cached

   # All changes (staged + unstaged)
   git diff HEAD
   git diff --cached
   ```

5. **Combine branch comparison with uncommitted changes**

   The review should analyze:
   - **Changes between current branch and target branch** (committed changes)
   - **Uncommitted changes** (if any)

   ```bash
   # Get all changes: branch diff + uncommitted
   git diff $TARGET_REF...HEAD > branch-changes.diff
   git diff HEAD >> branch-changes.diff
   git diff --cached >> branch-changes.diff

   # Or get combined diff (recommended approach)
   git diff $TARGET_REF...HEAD
   git diff HEAD
   git diff --cached
   ```

6. **Verify branch relationship**

   ```bash
   # Check if current branch is ahead/behind target branch
   git rev-list --left-right --count $TARGET_REF...HEAD

   # Show commit log differences
   git log $TARGET_REF..HEAD --oneline

   # Show summary of branch relationship
   AHEAD=$(git rev-list --left-right --count $TARGET_REF...HEAD | cut -f1)
   BEHIND=$(git rev-list --left-right --count $TARGET_REF...HEAD | cut -f2)
   echo "Branch is $AHEAD commits ahead and $BEHIND commits behind $TARGET_BRANCH"
   ```

7. **Understand the tech stack** (for validation):

   **Core:**
   - **Node.js**: v20.18.0 (specified in `.nvmrc`)
   - **TypeScript**: ^5.7.2
   - **pnpm**: 10.4.1 (package manager - enforced)
   - **Turborepo**: ^2.4.3 (monorepo tooling)

   **Frontend (apps/web):**
   - **Next.js**: 14.2.33 (App Router with RSC)
   - **React**: 18.3.1
   - **Tailwind CSS**: 3.4.1
   - **tRPC**: ^10.45.2
   - **TanStack React Query**: ^4.36.1
   - **Clerk Auth**: @clerk/nextjs 6.35.2
   - **TipTap**: ^3.15.1 (rich text editor)

   **Admin Panel (apps/admin):**
   - **React Router**: 7.6.1
   - **React**: 18.3.1
   - **tRPC**: 11.1.3
   - **TanStack React Query**: ^5.77.2
   - **Vite**: ^6.3.5

   **API Server (apps/api):**
   - **Hono**: ^4.7.2
   - **Socket.IO**: ^4.8.1
   - **tRPC**: integrated with Hono

   **Backend (apps/backend):**
   - **AWS Lambda** via Serverless Framework ^4.3.2
   - **Middy**: ^4.6.1 (Lambda middleware)
   - **AWS SDK**: Various @aws-sdk/* ^3.x packages

   **Database/Storage:**
   - **MongoDB**: via Mongoose ^8.3.2
   - **Redis**: via @evora/redis package
   - **OpenSearch**: via @evora/opensearch package

   **Validation:**
   - **Zod**: ^3.25.76 (prefer zod/v4 for new schemas)

   **Shared Packages (@evora/*):**
   - `@evora/db` - Mongoose models and database connection
   - `@evora/ui` - Shared React components (shadcn/ui + Radix UI)
   - `@evora/lib` - Shared business logic utilities
   - `@evora/clerk` - Clerk authentication utilities
   - `@evora/billing` - Stripe billing logic
   - `@evora/integrations` - Third-party integrations
   - `@evora/sqs` - AWS SQS utilities

   Check `package.json` files for exact versions

### Phase 2: Deep Dive Analysis (5 Agents)

Launch 5 separate deep dive agents, each with a specific focus area. Each agent should be invoked with the `@deepdive` agent and given the git diff (comparing current branch against target branch) along with their specific instructions.

**Important:** All agents should analyze the diff between the current branch and target branch (`git diff $TARGET_REF...HEAD`), plus any uncommitted changes. This ensures the review covers all changes that will be merged. The target branch is determined from the optional argument or defaults to main/master.

#### Agent 1: Tech Stack Validation (HIGHEST PRIORITY)

**Focus:** Verify code is valid for the Evora monorepo tech stack

**Instructions for Agent 1:**

```
Analyze the git diff for invalid code based on the Evora tech stack:

1. **TypeScript/JavaScript Syntax**
   - Check for valid TypeScript syntax (no invalid type annotations, correct import/export syntax)
   - Verify Node.js API usage is compatible with Node.js v20.18.0
   - Check for deprecated APIs or features not available in Node.js 20
   - Verify ES module syntax (type: "module" in package.json for all apps)
   - Ensure separate type imports from value imports (no combined imports)

2. **React 18.3.1 Compatibility**
   - Check for deprecated React APIs or patterns
   - Verify hooks usage is correct for React 18
   - Check for invalid JSX syntax
   - Verify component patterns match React 18 conventions
   - Check for proper "use client" directive usage in Next.js App Router

3. **Next.js 14.2.33 App Router Patterns**
   - Verify Server Components vs Client Components distinction
   - Check proper use of "use client" directives
   - Verify correct usage of Next.js 14 APIs (auth(), etc.)
   - Check middleware patterns for Clerk integration
   - Verify RSC-compatible data fetching patterns

4. **Hono API Server Patterns (apps/api)**
   - Verify Hono route handler patterns
   - Check proper middleware usage
   - Verify tRPC integration is correct
   - Check Socket.IO event handling patterns

5. **AWS Lambda Patterns (apps/backend)**
   - Verify Middy middleware composition
   - Check Lambda handler signatures
   - Verify SQS message handling patterns
   - Check proper error handling in Lambda context

6. **Type Safety**
   - Verify TypeScript types are correctly used
   - Check for `any` types that should be properly typed
   - Verify type imports/exports are separated from value imports
   - Check for missing type definitions
   - Verify Mongoose model types (IDocument types, .lean() usage)

7. **Import Patterns (CRITICAL)**
   - Check imports from @evora/db are direct file imports, NOT barrel imports
     ✅ CORRECT: import { workspaceModel } from "@evora/db/models/workspace.model"
     ❌ WRONG: import { workspaceModel } from "@evora/db"
   - Verify all workspace package imports follow direct import pattern
   - Check for circular dependencies between packages

8. **tRPC Patterns**
   - Verify tRPC procedure hierarchy (publicProcedure, protectedProcedure, workspaceProcedure, agencyProcedure)
   - Check for proper input/output validation with Zod schemas
   - Verify React Query integration patterns

9. **Mongoose Patterns**
   - Verify proper .lean() usage for read-only queries
   - Check for proper model registration before .populate()
   - Verify schema definitions use getCachedModel utility
   - Check InferSchemaType usage for type inference

10. **Zod Schema Patterns**
    - Prefer zod/v4 for new schemas when possible
    - Verify proper schema validation in tRPC procedures
    - Check for consistent error handling

11. **Notification Patterns**
    - Verify IntegrationsHelper.fetchAdaptersAndLogger() usage for notifications
    - Check for proper null checks before creating notification instances
    - Never import initializeAdapters directly

12. **Package Dependencies**
    - Check for imports from packages not in package.json
    - Verify workspace:^ dependencies are correctly referenced
    - Check for version compatibility between shared packages

Provide a detailed report with:
- File paths and line numbers of invalid code
- Specific error description (what's wrong and why)
- Expected vs actual behavior
- Priority level (CRITICAL for build-breaking issues)
```

#### Agent 2: Security Vulnerability Scanner

**Focus:** Security issues and vulnerabilities

**Instructions for Agent 2:**

```
Analyze the git diff for security vulnerabilities:

1. **Injection Vulnerabilities**
   - NoSQL injection in MongoDB queries (especially with user input in $where, $regex)
   - Command injection (exec, spawn, etc.)
   - Path traversal vulnerabilities in file operations
   - XSS vulnerabilities in React components (especially with dangerouslySetInnerHTML)

2. **Authentication & Authorization**
   - Missing Clerk authentication checks in tRPC procedures
   - Incorrect procedure type usage (publicProcedure vs protectedProcedure vs workspaceProcedure)
   - Authorization bypasses in workspace/agency-scoped operations
   - Missing permission checks for sensitive operations

3. **Data Handling**
   - Unsafe deserialization
   - Insecure file operations (S3, local filesystem)
   - Missing input validation in Zod schemas
   - Sensitive data exposure (secrets, tokens, passwords, API keys)
   - PII leakage in logs or error messages

4. **Dependencies**
   - Known vulnerable packages in workspace dependencies
   - Insecure dependency versions
   - Missing security patches

5. **API Security**
   - Missing CORS configuration in Hono routes
   - Insecure tRPC endpoints (wrong procedure type)
   - Missing rate limiting
   - Insecure WebSocket connections in Socket.IO
   - Webhook signature verification missing (PandaDoc, Stripe, etc.)

6. **AWS Lambda Security**
   - Insecure IAM role configurations
   - Missing SQS message validation
   - Improper error handling exposing internal details
   - Missing timeout handling

7. **Database Security**
   - MongoDB injection via unsanitized user input
   - Missing field-level access control
   - Overly permissive queries
   - Sensitive data stored without encryption

8. **Third-Party Integration Security**
   - Missing webhook signature verification
   - Exposed API keys or secrets
   - Insecure external API calls
   - Missing SSL/TLS validation

Provide a detailed report with:
- Vulnerability type and severity (CRITICAL, HIGH, MEDIUM, LOW)
- File paths and line numbers
- Attack vector description
- Recommended fix approach
```

#### Agent 3: Code Quality & Clean Code

**Focus:** Dirty code, code smells, and quality issues

**Instructions for Agent 3:**

```
Analyze the git diff for code quality issues:

1. **Code Smells**
   - Long functions/methods (>50 lines)
   - High cyclomatic complexity
   - Duplicate code across packages
   - Dead code
   - Magic numbers/strings

2. **Best Practices**
   - Missing error handling in async operations
   - Inconsistent naming conventions
   - Poor separation of concerns
   - Tight coupling between packages
   - Missing comments for workarounds, important decisions, tricks, and corner cases only
   - Over-commenting (comments should be minimal per CLAUDE.md)

3. **Performance Issues**
   - Inefficient MongoDB queries (missing indexes, N+1 queries)
   - Memory leaks (event listeners, subscriptions, Socket.IO)
   - Unnecessary re-renders in React components
   - Missing memoization where needed (useMemo, useCallback)
   - Missing .lean() for read-only Mongoose queries
   - Inefficient OpenSearch queries

4. **Maintainability**
   - Hard-coded values that should be in env or config
   - Missing type definitions
   - Inconsistent code style
   - Poor file organization (not following feature-based structure)
   - Barrel imports instead of direct imports

5. **React-Specific (Next.js App Router)**
   - Missing key props in lists
   - Direct state mutations
   - Missing cleanup in useEffect
   - Unnecessary useState/useEffect
   - Prop drilling issues (should use context providers)
   - Missing "use client" directive for client components
   - Server component using client-only features

6. **tRPC-Specific**
   - Overly complex procedure logic (should be split)
   - Missing input validation schemas
   - Inconsistent error handling
   - Missing proper procedure type selection

7. **Class Member Ordering**
   - Class members should be ordered: public → protected → private
   - Public API should be visible first for readability

8. **Import Organization**
   - Imports should follow: Built-ins → React/Next → Third-party → @evora/* → Types → Relative
   - Type imports must be separate from value imports
   - Use direct imports, not barrel imports for @evora packages

9. **Lambda/Worker Specific**
   - Missing proper logging with context (child loggers)
   - Missing retry logic for transient failures
   - Missing graceful error handling

Provide a detailed report with:
- Issue type and severity
- File paths and line numbers
- Description of the problem
- Impact on maintainability/performance
- Recommended refactoring approach
```

#### Agent 4: Implementation Correctness

**Focus:** Verify code implements requirements correctly

**Instructions for Agent 4:**

```
Analyze the git diff for implementation correctness:

1. **Logic Errors**
   - Incorrect conditional logic
   - Wrong variable usage
   - Off-by-one errors
   - Race conditions
   - Missing null/undefined checks

2. **Functional Requirements**
   - Missing features from requirements
   - Incorrect feature implementation
   - Edge cases not handled
   - Missing validation

3. **Integration Issues**
   - Incorrect API usage
   - Wrong data format handling
   - Missing error handling for external calls
   - Incorrect state management

4. **Type Errors**
   - Type mismatches
   - Missing type guards
   - Incorrect type assertions
   - Unsafe type operations

5. **Testing Gaps**
   - Missing unit tests
   - Missing integration tests
   - Tests don't cover edge cases
   - Tests are incorrect

Provide a detailed report with:
- Issue description
- File paths and line numbers
- Expected vs actual behavior
- Steps to reproduce (if applicable)
- Recommended fix
```

#### Agent 5: Architecture & Design Patterns

**Focus:** Architectural issues and design pattern violations

**Instructions for Agent 5:**

```
Analyze the git diff for architectural and design issues:

1. **Monorepo Architecture Violations**
   - Violation of package boundaries (@evora/* packages)
   - Incorrect layer separation (apps vs packages)
   - Missing abstractions in shared packages
   - Tight coupling between apps
   - Circular dependencies between packages

2. **App-Specific Structure**
   - **apps/web**: Feature-based component organization, proper use of App Router patterns
   - **apps/api**: Hono route organization, proper middleware composition
   - **apps/backend**: Lambda handler structure, proper lib/ organization
   - **apps/admin**: React Router route organization, component structure

3. **Design Patterns**
   - Service/Factory pattern for external integrations (UpworkApiFactory, SqsPublisherFactory)
   - Incorrect pattern usage
   - Missing patterns where needed
   - Anti-patterns

4. **tRPC Router Design**
   - Router organization in /trpc/routers/
   - Procedure hierarchy (public → protected → workspace → agency)
   - Input/output schema design
   - Error handling consistency

5. **Database Model Design**
   - Mongoose model organization in @evora/db/models/
   - Schema design (InferSchemaType, getCachedModel)
   - Index definitions
   - Population patterns

6. **State Management**
   - React Context provider patterns in apps/web/providers/
   - TanStack React Query integration with tRPC
   - WebSocket state management with Socket.IO
   - No Redux/Zustand (relies on context + React Query)

7. **Event-Driven Architecture (Backend)**
   - SQS queue patterns
   - EventBridge scheduler patterns
   - Lambda handler composition with Middy
   - Error handling and retry logic

8. **Integration Patterns**
   - Third-party integration organization in @evora/integrations
   - Notification adapter patterns (ImmutableNotifications, GeneralNotifications)
   - Webhook handler patterns

9. **API Design**
   - tRPC procedure naming conventions
   - Hono REST endpoint design
   - Consistent error response formats
   - Proper HTTP status codes

Provide a detailed report with:
- Architectural issue description
- File paths and affected areas
- Impact on system design
- Recommended architectural changes
```

### Phase 3: Consolidate Findings

After all 5 deep dive agents complete their analysis:

1. **Collect all findings** from each agent
2. **Prioritize issues**:
   - CRITICAL: Tech stack invalid code (build-breaking)
   - HIGH: Security vulnerabilities, critical logic errors
   - MEDIUM: Code quality issues, architectural problems
   - LOW: Minor code smells, style issues

3. **Group by file** to understand impact per file
4. **Create a master report** summarizing all findings

### Phase 4: Deepcode Fixes (5 Agents)

Launch 5 deepcode agents to fix the issues found. Each agent should be invoked with the `@deepcode` agent.

#### Deepcode Agent 1: Fix Tech Stack Invalid Code

**Priority:** CRITICAL - Fix first

**Instructions:**

```
Fix all invalid code based on tech stack issues identified by Agent 1.

Focus on:
1. Fixing TypeScript syntax errors
2. Updating deprecated Node.js 20 APIs
3. Fixing React 18 compatibility issues
4. Correcting Next.js 14 App Router patterns
5. Fixing Hono API patterns
6. Correcting tRPC procedure usage
7. Fixing Mongoose model patterns (.lean(), populate registration)
8. Correcting import patterns (direct imports, not barrel imports)
9. Separating type imports from value imports
10. Fixing Zod schema issues

After fixes, verify:
- pnpm typecheck passes without errors
- TypeScript types are correct
- No deprecated API usage
- Import patterns follow project conventions
```

#### Deepcode Agent 2: Fix Security Vulnerabilities

**Priority:** HIGH

**Instructions:**

```
Fix all security vulnerabilities identified by Agent 2.

Focus on:
1. Adding Zod input validation to tRPC procedures
2. Fixing NoSQL injection vulnerabilities in MongoDB queries
3. Securing authentication with proper Clerk procedure types
4. Fixing insecure data handling and PII exposure
5. Adding webhook signature verification
6. Securing Lambda handlers with proper validation
7. Fixing XSS vulnerabilities in React components
8. Adding proper CORS configuration in Hono routes

After fixes, verify:
- Security vulnerabilities are addressed
- No sensitive data exposure in logs or errors
- Proper authentication/authorization via Clerk
- Webhook signatures are verified
```

#### Deepcode Agent 3: Refactor Dirty Code

**Priority:** MEDIUM

**Instructions:**

```
Refactor code quality issues identified by Agent 3.

Focus on:
1. Extracting long functions
2. Reducing complexity
3. Removing duplicate code
4. Adding error handling
5. Improving React component structure
6. Adding missing comments

After fixes, verify:
- Code follows best practices
- No code smells remain
- Performance optimizations applied
```

#### Deepcode Agent 4: Fix Implementation Errors

**Priority:** HIGH

**Instructions:**

```
Fix implementation correctness issues identified by Agent 4.

Focus on:
1. Fixing logic errors
2. Adding missing features
3. Handling edge cases
4. Fixing type errors
5. Adding missing tests

After fixes, verify:
- Logic is correct
- Edge cases handled
- Tests pass
```

#### Deepcode Agent 5: Fix Architectural Issues

**Priority:** MEDIUM

**Instructions:**

```
Fix architectural issues identified by Agent 5.

Focus on:
1. Correcting architecture violations
2. Applying proper design patterns
3. Fixing API design issues
4. Improving state management
5. Following project patterns

After fixes, verify:
- Architecture is sound
- Patterns are correctly applied
- Code follows project structure
```

### Phase 5: Verification

After all fixes are complete:

1. **Run TypeScript compilation check** (CRITICAL - must pass before push)

   ```bash
   # Check all packages
   pnpm typecheck

   # Or check specific packages you modified
   pnpm typecheck --filter @evora/web
   pnpm typecheck --filter @evora/api
   pnpm typecheck --filter @evora/admin
   pnpm typecheck --filter @evora/backend
   ```

2. **Run linting**

   ```bash
   pnpm lint
   ```

3. **Run formatting check**

   ```bash
   pnpm format
   ```

4. **Build check** (optional but recommended)

   ```bash
   pnpm build
   ```

5. **Verify git diff** shows only intended changes

   ```bash
   git diff HEAD
   ```

6. **Create summary report**:
   - Issues found by each agent
   - Issues fixed by each agent
   - Remaining issues (if any)
   - Verification results (typecheck must pass)

## Workflow Summary

1. ✅ Accept optional target branch argument (defaults to dev/main/master if not provided)
2. ✅ Determine current branch and target branch (from argument or auto-detect dev/main/master)
3. ✅ Get git diff comparing current branch against target branch (`git diff $TARGET_REF...HEAD`)
4. ✅ Include uncommitted changes in analysis (`git diff HEAD`, `git diff --cached`)
5. ✅ Launch 5 deep dive agents (parallel analysis) with branch diff
6. ✅ Consolidate findings and prioritize
7. ✅ Launch 5 deepcode agents (sequential fixes, priority order)
8. ✅ Verify fixes with build/lint/test
9. ✅ Report summary

## Notes

- **Tech stack validation is HIGHEST PRIORITY** - invalid code must be fixed first
- **Target branch argument**: The command accepts an optional target branch name as the first argument. If not provided, it automatically detects and uses `dev`, `main`, or `master` (in that order - `dev` is the default for Evora repo)
- Each deep dive agent should work independently and provide comprehensive analysis
- Deepcode agents should fix issues in priority order
- All fixes should maintain existing functionality
- If an agent finds no issues in their domain, they should report "No issues found"
- If fixes introduce new issues, they should be caught in verification phase
- The target branch is validated to ensure it exists (locally or remotely) before proceeding with the review