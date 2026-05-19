---
name: java-springboot
description: Spring Boot project structure, dependency injection, configuration, REST layer, JPA, logging, testing, and security conventions. Use when building, reviewing, or making tech stack decisions for a Spring Boot application.
metadata: 
  source: https://skills.sh/github/awesome-copilot/java-springboot
---

# Spring Boot Best Practices

Your goal is to help me write high-quality Spring Boot applications by following established best practices.

## Project Setup & Structure

- **Build Tool:** Use Maven `pom.xml` for dependency management.
- **Starters:** Use Spring Boot starters (e.g., `spring-boot-starter-web`, `spring-boot-starter-data-jpa`) to simplify dependency management.
- **Package Structure:** Organize code by feature/domain (e.g., `com.example.app.order`, `com.example.app.user`) rather than by layer (e.g., `com.example.app.controller`, `com.example.app.service`).

## Dependency Injection & Components

- **Constructor Injection:** Always use constructor-based injection for required dependencies. This makes components easier to test and dependencies explicit.
- **Immutability:** Declare dependency fields as `private final`.
- **Component Stereotypes:** Use `@Component`, `@Service`, `@Repository`, and `@Controller`/`@RestController` annotations appropriately to define beans.

## Configuration

- **Externalized Configuration:** Use `application.properties` for configuration.
- **Type-Safe Properties:** Use `@ConfigurationProperties` to bind configuration to strongly-typed Java objects.
- **Profiles:** Use Spring Profiles (`application-dev.yml`, `application-prod.yml`) to manage environment-specific configurations.
- **Secrets Management:** Do not hardcode secrets. Use environment variables, or a dedicated secret management tool like HashiCorp Vault or AWS Secrets Manager.

## Web Layer (Controllers)

- **RESTful APIs:** Design clear and consistent RESTful endpoints.
- **DTOs (Data Transfer Objects):** Use DTOs to expose and consume data in the API layer. Do not expose JPA entities directly to the client.
- **Validation:** Use Java Bean Validation (JSR 380) with annotations (`@Valid`, `@NotNull`, `@Size`) on DTOs to validate request payloads.
- **Error Handling:** Implement a global exception handler using `@ControllerAdvice` and `@ExceptionHandler` to provide consistent error responses.

## Service Layer

- **Business Logic:** Encapsulate all business logic within `@Service` classes.
- **Statelessness:** Services should be stateless.
- **Transaction Management:** Use `@Transactional` on service methods to manage database transactions declaratively. Apply it at the most granular level necessary.

## Data Layer (Repositories)

- **Spring Data JPA:** Use Spring Data JPA repositories by extending `JpaRepository` or `CrudRepository` for standard database operations.
- **Custom Queries:** For complex queries, use `@Query` or the JPA Criteria API.
- **Projections:** Use DTO projections to fetch only the necessary data from the database.

## Database migrations

Use Flyway (preferred) or Liquibase. The migration tool owns all schema creation -- Hibernate must never create or modify tables.

### Maven dependencies

Add to `pom.xml`:

```xml
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
<!-- Pick one: -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-mysql</artifactId>
</dependency>
<!-- or -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-database-postgresql</artifactId>
</dependency>
```

### application.properties

Required in every environment (dev, test, prod):

```properties
spring.jpa.hibernate.ddl-auto=validate
spring.flyway.locations=filesystem:../db/schema,filesystem:../db/seeds/common,filesystem:../db/migrations
spring.flyway.sql-migration-prefix=
spring.flyway.sql-migration-separator=_
spring.flyway.baseline-on-migrate=true
spring.flyway.baseline-version=0
```

`filesystem:../db/...` -- Maven's working directory during `mvn spring-boot:run` is the module root (`src/backend/`), not the repo root. Paths must be relative to `src/backend/`, so `../db/schema` reaches `src/db/schema`. Using `src/db/...` is incorrect and causes Flyway to find no scripts silently, which then causes Hibernate to fail with "missing table" on startup.

`baseline-on-migrate` and `baseline-version` -- required when adding Flyway to an existing database that already has tables but no schema history table. Without them, Flyway refuses to run with "Found non-empty schema but no schema history table". Setting `baseline-version=0` ensures all schema files (version `01`+) are applied on first run.

In `application-dev.properties` (dev/staging only -- never prod):

```properties
spring.flyway.locations=filesystem:../db/schema,filesystem:../db/seeds/common,filesystem:../db/seeds/dev,filesystem:../db/migrations
```

Never use `ddl-auto=create`, `create-drop`, or `update`. If Hibernate reports a missing table on startup, the fix is to write a migration -- not to change `ddl-auto`.

Flyway uses the text before the first `_` as the version key (`01` from `01_users.sql`, `20240315143022` from `20240315143022_add_phone.sql`) and skips already-applied scripts.

### Startup sequence

1. Flyway applies any pending scripts (schema, seeds, migrations -- in locations order)
2. Hibernate validates the schema against entity mappings
3. Application starts

This happens automatically when the Flyway dependency is on the classpath.

### File ownership

The BE agent writes all schema files (`src/db/schema/`) and migration files (`src/db/migrations/`). The human only creates the database and user.

## Testing

- **Unit Tests:** Write unit tests for services and components using JUnit 5 and a mocking framework like Mockito.
- **Integration Tests:** Use `@SpringBootTest` for integration tests that load the Spring application context.
- **Test Slices:** Use test slice annotations like `@WebMvcTest` (for controllers) or `@DataJpaTest` (for repositories) to test specific parts of the application in isolation.
- **Testcontainers:** Consider using Testcontainers for reliable integration tests with real databases, message brokers, etc.

## Security

- **Spring Security:** Use Spring Security for authentication and authorization.
- **Password Encoding:** Always encode passwords using a strong hashing algorithm like BCrypt.
- **Input Sanitization:** Prevent SQL injection by using Spring Data JPA or parameterized queries. Prevent Cross-Site Scripting (XSS) by properly encoding output.

## API Documentation (SpringDoc OpenAPI)

- **Dependency:** Add `springdoc-openapi-starter-webmvc-ui` to `pom.xml`. Zero config needed for Spring Boot 3.x. Version must match the Spring Boot minor version: Spring Boot 3.2.x → `2.3.0`, Spring Boot 3.3.x → `2.5.0`, Spring Boot 3.4.x → `2.8.8`. Using a version newer than the Spring Boot version will cause a `NoClassDefFoundError` at startup.
- **Auto-generated endpoints:** `/v3/api-docs` (OpenAPI JSON), `/swagger-ui.html` (UI) -- no controller changes required.
- **Spring Security:** If the project uses Spring Security, permit the SpringDoc endpoints explicitly or they return `{"error":"Unauthorized"}`. Add to `authorizeHttpRequests` before `.anyRequest().authenticated()`:
  ```java
  .requestMatchers("/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs/**").permitAll()
  ```
- **Optional annotations:** `@Tag`, `@Operation`, `@ApiResponse`, `@Schema` enrich the spec with descriptions and examples but are not required.
- **Spec export:** After implementation, run `curl http://localhost:8080/v3/api-docs -o generated-docs/contracts/openapi.json` and commit with message `export openapi spec for <feature> #<issue>`.

## OTEL agent setup

The OTEL Java agent must be attached in every environment. See `be-logging` skill for why.

### Local dev

Set `JAVA_TOOL_OPTIONS` in your shell or `.env` before running the app:

```bash
export JAVA_TOOL_OPTIONS="-javaagent:/opt/otel/opentelemetry-javaagent.jar"
export OTEL_SERVICE_NAME=my-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_LOGS_EXPORTER=otlp
```

Or via Maven plugin in `pom.xml` so it applies to every `mvn spring-boot:run` without manual export:

```xml
<plugin>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-maven-plugin</artifactId>
  <configuration>
    <agents>
      <agent>${project.basedir}/../../infra/otel/opentelemetry-javaagent.jar</agent>
    </agents>
    <environmentVariables>
      <OTEL_SERVICE_NAME>my-service</OTEL_SERVICE_NAME>
      <OTEL_EXPORTER_OTLP_ENDPOINT>http://localhost:4317</OTEL_EXPORTER_OTLP_ENDPOINT>
      <OTEL_LOGS_EXPORTER>otlp</OTEL_LOGS_EXPORTER>
    </environmentVariables>
  </configuration>
</plugin>
```

Store the agent jar at a committed path (e.g. `infra/otel/opentelemetry-javaagent.jar`) so all developers use the same version without manual downloads.

### Docker

Copy the agent jar into the image and set `JAVA_TOOL_OPTIONS` so it is inherited by the JVM process automatically -- no `CMD` changes required:

```dockerfile
COPY infra/otel/opentelemetry-javaagent.jar /opt/otel/opentelemetry-javaagent.jar
ENV JAVA_TOOL_OPTIONS="-javaagent:/opt/otel/opentelemetry-javaagent.jar"
```

Pass OTEL config as environment variables at `docker run` time or via `docker-compose.yml`:

```yaml
environment:
  OTEL_SERVICE_NAME: my-service
  OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317
  OTEL_LOGS_EXPORTER: otlp
```

Do not hardcode `OTEL_EXPORTER_OTLP_ENDPOINT` in the image -- it differs between local, staging, and prod.

## Code Style

- **Ruleset:** Google Java Style Guide enforced via Checkstyle.
- **Maven phase:** Checkstyle is bound to the `verify` phase -- `mvn verify` will fail on violations. Run it locally before pushing.
- **CI gate:** A GitHub Actions workflow runs `mvn verify` on every PR and blocks merge on Checkstyle failure.
- **Config:** Use the official `google_checks.xml` from the Checkstyle distribution. Reference it in `pom.xml` via the `maven-checkstyle-plugin`:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
    <configuration>
        <configLocation>google_checks.xml</configLocation>
        <failsOnError>true</failsOnError>
        <consoleOutput>true</consoleOutput>
    </configuration>
    <executions>
        <execution>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <executions>
        <execution>
            <id>prepare-agent</id>
            <goals><goal>prepare-agent</goal></goals>
        </execution>
        <execution>
            <id>check</id>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit>
                                <counter>LINE</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>1.00</minimum>
                            </limit>
                        </limits>
                    </rule>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### Static analysis

Checkstyle with `google_checks.xml` is the only enforced linter. Stay within it; do not add rules beyond it.

**Always fix before committing:**
- Unused imports
- Unused local variables
- Unreachable code

**Do not enforce (subjective, hurts readability):**
- Cyclomatic complexity thresholds (forces artificial decomposition of readable code)
- Method or class line length limits (context-dependent)
- "Magic number" rules (inline literals like `401` or `3600` are often more readable than named constants)
- Naming length rules

The rule of thumb: if fixing the violation makes the code harder to read, the rule is not worth having.
