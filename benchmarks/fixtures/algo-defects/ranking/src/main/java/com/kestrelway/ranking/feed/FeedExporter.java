package com.kestrelway.ranking.feed;

import java.util.List;

import com.kestrelway.ranking.model.Item;

/** Builds the nightly partner feed: one CSV line per store listing every SKU in rank order. */
public final class FeedExporter {

    private final ItemRepository items;

    public FeedExporter(ItemRepository items) {
        this.items = items;
    }

    public String skuLine(long storeId) {
        List<Item> ranked = items.findListedByStore(storeId);
        String csv = Long.toString(storeId);
        for (Item item : ranked) {
            csv = csv + "," + item.getSku();
        }
        return csv;
    }
}
