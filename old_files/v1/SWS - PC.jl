include("src/methods.jl")
include("src/visualize.jl")
using DataFrames


# Import Data
path_to_links_data = "/Users/Jenn/Google Drive/Shared Mike and Jenn/links files/links042817.csv"
(F, fHeaders) = readdlm(path_to_links_data, ',', header=true);

# Filter flow data by year and aggregate multi-flows
F = QuickFilterTemp(F, 2010.0);

# Build Graph
g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)

# Plot Graph
path_to_graph_plus_name = "/Users/Jenn/Google Drive/Shared Mike and Jenn/Model Debug/California network"
networkPlot2(g, path_to_graph_plus_name, reverseFacilityHash,FlowHash, false) # Last input sets showLinkData to {{true}} of {{false}}

# Process Subgraphs
path_to_sub_path_save = "/Users/Jenn/Google Drive/Shared Mike and Jenn/Model Debug/"
# All nodes indirectly connected downstream
connects = ViewDownstream(path_to_sub_path_save,"Lk_Orvl",g, facilityHash, reverseFacilityHash, FlowHash);
# Get Energy Value for Node
AssessUpstream(path_to_sub_path_save,"1803015E",g, facilityHash, reverseFacilityHash, FlowHash);


# Summarize Enegry
nrgList  = BundledUnitCost(g, connects, facilityHash, reverseFacilityHash, FlowHash, true, path_to_sub_path_save)

# Visualize SubNetwork Down
EnergySubNetwork(path_to_sub_path_save, "Lk_Orvl", g, facilityHash, reverseFacilityHash, FlowHash, true) # Last input {{TRUE}} yields subgraph only, {{FALSE}} gives whole network
