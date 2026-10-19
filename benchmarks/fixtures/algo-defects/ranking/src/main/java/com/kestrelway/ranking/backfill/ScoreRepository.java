package com.kestrelway.ranking.backfill;

import java.util.List;

public interface ScoreRepository {

    /** Rows with score >= the given value, ascending by score, at most {@code limit}. */
    List<ScoreRow> findByScoreGreaterThanEqual(double score, int limit);

    void saveRescored(ScoreRow row, double newScore);
}
