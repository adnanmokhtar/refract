import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { httpResource } from '@angular/common/http';

type Summary = { average: number; count: number };

@Component({
  selector: 'lumen-review-summary',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (summary.hasValue()) {
      <p class="lumen-rating">
        <span aria-hidden="true">{{ stars() }}</span>
        <span class="lumen-sr-only">{{ summary.value().average }} out of 5</span>
        ({{ summary.value().count }})
      </p>
    } @else if (summary.error()) {
      <p role="status">Reviews unavailable</p>
    } @else {
      <p aria-busy="true">…</p>
    }
  `,
})
export class ReviewSummaryComponent {
  readonly sku = input.required<string>();
  readonly summary = httpResource<Summary>(() => `/api/products/${this.sku()}/reviews/summary`);
  readonly stars = computed(() => '★'.repeat(Math.round(this.summary.value()?.average ?? 0)));
}
