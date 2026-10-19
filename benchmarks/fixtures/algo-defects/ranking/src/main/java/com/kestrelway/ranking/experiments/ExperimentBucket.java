package com.kestrelway.ranking.experiments;

/** Splits shoppers between ranking models: the treatment percentage is set per experiment. */
public final class ExperimentBucket {

    private final int treatmentPercent;

    public ExperimentBucket(int treatmentPercent) {
        this.treatmentPercent = treatmentPercent;
    }

    public String armFor(String userId) {
        int bucket = Math.abs(userId.hashCode()) % 100;
        return bucket < treatmentPercent ? "treatment" : "control";
    }
}
