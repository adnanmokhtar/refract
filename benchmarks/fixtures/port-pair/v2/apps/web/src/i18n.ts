import i18next from 'i18next';
import { initReactI18next } from 'react-i18next';
import arOrders from './locales/ar/orders.json';
import arTickets from './locales/ar/tickets.json';
import enOrders from './locales/en/orders.json';
import enTickets from './locales/en/tickets.json';

// i18next ≥ 21 picks plural keys through Intl.PluralRules: Arabic needs _zero, _one, _two,
// _few, _many and _other.
void i18next.use(initReactI18next).init({
  lng: 'ar',
  fallbackLng: 'en',
  resources: {
    ar: { orders: arOrders, tickets: arTickets },
    en: { orders: enOrders, tickets: enTickets },
  },
});

export default i18next;
