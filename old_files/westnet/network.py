import networkx as nx
from networkx.drawing.nx_agraph import write_dot
import os, math
import pandas as pd
import matplotlib as mpl
import matplotlib.cm as cm

def build_graph(self):
	nodes = {};
	edges = {};
	node_num = 0;
	edge_num = 0;
	g = nx.MultiDiGraph();

	# Iterate over the rows in the data table
	for index, r in self.d.iterrows():
		# Add edge
		g.add_edge(r['source'], r['target']);

		# Store edge data
		d = r[['cumulative_volume_af','transmission_kwh/af','treatment_kwh/af',
					'used_vol_af']].to_dict();
		d['number'] = edge_num;
		d['source'] = r['source'];
		d['target'] = r['target'];

		edges[(r['source'],r['target'])] = d;
		edge_num +=1;

		# Add nodes if not in node list
		if r['source'] not in nodes.keys():
			nodes[r['source']] = node_num;
			node_num+=1;

		if r['target'] not in nodes.keys():
			nodes[r['target']] = node_num;
			node_num+=1;

	# Save Graph
	self.g = g;
	self.nodes = nodes;
	self.edges = edges;

def in_nodes(self, node):

	return [e[0] for e in self.g.in_edges(node)]

def get_source_facilities(self):
	primary_nodes = []

	for node in self.nodes:
		upstream_nodes =  in_nodes(self, node);

		if len(upstream_nodes) == 0:
			# Add node name to primary node list
			primary_nodes.append(node);

	self.primary_nodes = primary_nodes;

def check_all_complete(nodes, completed_nodes):

	status = [n in completed_nodes.keys() for n in nodes];

	return all(status)

def get_incomplete_node(nodes, completed_nodes):

	for n in nodes:
		if n not in completed_nodes.keys():
			return n

def balance_graph(self):
	queue_of_nodes = list(self.g.nodes());
	status = dict.fromkeys(queue_of_nodes, 0);
	completed_nodes = {};


	test =  dict.fromkeys(queue_of_nodes, 0);

	# Prime queue
	node = queue_of_nodes.pop();

	while len(queue_of_nodes) !=0:

		ancestors = in_nodes(self, node);

		# Check status
		if check_all_complete(ancestors, completed_nodes):
			# Get attribute data from in edges
			edge_names = self.g.in_edges(node);

			if len(edge_names) > 0:
				numerator = 0;
				denominator = 0;

				for e in edge_names:
					# pull the data for each edge
					d = self.edges[e];

					numerator += (d['transmission_kwh/af'] + d['treatment_kwh/af'] + status[d['source']]) * d['cumulative_volume_af'];
					denominator += d['cumulative_volume_af'];

				weighted_average = numerator / denominator;


				# Update
				completed_nodes[node] = weighted_average;

				status[node] = weighted_average;

			else:
				completed_nodes[node] = status[node];

			del node
			node = queue_of_nodes.pop();
		else:
			queue_of_nodes.append(node);
			node = queue_of_nodes[0];
			del queue_of_nodes[0]
			#node = get_incomplete_node(ancestors, completed_nodes);

	# Store results
	self.completed_nodes = completed_nodes;
	data = [{'node':k, 'kwh/af': v} for k, v in completed_nodes.items()]
	self.energy = pd.DataFrame(data)

def colorScale(val, vmin=0, vmax=4500, cmap = cm.RdYlGn_r):
	norm = mpl.colors.Normalize(vmin=vmin, vmax=vmax)
	m = cm.ScalarMappable(norm=norm, cmap=cmap)

	rgb = m.to_rgba(val)
	return mpl.colors.rgb2hex(rgb)

def graph_to_pdf(self, completed_nodes, path = 'output/'):
	# Define file name
	filename = '%(name)s_%(year)s' % {
					'name':self.name,
					'year': self.year
				};

	# Update colors
	colors = ['green', 'aquamarine', 'orange', 'yellow', 'red'];
	for node in completed_nodes:
		val =  (((completed_nodes[node] - 0) * (4 - 0)) / (4000 - 0)) + 0;

		val = int(math.floor(val)) if val <=4 else 4;
		color = colorScale(completed_nodes[node])
		self.g.add_node(node, style='filled',fillcolor=color)

	# Write the dot file
	write_dot(self.g, path+filename+'.dot');


	# Process the dot file using GraphViz
	os.system("""
		dot -Tpdf %(path)s%(filename)s.dot -o %(path)s%(filename)s.pdf
		"""% {
			'path': path,
			'filename':filename
		});
