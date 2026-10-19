package com.kestrelway.ranking.sponsored;

import java.util.List;
import java.util.Random;

/** Rotates the sponsored slot between advertisers in proportion to the weight each one bought. */
public final class WeightedPicker {

    public record Advertiser(String id, int weight) {}

    private final Random rng = new Random();

    public Advertiser pick(List<Advertiser> advertisers) {
        int totalWeight = 0;
        for (Advertiser a : advertisers) {
            totalWeight += a.weight();
        }
        int r = rng.nextInt() % totalWeight;
        for (Advertiser a : advertisers) {
            r -= a.weight();
            if (r < 0) {
                return a;
            }
        }
        return advertisers.get(advertisers.size() - 1);
    }
}
