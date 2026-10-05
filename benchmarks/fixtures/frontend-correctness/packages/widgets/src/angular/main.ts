import { createApplication } from '@angular/platform-browser';
import { createCustomElement } from '@angular/elements';
import { provideHttpClient, withFetch } from '@angular/common/http';
import { provideZonelessChangeDetection } from '@angular/core';
import { BasketButtonComponent } from './basket-button.component';
import { RecipeListComponent } from './recipe-list.component';

const app = await createApplication({ providers: [provideZonelessChangeDetection(), provideHttpClient(withFetch())] });
customElements.define('harbor-basket-button', createCustomElement(BasketButtonComponent, { injector: app.injector }));
customElements.define('harbor-recipe-list', createCustomElement(RecipeListComponent, { injector: app.injector }));
