import { ChatPanel } from './chat/ChatPanel';
import { TicketSidebar } from './tickets/TicketSidebar';

export function App() {
  return (
    <main className="layout">
      <TicketSidebar />
      <ChatPanel />
    </main>
  );
}
