import build_tools as build

import json, os, ast, math
import pandas as pd
import numpy as np
import networkx as nx
from networkx.drawing.nx_pydot import write_dot

class subWESTnet:

    def __init__(self, data, year):
        """Constructs a network from a subset of utilities.

        Loads and sorts data based on year, and creates empty graph.

        Attributes:
            year: An integer of the year specified
            data: A Pandas DataFrame with data only from the
                year specified
            graph: An empty NetworkX MultiDiGraph.
        """
        assert data[-4:] == '.csv'
        self.year = year
        self.is_balanced = False

        data = pd.read_csv(data)
        self.data = data[data['year'] == year].reset_index(drop=True)

        self.graph = nx.MultiDiGraph()

    def downstream(self, source):
        """Creates downstream graph from a specified utility.

        Assigns new attributes and updates the graph.

        Args:
            source: A string of the name of utility

        Returns:
            Nothing. Prints completion statement.
        """
        self.upstream = False
        self.name = source
        # create empty dictionaries for networkx graph
        nodes = {}
        edges = {}
        node_num = 0

        # get children from utility, save attribute
        down_nodes = build.children(self.data, source)
        self.down_nodes = down_nodes

        # construct links/edges from each node
        paths = build.graph_edges(down_nodes, down=True)

        # create the data for each edge
        edge_dicts = build.edge_data(self.data, paths)
        self.edge_info = edge_dicts

        # building nodes and edges for graph
        for i in range(len(paths)):
            edge = paths[i]
            edges[(edge[0], edge[1])] = edge_dicts[i]

            if edge[0] not in nodes.keys():
                nodes[edge[0]] = node_num
                node_num += 1

            if edge[1] not in nodes.keys():
                nodes[edge[1]] = node_num
                node_num += 1

        # assign attributes
        self.nodes = nodes
        self.edges = edges

        # add to networkx graph
        self.graph.add_nodes_from(nodes)
        self.graph.add_edges_from(edges)

        print('Unweighted downstream graph complete.')

    def upstream(self, end):
        """Creates an upstream graph from a specified utility.

        Assigns new attributes and updates the graph.

        Args:
            end: A string of the utility name.

        Returns:
            Nothing. Prints completion statement.
        """
        self.upstream = True
        self.name = end
        nodes = {}
        edges = {}
        node_num = 0

        up_nodes = build.parents(self.data, end)
        self.up_nodes = up_nodes

        columns = ['source', 'cumulative_volume_af', 'transmission_kwh/af',
                   'treatment_kwh/af','used_vol_af']

        paths = build.graph_edges(up_nodes, down=False)

        edge_dicts = build.edge_data(self.data, paths)
        self.edge_info = edge_dicts

        for i in range(len(paths)):
            edge = paths[i]
            edges[(edge[0], edge[1])] = edge_dicts[i]

            if edge[0] not in nodes.keys():
                nodes[edge[0]] = node_num
                node_num += 1

            if edge[1] not in nodes.keys():
                nodes[edge[1]] = node_num
                node_num += 1

        self.nodes = nodes
        self.edges = edges

        self.graph.add_nodes_from(nodes)
        self.graph.add_edges_from(edges)

        print('Unweighted upstream graph built.')

    def balance_graph(self):
        """Calculates volume-weighted averages.

        Only values of nodes in the graph are accounted for in
        the calculation (not all nodes), so values may differ
        from those calculated in the complete network.

        Assigns new attributes useful for visualizations.

        Args:
            None

        Returns:
            Nothing. Prints completion statement.
        """
        queue_of_nodes = list(self.graph.nodes())
        halt = False
        status = dict.fromkeys(queue_of_nodes, 0)
        completed_nodes = {}

        node = queue_of_nodes.pop()

        while len(queue_of_nodes) >= 0 and not halt:
            ancestors = self.in_nodes(node)

            if build.check_all_complete(ancestors, completed_nodes):
                edge_names = self.graph.in_edges(node)

                if len(edge_names) > 0:
                    numerator = 0
                    denominator = 0

                    for edge in edge_names:
                        d = self.edges[edge]

                        numerator += (d['transmission_kwh/af'] + d['treatment_kwh/af']
                                      + status[d['source']]) * d['cumulative_volume_af']
                        denominator += d['cumulative_volume_af']
                        weighted_average = numerator / denominator

                    completed_nodes[node] = weighted_average

                    status[node] = weighted_average

                else:
                    completed_nodes[node] = status[node]
                if len(queue_of_nodes) > 0:
                    del node
                    node = queue_of_nodes.pop()
                else:
                    halt = True

            else:
                queue_of_nodes.append(node)
                node = queue_of_nodes[0]
                del queue_of_nodes[0]

        # Store results
        self.completed_nodes = completed_nodes
        data = [{'node':k, 'kwh/af': v} for k, v in completed_nodes.items()]
        self.energy = pd.DataFrame(data)
        self.energy = self.energy[['node', 'kwh/af']]

        self.is_balanced = True
        print('Graph is weighted.')

    def table(self):
        """Displays table of data used in network.

        Args:
            None

        Returns:
            A Pandas DataFrame of the data used to create
            the network.
        """
        cols = ['source', 'target', 'cumulative_volume_af', 'transmission_kwh/af',
       'treatment_kwh/af', 'used_vol_af']
        df = pd.DataFrame(list(self.edges.values()))
        df = df.drop('number', axis=1)[cols]
        return df

    def in_nodes(self, node):
        return [e[0] for e in self.graph.in_edges(node)]

    def save_energy_df(self, filename, index=False):
        self.energy.to_csv(filename+'.csv', index=index)
        assert pd.read_csv(filename+'.csv').shape == self.energy.shape
        print('File saved.')

    def to_dot(self, path='output/'):
        """ Saves networkx graph to dot file.

        Args:
            completed_nodes: A dictionary of nodes and their computed values.
               If nodes were not weighted, use the nodes computed for the graph.
               (Nodes must be in networkx format).

        Returns:
            A dot file written to the specified path.
        """
        if self.upstream:
            direction = 'upstream'
        else:
            direction = 'downstream'

        if self.is_balanced:
            completed_nodes = self.completed_nodes
        else:
            completed_nodes = []
        # Define file name
        filename = 'sub_%(name)s_%(year)s_%(direction)s' % {
                                'name': self.name,
                                'year': self.year,
                                'direction': direction
                                  }

        # Update colors
        colors = ['green', 'aquamarine', 'orange', 'yellow', 'red']
        self.graph_colors = []
        for node in completed_nodes:
            val =  (((completed_nodes[node] - 0) * (4 - 0)) / (4000 - 0)) + 0;

            val = int(math.floor(val)) if val <=4 else 4
            color = build.ColorScale(completed_nodes[node])
            self.graph.add_node(node, style='filled', fillcolor=color)
            self.graph_colors.append({node: color})

        # write dot
        write_dot(self.graph, path+filename+'.dot')
