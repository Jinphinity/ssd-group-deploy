extends Node

## Lightweight object pool

class_name Pools

var pools := {}

func get_or_create(name: String, factory: Callable) -> Node:
    if not pools.has(name):
        pools[name] = []
    if pools[name].size() > 0:
        return pools[name].pop_back()
    return factory.call()

func release(name: String, node: Node) -> void:
    if not pools.has(name):
        pools[name] = []
    pools[name].append(node)

