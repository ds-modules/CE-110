import network as net
import networkx as nx
import pandas as pd
import os, getpass


class WESTNet(object):
	"""
	WESTNet: network model and decision-support tool for analyzing
	the resource consumption, energy usage, and environmental
	impacts of California's water supply network.

	"""
	def __init__(self, file_name, run_name=None):
		assert file_name[-4:] == '.csv'

		# Inititalize
		self.name = file_name[:-4];
		self.data = pd.read_csv('import/'+file_name);

	def run(self, year, pdf=False, dot=True):
		# Intitialize Parameters
		self.year = year;

		# Get data from master links dataset
		self.d = self.data[self.data['year'] == year];

		# Build network
		net.build_graph(self);

		# Get list of source edges
		net.get_source_facilities(self);

		# Balance network
		net.balance_graph(self);

		# Save Graph
		if pdf:
			net.graph_to_pdf(self, self.completed_nodes);

		# Write dot file
		if dot:
			pydot_file = nx.nx_pydot.to_pydot(self.g)
			pydot_file.write_dot('links_'+str(self.year)+'.dot')


	def save_csv(df, dir='output/', index=False):
		return df.to_csv(dir+file_name, index=index);
