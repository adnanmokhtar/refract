import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { HttpClient } from '@angular/common/http';
import { interval, switchMap } from 'rxjs';

@Component({
  selector: 'harbor-basket-button',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<a [href]="shopUrl()" class="harbor-basket">Basket ({{ count() }})</a>`,
})
export class BasketButtonComponent {
  private readonly http = inject(HttpClient);
  private readonly destroyRef = inject(DestroyRef);
  readonly shopUrl = input('https://harbor.example/basket');
  readonly count = signal(0);

  ngOnInit() {
    interval(60_000)
      .pipe(
        switchMap(() => this.http.get<{ count: number }>('https://harbor.example/api/basket/count', { withCredentials: true })),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((res) => this.count.set(res.count));
  }
}
