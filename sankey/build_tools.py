import pandas as pd

import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.cm as cm


def children(data, source):
    """Constructs a nested list of downstream nodes 
    from a specified utility.
    
    Args:
        data: A Pandas DataFrame.
        source: A string specifying the name of the utility
    
    Returns:
        A list, nested in a tree-like structure to indicate
        children. A child is always represented by another
        (possibly nested) list. An example:
        
        ['1807041PD', ['1807045PD', ['1807045E']],
                      ['1807043PD', ['1807043E']]]
        
        Or, nothing if in a recursive call and an end utility
        is reached.
    """
    # get rows with specified utility as the source
    rows = data[data.source == source]
    
    # if end is reached, return nothing
    if rows.shape[0] == 0:
        return 
    
    # create starting node
    down_nodes = [source] 
    
    #iterate through each row in sorted rows
    for i, row in rows.iterrows():
        r = []
        target = row.source
        next_target = row.target
            
        if data[data.source == next_target].shape[0] == 0:
            r.append([next_target])
        else:
            r.append(children(data, next_target))
            
        down_nodes.extend(r)
    
    return down_nodes

def graph_edges(path, down=True) -> list:
    """ Recursively creates a list of edges.
    
    Args:
        path: A list of children or parents (use the one
            returned from the `children` or `parents` function).
        down:  indicating if the
            edges are to be built up or downstream.
    
    Returns:
        A list of edges, in tuples, which is usable in 
        a NetworkX graph.
    """
    edges = []
    first_node = path[0]
    branches = path[1:]
    seen = set()
    
    if down:
        for b in branches:
            edges.append((first_node, b[0]))
        
            if type(b) == list and len(b) == 1:
                edges.append((first_node, b[0]))
            else:
                nested_edges = graph_edges(b, down)
                edges.extend(nested_edges)
        
        seen = set()
        edges =  [x for x in edges if not (x in seen or seen.add(x))]
    
    else:
        for b in branches:
            edges.append((b[0], first_node))

            if type(b) == list and len(b) == 1:
                edges.append((b[0], first_node))
            else:
                nested_edges = graph_edges(b, down)
                edges.extend(nested_edges)

        edges =  [x for x in edges if not (x in seen or seen.add(x))][::-1]
    
    return edges

def edge_data(data, paths):
    """Builds a list of edges with data for computing
    
    Args:
        data: A Pandas DataFrame instance.
        paths: A list of edges (computed in `graph_edges` function).
        
    Returns:
        A list of dictionaries containing values in the rows for 
        source-target pairs (or edges), as well as edge numbers 
        required for the graph.
    """
    edge_num = 0
    columns = ['source', 'cumulative_volume_af', 'transmission_kwh/af', 
               'treatment_kwh/af','used_vol_af']
    
    edge_dicts = []
    for i in paths:
        rows = data[(data.source == i[0]) & (data.target == i[1])]
        
        edge_dict = {}
        for col in columns:
            edge_dict[col] = rows[col].values[0]
        #edge_dict = rows[columns].to_dict('records') this stopped working
        
        edge_dict['number'] = edge_num
        
        edge_num += 1
        
        edge_dicts.append(edge_dict)
        edge_dict['target'] = i[1]
        
    return edge_dicts

def parents(data, target):
    """Constructs a nested list of nodes upstream 
    from a specified utility. Follows the same
        structure as the `children` function.
    
    Args:
        data: A Pandas DataFrame.
        target: A string specifying the endpoint 
            utility.
    
    Returns:
        A list that is nested in a tree-like structure to indicate
        parents. The structure of the list mirrors that in the 
        `children` function. For example, if the target is '1806011E':
        
        ['1806011E', ['1806011PD', ['1806011GW', ...] ...] ...]
        
        Otherwise, nothing is returned if, in a recursive call the
        utility has no further sources.
    """
    rows = data[data.target == target]
    
    if rows.shape[0] == 0:
        return 
    
    child = [target]
    for i, row in rows.iterrows():
        p = []
        parent = row.target
        next_target = row.source
        if data[data.target == next_target].shape[0] == 0:
            p.append([next_target])
        else:
            p.append(parents(data, next_target))
        
        child.extend(p)
    
    return child

def check_all_complete(nodes, completed_nodes):
    """Checks if nodes are in `completed_nodes`"""
    status = [n in completed_nodes.keys() for n in nodes]
    return all(status)
    
def ColorScale(val, vmin=0, vmax=4500, cmap = cm.RdYlGn_r):
    norm = mpl.colors.Normalize(vmin=vmin, vmax=vmax)
    m = cm.ScalarMappable(norm=norm, cmap=cmap)

    rgb = m.to_rgba(val)
    return mpl.colors.rgb2hex(rgb)