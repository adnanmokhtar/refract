package com.kestrelway.ranking.backfill;

import java.util.List;

/** Re-scores every item after a model release, walking the score index from a starting score upward. */
public final class ScoreBackfill {

    private static final int PAGE_SIZE = 500;

    private final ScoreRepository repo;
    private final Rescorer rescorer;

    public ScoreBackfill(ScoreRepository repo, Rescorer rescorer) {
        this.repo = repo;
        this.rescorer = rescorer;
    }

    public long run(double fromScore) {
        double cursor = fromScore;
        long rescored = 0;
        while (true) {
            List<ScoreRow> page = repo.findByScoreGreaterThanEqual(cursor, PAGE_SIZE);
            if (page.isEmpty()) {
                break;
            }
            for (ScoreRow row : page) {
                repo.saveRescored(row, rescorer.score(row.itemId()));
                rescored++;
            }
            cursor = page.get(page.size() - 1).getScore();
        }
        return rescored;
    }

    public interface Rescorer {
        double score(long itemId);
    }
}
