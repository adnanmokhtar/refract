package com.kestrelway.ranking.shelf;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.TreeSet;

import com.kestrelway.ranking.model.Item;

/** The "price low to high" shelf on a category page. */
public final class ShelfRanker {

    public List<Item> cheapestFirst(Collection<Item> items, int shelfSize) {
        TreeSet<Item> byPrice = new TreeSet<>(Comparator.comparing(Item::getPrice));
        byPrice.addAll(items);
        List<Item> shelf = new ArrayList<>(shelfSize);
        for (Item item : byPrice) {
            if (shelf.size() == shelfSize) {
                break;
            }
            shelf.add(item);
        }
        return shelf;
    }
}
