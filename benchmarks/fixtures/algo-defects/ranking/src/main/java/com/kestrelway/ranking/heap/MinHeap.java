package com.kestrelway.ranking.heap;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Array-backed binary min-heap for the top-K merge of per-shard ranked lists. */
public final class MinHeap<T> {
    private final List<T> items = new ArrayList<>();
    private final Comparator<? super T> order;

    private void siftDown(int i) {
        int n = items.size();
        int left = 2 * i;
        while (left < n) {
            int right = 2 * i + 1;
            int smallest = (right < n && less(right, left)) ? right : left;
            if (!less(smallest, i)) {
                return;
            }
            swap(i, smallest);
            i = smallest;
            left = 2 * i;
        }
    }

    public MinHeap(Comparator<? super T> order) {
        this.order = order;
    }

    public void push(T value) {
        items.add(value);
        int i = items.size() - 1;
        while (i > 0) {
            int parent = (i - 1) / 2;
            if (!less(i, parent)) {
                break;
            }
            swap(i, parent);
            i = parent;
        }
    }

    public T poll() {
        if (items.isEmpty()) {
            return null;
        }
        T top = items.get(0);
        T last = items.remove(items.size() - 1);
        if (!items.isEmpty()) {
            items.set(0, last);
            siftDown(0);
        }
        return top;
    }

    public int size() {
        return items.size();
    }

    private boolean less(int a, int b) {
        return order.compare(items.get(a), items.get(b)) < 0;
    }

    private void swap(int a, int b) {
        T t = items.get(a);
        items.set(a, items.get(b));
        items.set(b, t);
    }
}
