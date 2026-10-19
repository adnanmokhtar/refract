package com.kestrelway.ranking.model;

import java.math.BigDecimal;

public record Item(long id, String sku, String name, BigDecimal price, double score) {

    public long getId() {
        return id;
    }

    public String getSku() {
        return sku;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public double getScore() {
        return score;
    }
}
