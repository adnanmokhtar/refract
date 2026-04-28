# Spring Boot (Java / Kotlin) reference

## Structure

```
src/main/java/com/company/app/
├── Application.java            # @SpringBootApplication
├── config/                     # @Configuration classes
├── modules/
│   └── <name>/
│       ├── api/                # @RestController
│       ├── application/        # @Service, use cases
│       ├── domain/             # entities, value objects, domain errors
│       ├── infrastructure/     # repositories, JPA entities, adapters
│       └── dto/                # request / response DTOs
└── common/                     # shared exceptions, interceptors, utils
```

## Rules

### API layer
- `@RestController` thin — no business logic.
- `@Valid` on every request body.
- `@ControllerAdvice` for global exception mapping (domain error → HTTP status).
- `ResponseEntity<T>` for explicit status codes.
- Use records (Java 17+) or data classes (Kotlin) for DTOs.

### Service layer
- `@Service` for business logic.
- Constructor injection only (no `@Autowired` on fields).
- Transactional boundaries declared with `@Transactional` at service layer.
- Avoid `@Transactional` on public methods that call other `@Transactional` methods of the same bean (proxy bypass).

### Data layer
- Spring Data JPA for standard CRUD.
- Use projections / `@Query` for custom reads — don't fetch entities you won't fully use.
- Avoid `LAZY` fetch + `@Transactional` boundaries mismatch (classic N+1).
- `@EntityGraph` or `JOIN FETCH` to eager-load explicitly.
- Never expose JPA entities from controllers — always map to DTO.

### Validation
- Bean Validation (`jakarta.validation`) — `@NotNull`, `@Size`, `@Pattern`, custom validators.

### Security
- Spring Security 6+.
- JWT via `spring-security-oauth2-resource-server`.
- CSRF disabled for stateless JSON APIs (kept for form-based).
- Method-level: `@PreAuthorize("hasRole('ADMIN')")`.

### Testing
- `@SpringBootTest` — integration.
- `@WebMvcTest` — controller only.
- `@DataJpaTest` — repository only.
- Testcontainers for real DB / Kafka / Redis in integration tests.

## Observability

- Actuator (`/actuator/health`, `/actuator/metrics`, `/actuator/prometheus`).
- Micrometer for metrics.
- OpenTelemetry agent for traces.

## Anti-patterns

- Field injection (`@Autowired` private field).
- Returning JPA entities from controllers.
- `@Transactional` wrapping an entire service method including external API calls.
- `findAll()` on large tables.
- `Optional` misuse (don't chain 5 `.map().orElse()` — extract to a method).
- `@ComponentScan` that scans outside your package (slow + surprising).
