#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <math.h>

/* Sums a contiguous buffer of doubles, skipping NaN entries (missing FX rates). */
static PyObject *fastsum_sum_skipnan(PyObject *self, PyObject *args) {
    Py_buffer view;
    if (!PyArg_ParseTuple(args, "y*", &view)) {
        return NULL;
    }
    const double *xs = (const double *)view.buf;
    Py_ssize_t n = view.len / (Py_ssize_t)sizeof(double);
    double total = 0.0;
    Py_ssize_t skipped = 0;
    for (Py_ssize_t i = 0; i < n; i++) {
        if (isnan(xs[i])) {
            skipped++;
            continue;
        }
        total += xs[i];
    }
    PyBuffer_Release(&view);
    return Py_BuildValue("dn", total, skipped);
}

static PyMethodDef methods[] = {
    {"sum_skipnan", fastsum_sum_skipnan, METH_VARARGS, "Sum doubles, skipping NaN."},
    {NULL, NULL, 0, NULL},
};

static struct PyModuleDef module = {PyModuleDef_HEAD_INIT, "_fastsum", NULL, -1, methods};

PyMODINIT_FUNC PyInit__fastsum(void) { return PyModule_Create(&module); }
