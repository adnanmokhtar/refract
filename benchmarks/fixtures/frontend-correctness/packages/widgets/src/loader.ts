// Loads the Angular widgets bundle on demand when a partner page contains one of our custom elements.
const TAGS = ['harbor-basket-button', 'harbor-recipe-list'];

if (TAGS.some((tag) => document.querySelector(tag))) {
  void import('./angular/main');
}
