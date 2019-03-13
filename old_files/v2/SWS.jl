include("src/methods.jl")
include("src/visualize.jl")
include("src/plot.jl")
using DataFrames

# Import Data
path_to_links_data = "/Users/Mike/Google Drive/Shared Mike and Jenn/links files/links061217b.csv"
(F, fHeaders) = readdlm(path_to_links_data, ',', header=true);

# Filter flow data by year and aggregate multi-flows
F = QuickFilterTemp(F, 2020.0);

# Build Graph
g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F);

# Loops through the network and gets the energy calculations
nrg = Dict();
data_to_save = Array{Float64}(0,2);
plot_fails = [];
for k in keys(facilityHash)
  try
    #Build graph
    g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)

    # Get the subgraph for the facility of interest, k
    s = GetSubGraph_UP(g, [facilityHash[k]], reverseFacilityHash, FlowHash);

    # Calaculate the unit Costs for each subnode.
    UnitCosts, g = QuantifyUnitImpacts(s.F);

    # Map Unit Costs to dictionary
    subgraphResultsDict = Dict(zip(UnitCosts[:,1], UnitCosts[:,2]));

    # Get Result for k
    energy_for_facility = subgraphResultsDict[k];

    # Save Data
    data_to_save = [ data_to_save; k energy_for_facility ]
    nrg[k] = energy_for_facility;
  catch(e)
    println(e)
    g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
    vs = vertices(g);
    if length(in_edges(vs[facilityHash[k]],g)) == 0
      data_to_save = [ data_to_save; k 0 ];
      nrg[k] = 0
    else
      push!(plot_fails, facilityHash[k])
    end
  end
end





## PRINTS THE FAILED VALUES
# Common reasons for fails : connected to circular link (INPUT ERROR)
fails_path = "/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/fails";
g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
networkPlot(g, fails_path, plot_fails, "MAC")

# SAVES THE GOOD VALUES (HORRAY!)
each_node_energy_path = "/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/each_node_energy.csv"
to_csv(each_node_energy_path, data_to_save, "node_id,net_kWh/af")
g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
Energysubnet(g, each_node_energy_path[1:end-4], reverseFacilityHash, nrg, "MAC")


# Make Spatial Data
path_to_utilities_data = "/Users/Mike/Google Drive/Shared Mike and Jenn/visualization data/utilitylatlong.csv"
(U, uHeaders) = readdlm(path_to_utilities_data, ',', header=true);

UtilLocs = Dict();
i = 1
while i < length(U[:,1])
  UtilLocs[U[i,3]] = [U[i,5], U[i,6], U[i,7], U[i,8]]
  i+=1
end

data_to_save = Array{Any}(0,6)
for k in keys(nrg)
  a = get!(UtilLocs, k, ["" ,"","",""]) # If no lat long found, default to empty strings
  data_to_save = [data_to_save; k nrg[k] a[1] a[2] a[3] a[4]];
end

path_to_utilities_maps = "/Users/Mike/Google Drive/Shared Mike and Jenn/Map Data/utility_energy.csv"
to_csv(path_to_utilities_maps, data_to_save, "utility,net_kWh/af, latitude, longitude")

## Group by region
energy = convert(DataFrame, data_to_save);
rename!(energy, :x2, :kwh)
rename!(energy, :x1, :utility)
rename!(energy, :x5, :huc4)
rename!(energy, :x6, :huc_name)
writetable("/Users/Mike/Google Drive/Shared Mike and Jenn/visualization data/energy_by_regions_full.csv", energy)
a = aggregate(groupby(energy[:,  [:huc_name, :kwh]], [:huc_name]), [mean]);
writetable("/Users/Mike/Google Drive/Shared Mike and Jenn/visualization data/energy_by_regions.csv", a)





# !!!!!!!!!!!!!!  TEST SPACE !!!!!!!!!!!!!!
"""
Use This Code to check the energy footprint of any node.
"""
(F, fHeaders) = readdlm(path_to_links_data, ',', header=true);
F = QuickFilterTemp(F, 2010.0);
g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
path_to_graph_plus_name = "/Users/Mike/Google Drive/Shared Mike and Jenn/Model Debug/check network"

_look_this_up = "1803083E";
s = GetSubGraph_UP(g, [facilityHash[_look_this_up]], reverseFacilityHash, FlowHash);
UnitCosts, d = QuantifyUnitImpacts(s.F, "MAC")
fixtoprob = Dict(zip(UnitCosts[:,1], UnitCosts[:,2]));

# Print Answer
println(_look_this_up, ": ", round(fixtoprob[_look_this_up], 2))

# Plot SubMap
Energysubnet(s.g, path_to_graph_plus_name, s.reverseFacilityHash, fixtoprob,"MAC")
networkPlot2(s.g, path_to_graph_plus_name, s.reverseFacilityHash,s.FlowHash, true, "MAC")
# !!!!!!!!!!!!!! END TEST SPACE !!!!!!!!!!!!!!
