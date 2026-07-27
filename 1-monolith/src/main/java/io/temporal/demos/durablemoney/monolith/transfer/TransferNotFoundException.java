package io.temporal.demos.durablemoney.monolith.transfer;

import java.util.UUID;

class TransferNotFoundException extends RuntimeException {
    TransferNotFoundException(UUID id) {
        super("Transfer not found: " + id);
    }
}
