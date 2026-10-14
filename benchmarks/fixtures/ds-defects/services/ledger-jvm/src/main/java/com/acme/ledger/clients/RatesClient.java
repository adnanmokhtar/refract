package com.acme.ledger.clients;

import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryConfig;
import java.math.BigDecimal;
import java.time.Duration;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/** FX rates for multi-currency settlement (the treasury API answers 400 for an unsupported currency pair). */
@Component
public class RatesClient {

    private final RestClient http = RestClient.create(System.getenv().getOrDefault("FX_API_URL", "https://fx.example"));
    private final Retry retry = Retry.of("fxRates", RetryConfig.custom()
            .maxAttempts(4)
            .intervalFunction(io.github.resilience4j.core.IntervalFunction.ofExponentialRandomBackoff(Duration.ofMillis(200), 2.0, 0.5))
            .build());

    public BigDecimal rate(String from, String to) {
        return Retry.decorateSupplier(retry, () -> http.get().uri("/rates/{from}/{to}", from, to).retrieve().body(BigDecimal.class)).get();
    }
}
