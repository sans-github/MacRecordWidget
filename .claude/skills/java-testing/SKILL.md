---
name: java-testing
description: Java testing with JUnit 5 -- unit and integration tests, naming conventions, parameterized tests, assertions, and mocking with Mockito. Use when writing or reviewing any Java tests.
metadata:
  source: https://skills.sh/github/awesome-copilot/java-junit
---

# Java Testing Best Practices

Covers unit and integration testing with JUnit 5: test structure, naming, data-driven tests, assertions, mocking, and test organization.

## When to use

- Writing unit or integration tests for a Java application
- Reviewing test quality or coverage strategy
- Establishing testing conventions for a team

## Key concepts

**Test structure** -- follow Arrange-Act-Assert (AAA). One behavior per test. Tests must be independent and idempotent -- order of execution should never matter.

**Naming** -- test classes use a `Test` suffix (`OrderServiceTest`). Test methods follow `methodName_should_expectedBehavior_when_scenario`. Use `@DisplayName` for human-readable output.

**Parameterized tests** -- default to `@ParameterizedTest` for all new tests. If a test has more than one scenario or input variant, it must be parameterized. Use `@Test` only when there is genuinely one and only one case to cover.

**Assertions** -- prefer AssertJ (`assertThat(...)`) for fluency. Use `assertAll` to group related assertions so all failures surface in one run. Use `assertThrows` for expected exceptions.

**Mocking** -- use Mockito with `@Mock` and `@InjectMocks`. Mock dependencies at boundaries; avoid mocking what you own. Prefer interfaces to enable clean substitution.

**Organization** -- group by feature using packages. Use `@Tag` to separate fast and slow tests. Use `@Nested` to cluster related scenarios within a class. Use `@Disabled` with a reason, never silently.

## Code Style

Test code is subject to the same Checkstyle rules as production code. `mvn verify` will fail on violations in `src/test/java`. See `java-springboot` for the Checkstyle configuration.

## Resources

- Load `junit-reference.md` when writing or reviewing tests -- it covers project setup, naming, lifecycle hooks, parameterized test sources, assertions, mocking patterns, and organization annotations.
- Load `test-checklist.md` before declaring any test code merge-ready. Items that genuinely do not apply must be noted as out of scope, not silently skipped. EM verifies the checklist was run during PR approval.
