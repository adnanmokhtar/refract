package com.acme.ledger.saga;

import io.eventuate.tram.commands.common.Command;
import io.eventuate.tram.commands.consumer.CommandWithDestination;
import java.util.Map;

final class Commands {
    private Commands() {}

    record Named(String type, String id) implements Command {}

    static CommandWithDestination to(String channel, String type, String id) {
        return new CommandWithDestination(channel, null, new Named(type, id), Map.of());
    }
}
