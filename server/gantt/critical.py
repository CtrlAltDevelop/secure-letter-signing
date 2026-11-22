"""Critical path over finish-to-start links: the longest chain of linked items; slack 0 = critical."""
from collections import defaultdict, deque


def slack(durations: dict, edges: list[tuple]) -> dict:
    """Days of slack per linked item (0 = critical). Items without links, or caught in a cycle, are left out."""
    succs, preds = defaultdict(list), defaultdict(list)
    for a, b in edges:
        if a in durations and b in durations:
            succs[a].append(b)
            preds[b].append(a)
    nodes = set(succs) | set(preds)
    left = {n: len(preds[n]) for n in nodes}
    order, queue = [], deque(n for n in nodes if not left[n])
    while queue:
        n = queue.popleft()
        order.append(n)
        for s in succs[n]:
            left[s] -= 1
            if not left[s]:
                queue.append(s)
    early = {}
    for n in order:
        early[n] = max((early[p] + durations[p] for p in preds[n]), default=0)
    finish = max((early[n] + durations[n] for n in order), default=0)
    late = {}
    for n in reversed(order):
        late[n] = min((late[s] for s in succs[n]), default=finish) - durations[n]
    return {n: late[n] - early[n] for n in order}
