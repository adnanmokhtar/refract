import { ChangeDetectionStrategy, Component, input, signal } from '@angular/core';

type Recipe = { id: string; title: string; minutes: number };

@Component({
  selector: 'harbor-recipe-list',
  templateUrl: './recipe-list.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RecipeListComponent {
  readonly initial = input<Recipe[]>([]);
  readonly recipes = signal<Recipe[]>([]);
  readonly saved = signal<Record<string, string>>({});

  ngOnInit() {
    this.recipes.set(this.initial());
  }

  sortByTime() {
    this.recipes.update((list) => [...list].sort((a, b) => a.minutes - b.minutes));
  }

  note(id: string, text: string) {
    this.saved.update((s) => ({ ...s, [id]: text }));
  }
}
