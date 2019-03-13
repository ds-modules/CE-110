Updated tool for calculating only upstream and/or downstream networks from a specified utility.

----

**Note:** 

There is a problem with the network balancing with choosing only upstream and downstream networks. For example if a utility is chosen for a downstream graph, if it is not a source (i.e. in the middle of some path), it will not consider the utilities before it. As a result, the chosen utility's resulting energy is 0 kwh/af. This will also apply to children in the network that have one or more "parents" not directly linked to the original specified source. 

The same issue applies to upstream graphs, where some "parent" utility might serve other utilities downstream but is not linked to the utility that was initially chosen.