import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'lumen-newsletter',
  imports: [FormsModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <form (ngSubmit)="subscribe()">
      <label for="lumen-nl-email">Email</label>
      <input id="lumen-nl-email" name="email" type="email" autocomplete="email" required [(ngModel)]="email" />
      <button type="submit" [disabled]="sending()">Subscribe</button>
      <p role="status">{{ message() }}</p>
    </form>
  `,
})
export class NewsletterComponent {
  private readonly http = inject(HttpClient);
  email = '';
  readonly sending = signal(false);
  readonly message = signal('');

  subscribe() {
    this.sending.set(true);
    this.http.post('/api/newsletter', { email: this.email }).subscribe({
      next: () => this.message.set('Thanks — check your inbox.'),
      error: () => this.message.set('That did not work. Try again.'),
      complete: () => this.sending.set(false),
    });
  }
}
