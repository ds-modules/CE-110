import network as net
import networkx as nx
from networkx.drawing.nx_pydot import write_dot
import pandas as pd
import os, getpass, math


class WESTNet(object):
    """WESTNet: network model and decision-support tool for analyzing
    the resource consumption, energy usage, and environmental
    impacts of California's water supply network.
    """
    def __init__(self, file_name, run_name=None):
        assert file_name[-4:] == '.csv'
        assert file_name[:5] == 'data/'
        # Inititalize
        self.name = file_name[5:-4];
        self.data = pd.read_csv(file_name)

    def run(self, year, pdf=False, dot=True):
        # Intitialize Parameters
        self.year = year;

        # Get data from master links dataset
        self.d = self.data[self.data['year'] == year]

        # Build network
        net.build_graph(self)

        # Get list of source edges
        net.get_source_facilities(self)

        # Balance network
        net.balance_graph(self)

        # Save Graph
        if pdf:
            net.graph_to_pdf(self, self.completed_nodes);

        # Write dot file
        if dot:
            pydot_file = nx.nx_pydot.to_pydot(self.g)
            pydot_file.write_dot('output/links_'+str(self.year)+'.dot')

    def save_csv(df, dir='output/', index=False):
        return df.to_csv(dir+file_name, index=index)

    #### new subgraph code ####
    def create_subgraph(self, utility, filename, up=False, csv=True):
        if up:
            nested = net.parents(self.d, utility)
        else:
            nested = net.children(self.d, utility)

        self.sub_nodes = net.flatten(nested)
        subgraph = self.g.subgraph(self.sub_nodes)

        colors = ['green', 'aquamarine', 'orange', 'yellow', 'red'];

        for node in self.completed_nodes:
            val =  (((self.completed_nodes[node] - 0) * (4 - 0)) / (4000 - 0)) + 0
            val = int(math.floor(val)) if val <=4 else 4;
            color = net.colorScale(self.completed_nodes[node])
            self.g.add_node(node, style='filled',fillcolor=color)

        write_dot(subgraph, 'output/' + filename + '.dot')

        #energy table
        rows = [{'node': node, 'kwh/af':self.completed_nodes[node]} for node in subgraph.nodes()]
        self.subgraph_table = pd.DataFrame(rows)

        if csv:
            self.subgraph_table.to_csv(filename+'_energy_table_full.csv', index=False)

        return self.subgraph_table[['node', 'kwh/af']]
