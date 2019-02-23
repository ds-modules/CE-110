include("src/methods.jl")
include("src/visualize.jl")
using DataFrames


# Import Data
path_to_links_data = "/Users/Mike/Google Drive/Shared Mike and Jenn/links files/links112916.csv"
(F, fHeaders) = readdlm(path_to_links_data, ',', header=true);

# Filter flow data by year and aggregate multi-flows
F = QuickFilterTemp(F, 2010.0);

# Build Graph
g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)

"""
ADD to Model 12/28/16
"""
# Loops through the network and gets the energy calculations
nrg = Dict();
data_to_save = [];
plot_fails = [];
for k in keys(facilityHash)
  try
    g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
    s = GetSubGraph_UP(g, [facilityHash[k]], reverseFacilityHash, FlowHash);
    UnitCosts, g = QuantifyUnitImpacts(s.F);
    push!(data_to_save,[k ,UnitCosts[length(UnitCosts[:,1]),2]])
    nrg[k] = UnitCosts[length(UnitCosts[:,1]),2];
  catch
    g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
    vs = vertices(g);
    if length(in_edges(vs[facilityHash[k]],g)) == 0
      push!(data_to_save,[k , 0])
      nrg[k] = 0
    else
      push!(plot_fails, facilityHash[k])
    end
  end
end

## PRINTS THE FAILED VALUES
# Common reasons for fails : zero edge (OK), connected to circular link (INPUT ERROR)
g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
networkPlot(g, "/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/fails", plot_fails, "MAC") #, "MAC"

# SAVES THE GOOD VALUES (HORRAY!)
to_csv("/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/each_node_energy.csv", data_to_save, "node_id,net_kWh/af")
g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
Energysubnet(g, "/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/each_node_energy", reverseFacilityHash, nrg, "MAC")

"""
End
"""


"""
# NOT SURE IF WE NEED THIS ANYMORE
# Plot Graph
path_to_graph_plus_name = "/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/California network"
networkPlot2(g, path_to_graph_plus_name, reverseFacilityHash,FlowHash, false, "MAC")

SourceTerminal, NodesToQuant2, Confirms = IdentifyKeyFeatures(g);
#Confirms = BalenceNetwork(NodesToQuant2, Confirms, FlowHash, g); #ERRORS

# Process Subgraphs
path_to_sub_path_save = "/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/"
# All nodes indirectly connected downstream
connects = ViewDownstream(path_to_sub_path_save,"Lk_Orvl",g, facilityHash, reverseFacilityHash, FlowHash, "MAC");
# Get Energy Value for Node
AssessUpstream(path_to_sub_path_save,"1805085E",g, facilityHash, reverseFacilityHash, FlowHash, "MAC");

# Summarize Enegry≠
path_to_graph_plus_name = "/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/California energy"
nrgList = BundledUnitCost(F, connects, true, path_to_sub_path_save)
Energysubnet(g, path_to_graph_plus_name, reverseFacilityHash, nrgList , "MAC")

# Visualize Energy Downstream
EnergySubNetwork(path_to_sub_path_save, "Lk_Orvl", g, facilityHash, reverseFacilityHash, FlowHash, true, "MAC")
"""
