#!/usr/bin/env python3
"""Post-build canonicalization pass for graphify graph.json.

Merges duplicate-label nodes, rewires their edges, and accumulates weights for
recurring (source, target, relation) triples while preserving the graphify
schema (nodes[]/links[]/hyperedges[], EXTRACTED|INFERRED|AMBIGUOUS confidence).
Additive-only: nodes gain ``canonical_id`` and ``merged_from``; everything else
is unchanged. Idempotent.
"""

import argparse
import json
import re
import sys
import unicodedata

_NON_WORD_RE = re.compile(r"[^\w]+", re.UNICODE)


def normalize_id(label):
    """Return a canonical key for a node label.

    Mirrors the graphifyy node-id recipe (NFKC -> non-word chars to _ -> collapse
    _+ -> strip leading/trailing _. -> casefold). Idempotent.
    """
    if not label:
        return ""
    normalized = unicodedata.normalize("NFKC", label)
    with_underscores = _NON_WORD_RE.sub("_", normalized)
    collapsed = re.sub(r"_+", "_", with_underscores)
    stripped = collapsed.strip("_.")
    return stripped.casefold()


def canonicalize_graph(graph):
    """Return a copy of ``graph`` with duplicate-label nodes merged.

    Group nodes by ``normalize_id(label)``; the deterministic winner is the
    node with the smallest id. Winner nodes gain ``canonical_id`` (and
    ``merged_from`` when they absorbed others). Links and hyperedge node
    lists are rewired, and links sharing (source, target, relation) are
    collapsed with summed weights and the strongest confidence retained.
    """
    out = dict(graph)
    nodes = list(graph.get("nodes", []))
    links = list(graph.get("links", []))
    hyperedges = list(graph.get("hyperedges", []))

    groups = {}
    for node in nodes:
        key = normalize_id(node.get("label"))
        groups.setdefault(key if key else node["id"], []).append(node)

    winner_nodes = []
    merged_to_winner = {}
    canonical_keys = {}
    for group in groups.values():
        group = sorted(group, key=lambda n: n["id"])
        winner = group[0]
        for node in group:
            canonical_keys[node["id"]] = normalize_id(node.get("label"))
        if len(group) > 1:
            winner["merged_from"] = [n["id"] for n in group[1:]]
        winner["canonical_id"] = canonical_keys[winner["id"]]
        winner_nodes.append(winner)
        for node in group:
            merged_to_winner[node["id"]] = winner["id"]

    remap = {old_id: merged_to_winner[old_id] for old_id in canonical_keys}
    for link in links:
        link["source"] = remap.get(link["source"], link["source"])
        link["target"] = remap.get(link["target"], link["target"])

    accumulated = {}
    for link in links:
        key = (link["source"], link["target"], link["relation"])
        if key in accumulated:
            existing = accumulated[key]
            existing["weight"] = existing.get("weight", 0.0) + link.get("weight", 0.0)
            if link.get("confidence_score", 0.0) > existing.get("confidence_score", 0.0):
                existing["confidence"] = link["confidence"]
                existing["confidence_score"] = link["confidence_score"]
        else:
            accumulated[key] = dict(link)

    for hyper in hyperedges:
        hyper["nodes"] = [remap.get(nid, nid) for nid in hyper.get("nodes", [])]

    out["nodes"] = winner_nodes
    out["links"] = list(accumulated.values())
    out["hyperedges"] = hyperedges
    return out


def load_graph(path):
    """Read and parse a graph.json file, or raise OSError/ValueError."""
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def save_graph(path, graph):
    """Write ``graph`` as JSON to ``path``."""
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(graph, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def main(argv=None):
    """CLI entry point: canonicalize a graph.json in place (or to --out)."""
    parser = argparse.ArgumentParser(description="Canonicalize a graphify graph.json.")
    parser.add_argument("path", help="path to graph.json")
    parser.add_argument("--out", help="output path (defaults to in-place)")
    args = parser.parse_args(argv[1:] if argv is not None else None)

    try:
        graph = load_graph(args.path)
    except (OSError, ValueError) as error:
        print("canonicalize_graph: %s" % error, file=sys.stderr)
        return 1

    result = canonicalize_graph(graph)
    before = len(graph.get("nodes", []))
    after = len(result["nodes"])
    save_graph(args.out or args.path, result)
    print("canonicalized: %d->%d nodes" % (before, after))
    return 0


if __name__ == "__main__":
    sys.exit(main())
