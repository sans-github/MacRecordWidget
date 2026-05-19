# Test Review Checklist

## Factories

- [ ] Test objects built via `{Entity}Factory`, not inline constructors
- [ ] Factories live in `src/test/java/.../factory/`
- [ ] `build()` used in unit tests (no DB), `persist()` used in ITs
- [ ] Only relevant fields overridden per test -- defaults handle the rest

## Structure

- [ ] Tests follow Arrange-Act-Assert (AAA) pattern
- [ ] Each test covers exactly one behavior
- [ ] Tests are independent -- no shared mutable state, no ordering dependencies

## Naming

- [ ] Unit test class has `Test` suffix (e.g. `OrderServiceTest`)
- [ ] Integration test class has `IT` suffix (e.g. `OrderControllerIT`)
- [ ] Test methods follow `methodName_should_expectedBehavior_when_scenario`
- [ ] `@DisplayName` used for human-readable output

## Parameterization

- [ ] All multi-scenario tests use `@ParameterizedTest`
- [ ] No duplicate test methods that differ only in input values
- [ ] Appropriate source annotation chosen (`@CsvSource`, `@MethodSource`, etc.)

## Assertions

- [ ] AssertJ used for fluency (`assertThat(...)`)
- [ ] `assertAll` used when checking multiple fields
- [ ] Exception cases use `assertThrows` or `assertDoesNotThrow`
- [ ] Assertion messages are descriptive on failure

## Mocking (unit tests only)

- [ ] Only external dependencies are mocked (repositories, HTTP clients)
- [ ] No mocking of classes you own
- [ ] `@Mock` and `@InjectMocks` used via `@ExtendWith(MockitoExtension.class)`

## Integration Tests

- [ ] Class name ends in `IT`
- [ ] `@SpringBootTest` and `@ActiveProfiles("test")` present
- [ ] `@Tag("integration")` applied
- [ ] No `@Mock` or `@MockBean` -- real dependencies only
- [ ] Testcontainers used for DB (not an in-memory substitute)
- [ ] `@DynamicPropertySource` wires container config to Spring context
- [ ] `@BeforeAll` / `@AfterAll` manage container lifecycle

## Organization

- [ ] Tests grouped by feature in packages
- [ ] Related scenarios clustered with `@Nested`
- [ ] `@Tag` applied (`"fast"` or `"integration"`)
- [ ] Any `@Disabled` test includes a reason

## Coverage

- [ ] Happy path tested
- [ ] Validation and error cases tested
- [ ] Boundary values tested (nulls, empty, min/max)
- [ ] 100% line coverage enforced -- `mvn verify` fails below this threshold
