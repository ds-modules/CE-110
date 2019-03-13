using Graphs
using DataFrames
"""
Simple Water Supply (SWS)
Created By: Mike Taptich, Ph.D.
Date: 2016
"""

type SubGraph <: Any
  g::AbstractGraph
  F::Array
  facilityHash::Dict{Any,Any}
  reverseFacilityHash::Dict{Any,Any}
  FlowHash::Dict{Any,Any}
end

# Core Functions
function QuickFilterTemp(Flows::Array, YearTag::Any)

  Flows = Flows[(Flows[:,1]/100 .> YearTag)&(Flows[:,1]/100 .< (YearTag+1))&(Flows[:,4] .> 0.0),:];

  df = convert(DataFrame, Flows);
  t = aggregate(groupby(df[:,1:6], [:x1,:x2, :x3]), [sum, mean]); # Sum volumes and average energy
  t = t[:, filter(x -> (x in [:x1, :x2, :x3, :x4_sum, :x5_mean, :x6_mean]), names(t))]; # keep correct columns
  return convert(Array, t);
end

function NotinMat(x,y)
  check = true
  for idx=1:size(y)[1]
    if x == y[idx,:]
      check = false
    end
  end
  return check
end

function to_csv(file_path::AbstractString, data, header::AbstractString)
  open(file_path, "w") do f
    write(f, "$header\n")
    writedlm(f, data, ',')
  end
end

# Project Builds
function buildGraph(Facilities::Array)
  # Create functions that map input objects to variable indices
  facility_state = 0
  facility_idx() = facility_state += 1

  # Map object identifiers to decision variables
  facilityHash = Dict();
  reverseFacilityHash = Dict();
  FlowHash = Dict{Int64,Tuple}();

  # Get node dimensions and initialize graph
  global n_fac = length(unique(Facilities[:,2:3]));
  g = simple_graph(n_fac);

  # Build graph and update hash tables
  e_id = 1;
  for rowidx = 1:size(Facilities)[1]
    r = Facilities[rowidx,:];

    s = get!(()->facility_idx(), facilityHash, r[2]); # source
    reverseFacilityHash[s] = r[2];

    t =  get!(()->facility_idx(), facilityHash, r[3]); # target
    reverseFacilityHash[t]= r[3];

    # Add edge to graph
    add_edge!(g, s, t);

    # Update Volume List
    FlowHash[e_id] = (r[4], [r[5], r[6]]); # volume
    e_id +=1;
  end

  return g, facilityHash, reverseFacilityHash, FlowHash
end

function IdentifyKeyFeatures(g::AbstractGraph)
  ## Identify Primary Sources, Terminal Demand, and Unquantified Nodes
  SourceTerminal = Dict("S" => [], "T"=> []);
  NodesToQuant = Int64[];
  Confirms = Dict{Int64, Float64}();
  for v in vertices(g)
    if isempty(in_edges(v,g))
      push!(SourceTerminal["S"], vertex_index(v,g)) # Prime Source of Water
      Confirms[vertex_index(v,g)] = 0.0
    elseif isempty(out_edges(v,g))
      push!(SourceTerminal["T"], vertex_index(v,g)) # Terminal Demand for Water
      push!(NodesToQuant, vertex_index(v,g))
    else
      push!(NodesToQuant, vertex_index(v,g))
    end
  end
  return SourceTerminal, NodesToQuant, Confirms
end

function GetSubGraph_UP(g::AbstractGraph, Queue::Array, revFacilityHash::Any, fHash::Any)
  AreadyChecked = [];
  c = Array{Any}(0,6);
  while !isempty(Queue)
    # Move to a new node
    current_node_id = shift!(Queue);
    InFlows = in_edges(vertices(g)[current_node_id], g); # get the edges flowing into ID

    # Analyze the edges flowing into the current node
    for inflow in InFlows
      # Get the source node id from in_edge
      up_node_id = source(inflow);

      # Extract original Data
      (v, (trans, treat)) = fHash[edge_index(inflow)]

      # Update log for new subgraph
      if NotinMat([1.0 revFacilityHash[up_node_id] revFacilityHash[current_node_id] v trans treat], c)
        c = [c ; 1.0 revFacilityHash[up_node_id] revFacilityHash[current_node_id] v trans treat]
      end

      # If the new node id hasn't been checked, then add it to our Queue
      if !(current_node_id in AreadyChecked)
        push!(Queue, up_node_id)
      end
    end

    # Add checked node to completed list
    push!(AreadyChecked, current_node_id)
  end

  # Build new graph
  subg, new_facilityHash, new_reverseFacilityHash, new_FlowHash =  buildGraph(c)

  # Return bundled data
  return SubGraph(subg, c, new_facilityHash, new_reverseFacilityHash, new_FlowHash)
end

function GetSubGraph_DOWN(g::AbstractGraph, Queue::Array, revFacilityHash::Any, fHash::Any)
  AreadyChecked = [];
  c = Array{Any}(0,6);
  while !isempty(Queue)
    # Move to a new node
    current_node_id = shift!(Queue);
    OutFlows = out_edges(vertices(g)[current_node_id], g);

    # Analyze the edges flowing out of the current node
    for outflow in OutFlows
      # Get the source node id from in_edge
      down_node_id = target(outflow);

      # Extract original Data
      (v, (trans, treat)) = fHash[edge_index(outflow)]

      # Update log for new subgraph
      if NotinMat([1.0 revFacilityHash[current_node_id] revFacilityHash[down_node_id] v trans treat], c)
        c = [c ; 1.0 revFacilityHash[current_node_id] revFacilityHash[down_node_id] v trans treat]
      end

      # If the new node id hasn't been checked, then add it to our Queue
      if !(current_node_id in AreadyChecked)
        push!(Queue, down_node_id)
      end
    end

    # Add checked node to completed list
    push!(AreadyChecked, current_node_id)
  end

  # Build new graph
  subg, new_facilityHash, new_reverseFacilityHash, new_FlowHash =  buildGraph(c)

  # Return bundled data
  return SubGraph(subg, c, new_facilityHash, new_reverseFacilityHash, new_FlowHash)
end


# Project Calculations
function BalenceNetwork(N::Array, C::Dict, F::Dict, g::AbstractGraph)
  """
  Estimate the average cost of water at each node by balencing the network sequentially.
  The status of a node is known if each of the influent nodes is previously known. Run
  as a recursion until NodesToQuant (N) is empty
  """
  verts = vertices(g);
  ids_to_delete = Any[];

  # For the vertices still left in the Queue
  for vID in N
    # Get the node ID from
    inflows = in_edges(verts[vID],g);

    # If the source of the inflow edge is confirmed, then execute.
    if issubset([source(e, g) for e in inflows], keys(C))
      flowVals = [(vertex_index(source(e,g), g),F[edge_index(e)]) for e in inflows];

      vol = 0;
      cost = 0;
      for f in flowVals
        id = f[1]; # Id of the source node
        d = f[2]; # (volume, [transmission, treatment])
        vol+= d[1]
        cost+= d[1] * ( sum(d[2]) + C[id] )

      end

      C[vID] = cost/vol;
      push!(ids_to_delete, vID)
    end

  end

  # Remove Id's that were we have the complted data
  for vID in ids_to_delete deleteat!(N, findin(N,vID)) end

  if isempty(N)
    return C
  else
    return BalenceNetwork(N, C, F, g)
  end
end

function QuantifyUnitImpacts(Facilities::Array, mode::AbstractString="MAC")
  ## Build the graph of the problem
  g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(Facilities);

  # Identify Primary Sources, Terminal Demand, and Unquantified Nodes
  SourceTerminal, NodesToQuant, Confirms = IdentifyKeyFeatures(g);

  # Sequentially Quantify the Unit Costs
  Confirms = BalenceNetwork(NodesToQuant, Confirms, FlowHash, g);

  # Remap the cost data to reflect the origin ID keys
  UnitCosts = Array{Float64}(0,2)
  for v in keys(Confirms)
    UnitCosts = [UnitCosts; reverseFacilityHash[v] Confirms[v]]
  end

  if mode == "MAC"
    #_console a check
    _chk = Array{Float64}(0,2)
    for cID in keys(Confirms)
      _chk = [_chk; reverseFacilityHash[cID] Confirms[cID]]
    end
    node_of_interest = "test";
    #to_csv("/Users/Mike/Desktop/QuantifyUnitImpacts_$node_of_interest.csv", _chk, "node,net_kWh/af")
  end


  return sortrows(UnitCosts, by=x->(x[2])), g
end

matchrow(a,B) = findfirst(i->all(j->a[j] == B[i,j],1:size(B,2)),1:size(B,1))

function BundledUnitCost(F::Any, IDS::Array, savetoCSV::Bool=false, save_path::AbstractString="")
  nrg = Dict()

  # Loops through the network and gets the energy calculations
  data_to_save = [];
  plot_fails = [];
  for searchid in IDS
    try
      g, facilityHash, reverseFacilityHash, FlowHash =buildGraph(F)
      s = GetSubGraph_UP(g, [facilityHash[searchid]], reverseFacilityHash, FlowHash);
      UnitCosts, _g = QuantifyUnitImpacts(s.F);
      sid_erg = UnitCosts[UnitCosts[:,1] .== searchid, :]
      nrg[sid_erg[1]] = sid_erg[2]
      push!(data_to_save,[searchid,UnitCosts[length(UnitCosts[:,1]),2]])
    catch
      println("ERROR: ", searchid)
      push!(plot_fails, facilityHash[searchid])
    end
  end

  # Save?
  if savetoCSV
    to_csv("$save_path energy bundle.csv", data_to_save, "node,net_kWh/af")
  end
  return nrg
end

function AssessUpstream(save_path::AbstractString, searchid::AbstractString, g::AbstractGraph, facHash::Any, revFacHash::Any, flHash::Any, mode::AbstractString="PC")
  s = GetSubGraph_UP(g, [facHash[searchid]], revFacHash, flHash);
  UnitCosts, g = QuantifyUnitImpacts(s.F);

  CAsubnet(s.g, searchid, "$save_path$searchid network", s.reverseFacilityHash, s.FlowHash, mode)

  to_csv("$save_path$searchid us_flows.csv", s.F, "blank,source,target,cum_volume_af,transmission_kwh/af,treatment_kwh/af")
  to_csv("$save_path$searchid energy.csv", UnitCosts, "node,net_kWh/af")
end


function ViewDownstream(save_path::AbstractString, searchid::AbstractString, g::AbstractGraph, facHash::Any, revFacHash::Any, flHash::Any, mode::AbstractString="PC")
  s = GetSubGraph_DOWN(g, [facHash[searchid]], revFacHash, flHash);
  CAsubnet(s.g, searchid, "$save_path$searchid network", s.reverseFacilityHash, s.FlowHash, mode)

  to_csv("$save_path$searchid ds_flows.csv", s.F, "blank,source,target,cum_volume_af,transmission_kwh/af,treatment_kwh/af")

  return unique(s.F[:,2:3])
end


function EnergySubNetwork(path_to_sub_path_save::AbstractString, searchid::AbstractString, g::AbstractGraph, facHash::Any, revFacHash::Any, flHash::Any, subonly::Bool=false, mode::AbstractString="PC")
  connects = ViewDownstream(path_to_sub_path_save, searchid, g, facHash, revFacHash, flHash);
  nrgList = BundledUnitCost(g, connects, facHash, revFacHash, flHash, true, path_to_sub_path_save);

  s = GetSubGraph_DOWN(g, [facHash[searchid]], revFacHash, flHash);
  if subonly
    Energysubnet(s.g, "$path_to_sub_path_save California_energy", s.reverseFacilityHash, nrgList, mode)
  else
    Energysubnet(g, "$path_to_sub_path_save California_energy", revFacHash, nrgList, mode)
  end
end
