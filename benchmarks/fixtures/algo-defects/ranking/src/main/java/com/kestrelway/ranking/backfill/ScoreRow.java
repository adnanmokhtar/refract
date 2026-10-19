package com.kestrelway.ranking.backfill;

public record ScoreRow(long itemId, double score) {

    public double getScore() {
        return score;
    }
}
