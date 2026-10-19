"""Builds the analytics package with its one C extension (the hot rollup kernel)."""
from setuptools import Extension, setup

fastsum = Extension(
    "analytics._fastsum",
    sources=["csrc/fastsum.c"],
    extra_compile_args=["-O3", "-ffast-math"],
)

setup(
    name="kestrelway-analytics",
    ext_modules=[fastsum],
)
