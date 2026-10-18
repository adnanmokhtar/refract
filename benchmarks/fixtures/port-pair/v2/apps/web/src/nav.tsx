import { NavLink } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useCan } from './lib/useCan';

const items = [
  { to: '/', label: 'nav.dashboard' },
  { to: '/orders', label: 'nav.orders' },
  { to: '/wallet', label: 'nav.wallet' },
];

export function Nav() {
  const { t } = useTranslation();
  const canSeeReports = useCan('reports:view');

  return (
    <nav className="portal-nav" aria-label={t('nav.main')}>
      <ul>
        {items.map((item) => (
          <li key={item.to}>
            <NavLink to={item.to}>{t(item.label)}</NavLink>
          </li>
        ))}
        {canSeeReports && (
          <li>
            <NavLink to="/reports">{t('nav.reports')}</NavLink>
          </li>
        )}
      </ul>
    </nav>
  );
}
