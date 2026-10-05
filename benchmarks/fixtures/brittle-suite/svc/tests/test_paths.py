import sys

import pytest

from app.paths import export_path


def test_export_path_uses_posix_separators():
    assert export_path("m_1", "2026-09") == "exports/m_1/2026-09.csv"


@pytest.mark.skipif(sys.platform == "win32", reason="object-store keys are POSIX; the Windows dev shell maps them — #431, owner @finance-eng")
def test_export_path_is_a_valid_object_key():
    assert "\\" not in export_path("m_2", "2026-10")
