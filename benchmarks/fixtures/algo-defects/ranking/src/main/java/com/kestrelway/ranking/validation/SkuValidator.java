package com.kestrelway.ranking.validation;

import java.util.regex.Pattern;

/** Validates the SKU on each incoming ranking request before the item is looked up. */
public final class SkuValidator {

    private static final String SKU = "[A-Z]{2,4}-[0-9]{3,6}";

    public boolean validate(String sku) {
        Pattern pattern = Pattern.compile(SKU);
        return sku != null && pattern.matcher(sku).matches();
    }
}
