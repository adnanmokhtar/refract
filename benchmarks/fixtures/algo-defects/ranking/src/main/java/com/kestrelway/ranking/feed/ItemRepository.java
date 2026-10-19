package com.kestrelway.ranking.feed;

import java.util.List;

import com.kestrelway.ranking.model.Item;

public interface ItemRepository {

    /** Every listed item of a store in rank order (a large store lists 40,000+ SKUs). */
    List<Item> findListedByStore(long storeId);
}
