# JUnit 5 Reference

## Test Factories

Use factories to build test objects. Never construct domain objects inline across multiple tests -- a single required field change will break them all.

### Location and naming

```
src/test/java/.../factory/
├── UserFactory.java
├── OrderFactory.java
```

### Pattern

Factories use the builder pattern with sensible defaults. Tests override only what is relevant to their scenario.

```java
public class UserFactory {

    public static User build() {
        return User.builder()
            .id(UUID.randomUUID())
            .email("user@example.com")
            .name("Test User")
            .createdAt(Instant.now())
            .build();
    }

    public static User build(Consumer<User.UserBuilder> overrides) {
        User.UserBuilder builder = User.builder()
            .id(UUID.randomUUID())
            .email("user@example.com")
            .name("Test User")
            .createdAt(Instant.now());
        overrides.accept(builder);
        return builder.build();
    }

    public static User persist(UserRepository repository) {
        return repository.save(build());
    }

    public static User persist(UserRepository repository, Consumer<User.UserBuilder> overrides) {
        return repository.save(build(overrides));
    }
}
```

### Usage

```java
// Unit test -- in-memory, only override what matters
User user = UserFactory.build(u -> u.email("custom@example.com"));

// Integration test -- persisted to real DB
User user = UserFactory.persist(userRepository, u -> u.name("Jane"));
```

### Rules

- `build()` never touches the database -- safe for unit tests
- `persist()` requires a real repository -- use in ITs only
- Defaults must be valid enough to pass bean validation
- One factory per entity, in the `factory` package

---

## Project Setup

- Place tests in `src/test/java` mirroring the main source package structure.
- Add the `org.junit.jupiter:junit-jupiter` aggregator -- it includes `junit-jupiter-api`, `junit-jupiter-engine`, and `junit-jupiter-params` transitively.
- Run tests with `mvn test`.

---

## Test Structure

### Naming

- Test class: `{ClassName}Test` (e.g., `OrderServiceTest` for `OrderService`).
- Test method: `methodName_should_expectedBehavior_when_scenario`.
- Use `@DisplayName` for human-readable descriptions in test reports.

### Pattern

Follow Arrange-Act-Assert (AAA):

```java
@Test
@DisplayName("should apply discount when order exceeds threshold")
void applyDiscount_should_reduceTotal_when_orderExceedsThreshold() {
    // Arrange
    Order order = new Order(150.00);

    // Act
    double total = pricingService.applyDiscount(order);

    // Assert
    assertThat(total).isEqualTo(135.00);
}
```

### Lifecycle hooks

| Annotation | Scope | Use for |
|---|---|---|
| `@BeforeEach` | Per test | Reset state, build fixtures |
| `@AfterEach` | Per test | Cleanup, close resources |
| `@BeforeAll` | Per class (static) | Expensive one-time setup (DB, container) |
| `@AfterAll` | Per class (static) | One-time teardown |

---

## Parameterized Tests

Prefer `@ParameterizedTest` by default. If a test covers more than one scenario or input variant, it must be parameterized. Use `@Test` only when there is genuinely a single case with no variants.

```java
@ParameterizedTest
@ValueSource(strings = {"", " ", "\t"})
void isBlank_should_returnTrue_when_inputIsBlank(String input) {
    assertThat(StringUtils.isBlank(input)).isTrue();
}
```

| Source | When to use |
|---|---|
| `@ValueSource` | Simple literals (strings, ints, booleans) |
| `@CsvSource` | Inline input/expected pairs |
| `@CsvFileSource` | CSV file from classpath (large datasets) |
| `@MethodSource` | Factory method returning `Stream<Arguments>` |
| `@EnumSource` | All or subset of enum constants |

---

## Assertions

Prefer AssertJ for fluency and readable failure messages:

```java
// AssertJ (preferred)
assertThat(result).isEqualTo(expected);
assertThat(list).hasSize(3).contains("item");

// JUnit built-in
assertEquals(expected, actual, "failure message");
assertAll(
    () -> assertEquals(1, result.getId()),
    () -> assertEquals("John", result.getName())
);

// Exceptions
assertThrows(IllegalArgumentException.class, () -> service.process(null));
assertDoesNotThrow(() -> service.process(validInput));
```

Use `assertAll` when checking multiple fields -- all failures surface in one run instead of stopping at the first.

---

## Mocking with Mockito

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository repository;

    @InjectMocks
    private OrderService orderService;

    @Test
    void findById_should_returnOrder_when_exists() {
        given(repository.findById(1L)).willReturn(Optional.of(new Order(1L)));

        Order result = orderService.findById(1L);

        assertThat(result.getId()).isEqualTo(1L);
    }
}
```

- Mock at boundaries (repositories, HTTP clients, external services).
- Prefer interfaces to enable clean substitution.
- Use `given(...).willReturn(...)` (BDDMockito) for readability.

---

## Integration Tests

### Naming

- IT class: `{ClassName}IT` (e.g. `OrderControllerIT`). Maven Failsafe picks up `*IT.java` automatically and runs them in the `integration-test` phase, separate from unit tests.
- Test methods follow the same `methodName_should_expectedBehavior_when_scenario` convention.

### Spring Boot setup

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Tag("integration")
class OrderControllerIT {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void createOrder_should_return201_when_requestIsValid() throws Exception {
        mockMvc.perform(post("/api/v1/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"item\": \"book\"}"))
            .andExpect(status().isCreated());
    }
}
```

### Testcontainers (real database)

```java
@SpringBootTest
@ActiveProfiles("test")
@Tag("integration")
class OrderRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @BeforeAll
    static void beforeAll() {
        postgres.start();
    }

    @AfterAll
    static void afterAll() {
        postgres.stop();
    }
}
```

### No mocking in ITs

ITs exist to verify the system works with real dependencies. Do not use `@Mock`, `@MockBean`, or Mockito in IT classes. If you find yourself needing to mock something in an IT, it is a sign the test should be a unit test instead.

### Running ITs separately

```bash
mvn test                     # unit tests only (Test suffix)
mvn failsafe:integration-test # ITs only (IT suffix)
mvn verify                   # both + Checkstyle
```

---

## Test Organization

```java
@Tag("fast")
class UserServiceTest {

    @Nested
    @DisplayName("create user")
    class CreateUser {

        @Test
        void should_persistUser_when_emailIsUnique() { ... }

        @Test
        void should_throwException_when_emailIsDuplicate() { ... }
    }
}
```

| Annotation | Purpose |
|---|---|
| `@Tag("fast")` / `@Tag("integration")` | Categorize for selective test runs |
| `@Nested` | Group related scenarios in an inner class |
| `@TestMethodOrder` + `@Order` | Control execution order (use sparingly) |
| `@Disabled("reason")` | Skip temporarily -- always include a reason |
