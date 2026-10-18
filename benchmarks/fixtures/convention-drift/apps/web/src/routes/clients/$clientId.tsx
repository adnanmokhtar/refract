import { createFileRoute } from '@tanstack/react-router';
import { t } from '@acme/i18n';
import { CustomerDetail } from '../../features/customers';

export const Route = createFileRoute('/clients/$clientId')({
  component: ClientRoute,
});

function ClientRoute() {
  const { clientId } = Route.useParams();
  return (
    <section>
      <h1>{t('clients.title')}</h1>
      <CustomerDetail customerId={clientId} />
    </section>
  );
}
