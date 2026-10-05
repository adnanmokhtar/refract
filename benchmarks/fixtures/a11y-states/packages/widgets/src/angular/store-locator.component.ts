import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { httpResource } from '@angular/common/http';

type Store = { id: string; name: string; city: string };

@Component({
  selector: 'lumen-store-locator',
  templateUrl: './store-locator.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class StoreLocatorComponent {
  readonly postcode = input<string>('');
  readonly stores = httpResource<Store[]>(() => `/api/stores?near=${encodeURIComponent(this.postcode())}`);
}
