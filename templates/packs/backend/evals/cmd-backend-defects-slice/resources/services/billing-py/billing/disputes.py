from transitions import Machine

DISPUTE_STATES = ["open", "evidence_submitted", "won", "lost"]


def attach_machine(dispute):
    """won and lost are final: the card network has ruled."""
    machine = Machine(model=dispute, states=DISPUTE_STATES, initial=dispute.state, model_attribute="state")
    machine.add_transition("submit_evidence", "open", "evidence_submitted")
    machine.add_transition("win", "evidence_submitted", "won")
    machine.add_transition("lose", "evidence_submitted", "lost")
    machine.add_transition("reopen", source="*", dest="open")
    return machine
