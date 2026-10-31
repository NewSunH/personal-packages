#!/usr/bin/env python3
"""Check extraction collisions and stale callbacks against the packaged code."""
import argparse
import ast
from functools import partial
import importlib
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest

sys.dont_write_bytecode = True
parser = argparse.ArgumentParser()
parser.add_argument("path", type=Path, help="Patched source root or installed package prefix")
parser.add_argument("--sevenzip", help="Override 7zz for a source tree without path substitution")
options = parser.parse_args()
if (options.path / "src/plugins/sevenzip.py").is_file():
    module_root, module_name = options.path, "src"
else:
    module_root, module_name = options.path / "share/akizip", "akizip"
sys.path.insert(0, str(module_root))
sevenzip = importlib.import_module(f"{module_name}.plugins.sevenzip")
is_password_error = importlib.import_module(f"{module_name}.plugins.password").is_password_error
if options.sevenzip:
    sevenzip.SEVENZIP_PATH = options.sevenzip

# Load the actual method without constructing GTK widgets or requiring a display.
tree = ast.parse((module_root / module_name / "ui/window.py").read_text())
window_class = next(node for node in tree.body
                    if isinstance(node, ast.ClassDef) and node.name == "AkizipWindow")
refresh_node = next(node for node in window_class.body
                    if isinstance(node, ast.FunctionDef) and node.name == "_refresh_file_list")
scope = {"Path": Path, "partial": partial, "_": lambda text: text,
         "is_password_error": is_password_error}
exec(compile(ast.Module(body=[refresh_node], type_ignores=[]), "upstream-window", "exec"), scope)
refresh = scope["_refresh_file_list"]


class PendingQueue:
    def __init__(self):
        self.jobs = []

    def submit(self, function, args, **callbacks):
        self.jobs.append({"function": function, "args": args, **callbacks})


class FakeWindow:
    def __init__(self):
        self.selected = Path("/A.zip")
        self.category = "full"
        self.queue = PendingQueue()
        self.populated = []
        self.errors = []
        self.password_callbacks = []
        self.states = []
        system = SimpleNamespace(
            has_selected=lambda: self.selected is not None,
            is_archive=lambda: self.selected.suffix == ".zip",
            format_category=lambda: self.category,
            operation_path=lambda: str(self.selected),
            selected_path=lambda: str(self.selected),
        )
        self.app = SimpleNamespace(system=system, commands={"archive.list": sevenzip.archive_list},
                                   job_queue=self.queue)
        self._file_list_store = SimpleNamespace(remove_all=lambda: None)
        self.file_list_stack = SimpleNamespace(set_visible_child_name=self.states.append)

    def get_application(self):
        return self.app

    def _get_archive_locale(self):
        return "zh_CN"

    def _populate_file_list(self, output):
        self.populated.append(output)

    def _on_file_list_error(self, error):
        self.errors.append(error)

    def _present_password_dialog(self, callback):
        self.password_callbacks.append(callback)


class InteractionTests(unittest.TestCase):
    def test_extract_preserves_existing_files(self):
        with tempfile.TemporaryDirectory(prefix="akizip-interactions-") as temp:
            root = Path(temp)
            source = root / "中文 文件.txt"
            source.write_bytes(b"archive contents")
            for fmt in ("7z", "zip"):
                archive = root / f"archive.{fmt}"
                sevenzip.archive_compress_advance(archive, [source], [f"-t{fmt}", "-mx=1"], timeout=20)
                for selected in (False, True):
                    with self.subTest(format=fmt, selected=selected):
                        target = root / f"{fmt}-{selected}"
                        target.mkdir()
                        existing = target / source.name
                        existing.write_bytes(b"existing user contents")
                        if selected:
                            sevenzip.archive_extract_FileInZip(archive, source.name, target, timeout=20)
                        else:
                            sevenzip.archive_extract(archive, target, timeout=20)
                        self.assertEqual(existing.read_bytes(), b"existing user contents")
                        others = [path for path in target.iterdir() if path != existing]
                        self.assertEqual(len(others), 1)
                        self.assertEqual(others[0].read_bytes(), source.read_bytes())

    def test_only_latest_callbacks_change_the_view(self):
        window = FakeWindow()
        for name in ("A.zip", "B.zip", "A.zip"):
            window.selected = Path("/") / name
            refresh(window)
        for old in window.queue.jobs[:-1]:
            old["on_success"]("stale list")
            old["on_error"](RuntimeError("old failure"))
            old["on_error"](RuntimeError("Wrong password"))
        self.assertEqual(window.populated, [])
        self.assertEqual(window.errors, [])
        self.assertEqual(window.password_callbacks, [])
        current = window.queue.jobs[-1]
        current["on_success"]("current list")
        error = RuntimeError("current failure")
        current["on_error"](error)
        self.assertEqual(window.populated, ["current list"])
        self.assertEqual(window.errors, [error])

    def test_early_returns_invalidate_pending_callbacks(self):
        for state in ("no selection", "not archive", "no preview"):
            with self.subTest(state=state):
                window = FakeWindow()
                refresh(window)
                pending = window.queue.jobs[-1]
                if state == "no selection":
                    window.selected = None
                elif state == "not archive":
                    window.selected = Path("/notes.txt")
                else:
                    window.category = "no_preview"
                refresh(window)
                pending["on_success"]("stale list")
                pending["on_error"](RuntimeError("old failure"))
                pending["on_error"](RuntimeError("Wrong password"))
                self.assertEqual(len(window.queue.jobs), 1)
                self.assertEqual(window.populated, [])
                self.assertEqual(window.errors, [])
                self.assertEqual(window.password_callbacks, [])

    def test_password_retry_is_bound_to_its_request(self):
        window = FakeWindow()
        refresh(window)
        window.queue.jobs[-1]["on_error"](RuntimeError("Wrong password"))
        self.assertEqual(len(window.password_callbacks), 1)
        retry = window.password_callbacks[0]
        retry("current password")
        self.assertEqual(len(window.queue.jobs), 2)
        self.assertEqual(window.queue.jobs[-1]["args"], (Path("/A.zip"), "current password"))
        window.selected = None
        refresh(window)
        retry("obsolete password")
        self.assertEqual(len(window.queue.jobs), 2)
        window.queue.jobs[-1]["on_success"]("obsolete retry result")
        self.assertEqual(window.populated, [])


unittest.main(argv=[sys.argv[0]], verbosity=2)
