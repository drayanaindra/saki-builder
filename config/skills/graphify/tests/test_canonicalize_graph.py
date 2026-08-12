import copy
import subprocess
import sys
from pathlib import Path

import pytest

from config.skills.graphify.canonicalize_graph import canonicalize_graph, main, normalize_id

BASE_GRAPH = {
    "directed": True,
    "multigraph": True,
    "graph": {},
    "nodes": [
        {
            "id": "src_mod_a",
            "label": "mod_a.py",
            "norm_label": "mod_a.py",
            "source_file": "src/mod_a.py",
        },
        {
            "id": "src_mod_a_foo",
            "label": "foo()",
            "norm_label": "foo()",
            "source_file": "src/mod_a.py",
        },
        {
            "id": "src_mod_b_foo",
            "label": "foo()",
            "norm_label": "foo()",
            "source_file": "src/mod_b.py",
        },
    ],
    "links": [
        {
            "source": "src_mod_a",
            "target": "src_mod_a_foo",
            "relation": "contains",
            "weight": 1.0,
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": "src/mod_a.py",
            "context": "def",
        },
        {
            "source": "src_mod_b_foo",
            "target": "src_mod_a_foo",
            "relation": "calls",
            "weight": 1.0,
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": "src/mod_b.py",
            "context": "call",
        },
        {
            "source": "src_mod_b_foo",
            "target": "src_mod_a_foo",
            "relation": "calls",
            "weight": 1.0,
            "confidence": "INFERRED",
            "confidence_score": 0.8,
            "source_file": "src/mod_b.py",
            "context": "call",
        },
    ],
    "hyperedges": [
        {"nodes": ["src_mod_a", "src_mod_a_foo", "src_mod_b_foo"], "relation": "group"}
    ],
}


def _node_ids(graph):
    return {n["id"] for n in graph["nodes"]}


def test_normalize_id_recipe():
    assert normalize_id("foo()") == "foo"
    assert normalize_id("Bar()") == "bar"
    assert normalize_id("Foo Bar") == "foo_bar"
    assert normalize_id(normalize_id("Foo Bar()")) == normalize_id("Foo Bar()")


def test_merge_same_label_nodes_rewires_edges():
    graph = copy.deepcopy(BASE_GRAPH)
    out = canonicalize_graph(graph)
    nodes = {n["id"]: n for n in out["nodes"]}
    assert len(out["nodes"]) == 2
    assert "src_mod_a_foo" in nodes
    assert nodes["src_mod_a_foo"]["canonical_id"] == "foo"
    assert nodes["src_mod_a_foo"]["merged_from"] == ["src_mod_b_foo"]
    assert "src_mod_b_foo" not in _node_ids(out)
    for link in out["links"]:
        assert link["source"] != "src_mod_b_foo"
        assert link["target"] != "src_mod_b_foo"


def test_accumulate_edge_weights_for_recurring_src_tgt_relation():
    graph = copy.deepcopy(BASE_GRAPH)
    out = canonicalize_graph(graph)
    calls = [l for l in out["links"] if l["relation"] == "calls"]
    assert len(calls) == 1
    assert calls[0]["weight"] == 2.0
    assert calls[0]["confidence"] == "EXTRACTED"
    assert calls[0]["confidence_score"] == 1.0
    contains = [l for l in out["links"] if l["relation"] == "contains"]
    assert contains[0]["weight"] == 1.0


def test_preserves_schema_and_confidence():
    graph = copy.deepcopy(BASE_GRAPH)
    out = canonicalize_graph(graph)
    for key in ("directed", "multigraph", "graph", "nodes", "links", "hyperedges"):
        assert key in out
    graph_str = str(out)
    assert "betweenness" not in graph_str
    for link in out["links"]:
        assert link["confidence"] in ("EXTRACTED", "INFERRED", "AMBIGUOUS")
        assert "confidence_score" in link


def test_idempotent_rerun_noop():
    graph = copy.deepcopy(BASE_GRAPH)
    once = canonicalize_graph(graph)
    twice = canonicalize_graph(copy.deepcopy(once))
    assert twice == once


def test_missing_file_exit_1():
    assert main(["canonicalize_graph.py", "/nonexistent.json"]) == 1


def test_roundtrip_via_cli(tmp_path):
    in_path = tmp_path / "graph.json"
    out_path = tmp_path / "canonical.json"
    in_path.write_text(__import__("json").dumps(BASE_GRAPH))
    script = Path(__file__).parent.parent / "canonicalize_graph.py"
    proc = subprocess.run(
        [sys.executable, str(script), str(in_path), "--out", str(out_path)],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0
    out = __import__("json").loads(out_path.read_text())
    assert canonicalize_graph(copy.deepcopy(BASE_GRAPH)) == out


def test_malformed_file_exit_1(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text("not json")
    assert main(["canonicalize_graph.py", str(bad)]) == 1


def test_hyperedges_rewired(tmp_path):
    graph = copy.deepcopy(BASE_GRAPH)
    out = canonicalize_graph(graph)
    for hyper in out["hyperedges"]:
        assert "src_mod_b_foo" not in hyper["nodes"]
