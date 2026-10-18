from app.reports import summarise


def test_summarise_counts_and_totals():
    assert summarise([{"totalMinor": 100}, {"totalMinor": 250}]) == {"count": 2, "total_minor": 350}


def test_summarise_empty():
    assert summarise([]) == {"count": 0, "total_minor": 0}
