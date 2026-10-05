#!/usr/bin/env python3
"""Read-only lexical source inventory; never connects to Firebase.

Candidates are navigation aids, not proof of query/rule/index compatibility.
Variable queries, conditional filters, OR queries and delegated builders need
manual review. No application values, credentials or complete snippets are emitted.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CALL = re.compile(r'\.(collectionGroup|collection|where|orderBy|limit|limitToLast|'
                  r'startAfterDocument|startAfter|startAt|endBefore|endAt|'
                  r'doc|get|snapshots|count|set|update|delete|add|httpsCallable)\s*\(')
LITERAL = re.compile(r'''\s*(['"])([A-Za-z_][A-Za-z0-9_./-]*)\1\s*(?:,|$)''')


def uncomment(source):
    """Preserve offsets/newlines and strings while blanking Dart/TS comments."""
    out = list(source)
    i = 0
    while i < len(source):
        if source[i] in "'\"`":
            quote = source[i]
            triple = source.startswith(quote * 3, i)
            delimiter = quote * (3 if triple else 1)
            i += len(delimiter)
            while i < len(source):
                if source[i] == '\\':
                    i += 2
                elif source.startswith(delimiter, i):
                    i += len(delimiter)
                    break
                else:
                    i += 1
        elif source.startswith('//', i) or source.startswith('/*', i):
            block = source.startswith('/*', i)
            end = source.find('*/' if block else '\n', i + 2)
            end = len(source) if end == -1 else end + (2 if block else 0)
            for j in range(i, end):
                if source[j] != '\n':
                    out[j] = ' '
            i = end
        else:
            i += 1
    return ''.join(out)


def closing(source, opening):
    depth, i = 1, opening + 1
    while i < len(source):
        c = source[i]
        if c in "'\"`":
            quote = c
            i += 1
            while i < len(source):
                if source[i] == '\\':
                    i += 2
                elif source[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
            continue
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError('Unclosed method call at offset ' + str(opening))


def call_at(source, match):
    end = closing(source, match.end() - 1)
    argument = source[match.end():end]
    literal = LITERAL.match(argument)
    method = match.group(1)
    result = {'method': method, 'line': source.count('\n', 0, match.start()) + 1}
    if method in ('collection', 'collectionGroup', 'where', 'orderBy', 'httpsCallable'):
        result['literal'] = literal.group(2) if literal else None
    if method == 'where':
        result['operators'] = re.findall(
            r'\b(isEqualTo|isNotEqualTo|isLessThanOrEqualTo|isLessThan|'
            r'isGreaterThanOrEqualTo|isGreaterThan|arrayContainsAny|arrayContains|'
            r'whereIn|whereNotIn)\s*:', argument)
        if not result['operators']:
            op = re.search(r'''^\s*(['"])[^'"\n]+\1\s*,\s*(['"])(==|!=|<=|>=|<|>|in|not-in|array-contains|array-contains-any)\2''', argument)
            result['operators'] = [op.group(3)] if op else []
    if method == 'orderBy':
        result['direction'] = 'DESCENDING' if re.search(
            r'''descending\s*:\s*true|,\s*['"]desc['"]''', argument) else 'ASCENDING'
        if re.search(r'descending\s*:\s*(?!true\b|false\b)\w+', argument):
            result['direction'] = 'DYNAMIC'
    return result, end


def inspect_file(path, indexes, rules):
    raw = path.read_text()
    source = uncomment(raw)
    calls = []
    # Only method tokens outside string literals are code. Blank strings in a
    # second mask; parse their arguments from the original uncommented source.
    mask = re.sub(r'''(['"`])(?:\\.|(?!\1)[\s\S])*?\1''',
                  lambda m: ''.join('\n' if c == '\n' else ' ' for c in m[0]), source)
    for match in CALL.finditer(mask):
        item, end = call_at(source, match)
        calls.append((match.start(), end, item))
    accesses = []
    for start, end, item in calls:
        if item['method'] not in ('collection', 'collectionGroup'):
            continue
        chain = [item]
        next_offset = end + 1
        for next_start, next_end, following in calls:
            if next_start < next_offset:
                continue
            if source[next_offset:next_start].strip():
                break
            chain.append(following)
            next_offset = next_end + 1
        leaf = next((c for c in chain[1:] if c['method'] in ('collection', 'collectionGroup')), None)
        own_chain = chain[:chain.index(leaf)] if leaf else chain
        name = item['literal']
        matching = [i for i, index in enumerate(indexes) if index['collectionGroup'] == name]
        accesses.append({
            'line': item['line'], 'collection': name,
            'scope': item['method'], 'chain': own_chain,
            'index_candidate_ids': matching,
            'rule_candidate_ids': [i for i, rule in enumerate(rules)
                                   if name and name in rule['local_path'].split('/')],
            'review': 'MANUAL_REQUIRED',
            'unresolved': name is None or any(c.get('literal', True) is None for c in own_chain),
            'direct_index_review': review_index_signature(item, own_chain, indexes),
        })
    return {
        'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(raw.encode()).hexdigest(),
        'collection_accesses': accesses,
        # Include continuation sites too, even when the receiver is a variable.
        # Some where() sites operate on in-memory Iterables: manual classification.
        'filter_order_cursor_sites': [c for _, _, c in calls if c['method'] in (
            'where', 'orderBy', 'limit', 'limitToLast', 'startAfterDocument',
            'startAfter', 'startAt', 'endBefore', 'endAt', 'count')],
        'callable_sites': [c for _, _, c in calls if c['method'] == 'httpsCallable'],
    }


def review_index_signature(collection, chain, indexes):
    """Conservative matching for literal equality/array filters plus ordering.

    Does not approve query permissions, defaults, conditional additions, range
    plans or variable receivers. Those remain explicit manual-review entries.
    """
    filters = [c for c in chain if c['method'] == 'where']
    orders = [c for c in chain if c['method'] == 'orderBy']
    if not orders or collection['literal'] is None:
        return {'classification': 'MANUAL_REVIEW_REQUIRED'}
    if any(c.get('literal') is None for c in filters + orders):
        return {'classification': 'DYNAMIC_QUERY_REVIEW_REQUIRED'}
    if any(c['direction'] == 'DYNAMIC' for c in orders):
        return {'classification': 'DYNAMIC_QUERY_REVIEW_REQUIRED'}
    if len({c['literal'] for c in filters + orders}) < 2:
        return {'classification': 'SINGLE_FIELD_SOURCE_PATTERN_LIVE_DEFAULTS_UNVERIFIED'}
    equal, arrays = set(), set()
    for c in filters:
        op = c['operators']
        if op in (['isEqualTo'], ['=='], ['whereIn'], ['in']):
            equal.add(c['literal'])
        elif op in (['arrayContains'], ['arrayContainsAny'], ['array-contains'], ['array-contains-any']):
            arrays.add(c['literal'])
        else:
            return {'classification': 'RANGE_OR_COMPLEX_QUERY_REVIEW_REQUIRED'}
    expected_scope = 'COLLECTION_GROUP' if collection['method'] == 'collectionGroup' else 'COLLECTION'
    matches = []
    for i, index in enumerate(indexes):
        if index['collectionGroup'] != collection['literal'] or index['queryScope'] != expected_scope:
            continue
        prefix = index['fields'][:len(equal) + len(arrays)]
        suffix = index['fields'][len(prefix):]
        if {f['fieldPath'] for f in prefix} != equal | arrays:
            continue
        if any(f.get('arrayConfig') != 'CONTAINS' for f in prefix if f['fieldPath'] in arrays):
            continue
        if [(f['fieldPath'], f.get('order')) for f in suffix] == [(c['literal'], c['direction']) for c in orders]:
            matches.append(i)
    return {'classification': 'EXACT_SOURCE_COMPOSITE_SIGNATURE_PRESENT' if matches else 'SOURCE_COMPOSITE_SIGNATURE_NOT_FOUND_REVIEW_REQUIRED',
            'index_ids': matches}


def inventory():
    indexes = json.loads((ROOT / 'firestore.indexes.json').read_text())
    rules = []
    for rule_file in ('firestore.rules', 'storage.rules'):
        source = uncomment((ROOT / rule_file).read_text())
        for match in re.finditer(r'\bmatch\s+(/[^\n]+?)\s*\{\s*(?=\n)', source):
            rules.append({'file': rule_file, 'line': source.count('\n', 0, match.start()) + 1,
                          'local_path': match.group(1)})
    files = sorted({p for parent in ('apps', 'packages') for lib in (ROOT / parent).glob('*/lib')
                    for p in lib.rglob('*.dart')} | set((ROOT / 'functions/src').rglob('*.ts')))
    records = [inspect_file(p, indexes['indexes'], rules) for p in files]
    index_source = uncomment((ROOT / 'functions/src/index.ts').read_text())
    exports = []
    for match in re.finditer(r'export\s*\{([^}]+)\}\s*from\s*["\']([^"\']+)["\']', index_source):
        exports.append({'module': match.group(2), 'symbols': [s.strip() for s in match.group(1).split(',') if s.strip()]})
    return {
        'classification': 'CURRENT_SOURCE_LEXICAL_INVENTORY_NOT_LIVE_PARITY',
        'limitations': ['Candidate rules are local match paths, not effective inherited permissions.',
                       'Candidate indexes share a collection name; field/direction/scope compatibility needs review.',
                       'Variable receivers, dynamic names, conditional/OR filters and delegated builders need review.',
                       'Filter sites can be Dart Iterable operations rather than Firestore.',
                       'No live Firebase, secret, payment provider or production data access.'],
        'coverage': {'source_files': len(records), 'collection_accesses': sum(len(r['collection_accesses']) for r in records),
                     'filter_order_cursor_sites': sum(len(r['filter_order_cursor_sites']) for r in records),
                     'callable_sites': sum(len(r['callable_sites']) for r in records)},
        'config_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                          for name in ('firestore.rules', 'storage.rules', 'firestore.indexes.json',
                                       'firebase.json', 'functions/package.json')},
        'indexes': indexes, 'rule_matches': rules, 'function_exports': exports, 'files': records,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', type=Path, help='compare a saved inventory without writing')
    args = parser.parse_args()
    result = inventory()
    rendered = json.dumps(result, indent=2, sort_keys=True) + '\n'
    if args.check and args.check.read_text() != rendered:
        raise SystemExit('Inventory differs from current source; regenerate and review')
    if args.output:
        args.output.write_text(rendered)
    print(json.dumps(result['coverage'], sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
