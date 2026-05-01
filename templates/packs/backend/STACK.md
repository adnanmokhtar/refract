# Backend pack — stack assumption

This pack's commands, agents, skills, rules, ai-patterns, and examples assume:

- **Hexagonal / clean-architecture layering** (domain framework-free; application uses ports; infrastructure is the adapter)
- **Dependency injection** (NestJS `@Injectable`, Spring `@Component`, .NET DI container, Python FastAPI Depends, etc.)
- **Repository pattern** mediating data access
- **DTO + validation** at boundaries (class-validator / Zod / Pydantic / Bean Validation)
- **A canonical HTTP client** for outbound calls
- **Structured logger** (not `console.log` / `print`)

## Inline examples in this pack

Wherever this pack's files show concrete syntax (decorators, base classes, framework calls), the syntax is **NestJS + TypeScript** for illustration. Substitute your stack's equivalents:

| NestJS + TS (illustrated) | Spring Boot (Java/Kotlin) | FastAPI (Python) | Laravel (PHP) | Substitution source |
|---|---|---|---|---|
| `@Injectable()` | `@Component` / `@Service` | `Depends(...)` | `App\Container` binding | DI marker |
| `@Controller('foo')` | `@RestController` | `APIRouter()` | `Route::resource` | HTTP router |
| `@Get(':id')` + DTO | `@GetMapping("/:id")` | `@router.get("/{id}")` | `Route::get` | endpoint declaration |
| `class FooDto` (class-validator) | record + Bean Validation | `class FooSchema(BaseModel)` | Form Request | DTO + validation |
| `Repository<T>` | `JpaRepository<T, ID>` | SQLAlchemy session | Eloquent model | repository pattern |
| `Result<T, E>` envelope | sealed exceptions | `Either[T, E]` (returns) | exceptions | error contract |
| `HttpModule` / Axios | `RestTemplate` / `WebClient` | `httpx.AsyncClient` | Guzzle | outbound HTTP |
| `Logger` (NestJS) | `Logger` (slf4j) | `logging.getLogger` | `Log::` | structured logger |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — single source of truth for actual base classes / decorators / utilities.
- The project's `ai/migration/_v2-anchors.md` — layering rules, repository pattern, error envelope, transaction boundaries.
- The validator script `check_v2_structure` — stack-conditional fingerprint set keyed by `PROJECT_KIND` (`backend-nest`, `backend-laravel`, `backend-python`, `api-other`).
