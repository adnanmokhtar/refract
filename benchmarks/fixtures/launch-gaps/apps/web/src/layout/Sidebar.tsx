import { NavLink } from 'react-router';
import { useTranslation } from 'react-i18next';
import { useCan } from '../entities/permissions/use-permissions';
import { useModuleEnabled } from '../shared/entitlements/use-module-enabled';

export function Sidebar() {
  const { t } = useTranslation();
  const canManageTeam = useCan('team.manage');
  const orders = useModuleEnabled('orders');
  const inventory = useModuleEnabled('inventory');
  const reports = useModuleEnabled('reports');
  const inbox = useModuleEnabled('whatsapp_inbox');
  const giftCards = useModuleEnabled('gift_cards');
  const imports = useModuleEnabled('bulk_import');
  return (
    <nav aria-label="Main">
      <NavLink to="/">{t('nav.dashboard')}</NavLink>
      {orders && <NavLink to="/orders">{t('nav.orders')}</NavLink>}
      {inventory && <NavLink to="/stores">{t('nav.stores')}</NavLink>}
      {reports && <NavLink to="/reports">{t('nav.reports')}</NavLink>}
      {reports && <NavLink to="/reports/retention">{t('nav.retention')}</NavLink>}
      {inbox && <NavLink to="/inbox">{t('nav.inbox')}</NavLink>}
      <NavLink to="/loyalty">{t('nav.loyalty')}</NavLink>
      {giftCards && <NavLink to="/gift-cards">{t('nav.giftCards')}</NavLink>}
      {imports && <NavLink to="/imports">{t('nav.imports')}</NavLink>}
      <NavLink to="/assistant">{t('nav.assistant')}</NavLink>
      <NavLink to="/referrals">{t('nav.referrals')}</NavLink>
      {canManageTeam && <NavLink to="/team">{t('nav.team')}</NavLink>}
      <NavLink to="/settings">{t('nav.settings')}</NavLink>
    </nav>
  );
}
