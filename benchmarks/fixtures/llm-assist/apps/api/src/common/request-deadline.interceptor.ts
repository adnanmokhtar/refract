import { CallHandler, ExecutionContext, Injectable, NestInterceptor, RequestTimeoutException } from '@nestjs/common';
import { Observable, TimeoutError, catchError, throwError, timeout } from 'rxjs';
import type { AuthedRequest } from './authed-request';

const REQUEST_BUDGET_MS = 90_000;

/**
 * One deadline per request. The signal is handed to every outbound call (the LLM gateway passes it
 * to fetch), so a call still running at the deadline is aborted, not left to finish and bill.
 */
@Injectable()
export class RequestDeadlineInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    req.deadline = AbortSignal.timeout(REQUEST_BUDGET_MS);
    return next.handle().pipe(
      timeout(REQUEST_BUDGET_MS),
      catchError((err) =>
        throwError(() => (err instanceof TimeoutError ? new RequestTimeoutException('Request deadline exceeded') : err)),
      ),
    );
  }
}
