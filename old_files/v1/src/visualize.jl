using Graphs
"""
See Graphviz for colors: http://www.graphviz.org/doc/info/colors.html
"""

function networkPlot(g::AbstractGraph, title::AbstractString, nodes::Array=[], mode::AbstractString="PC")
  f = open("$title.dot", "w")
  count = 0
  for ln in split(to_dot(g), "\n")
      if count in nodes
        # Node Formatting
        write(f, string(string(ln)," [style=filled, color=cornsilk2]\n"))
      elseif contains(ln, "PD")
        write(f, string(string(ln)," [style=filled, color=cornsilk2]\n"))
      else
        write(f, string(ln,"\n"))
      end
      count+=1
  end
  close(f)

  if mode =="MAC"
    # Add layouts: -Kfdp; -Kneato; -
    run(`/usr/local/bin/dot -Tpdf $title.dot -Kdot  -o $title.pdf`);
    run(`open -a /Applications/Preview.app/ $title.pdf`)
  end
end

function ColorNodes(f::Any, ln::Any, agent::AbstractString)
  if length(agent) <2
    # Errors
    write(f, string(ln,"\n"))
  elseif contains(agent, "PD")
    #Distribution
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=slategray2]\n"))
  elseif contains(SubString(agent, 1, 3), "GW")
    # Groundwater
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=orchid1]\n"))
  elseif contains(agent[end:end], "E") #Only last character
    # Utility that Pumps Groundwater
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=gold]\n"))
  elseif contains(agent[end-1:end], "GW") #Only last two characters
    # Utility that Pumps Groundwater
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=palevioletred]\n"))
  elseif contains(agent[end-1:end], "MP") #Only last two characters
    # Utility that Pumps Groundwater
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=bisque]\n"))
  elseif contains(agent[1:2], "cW") #Only fist two characters
    # Recycled Water?
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=palegreen]\n"))
  elseif contains(agent, "REC") # All characters
    # Recycled Water?
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=mediumseagreen]\n"))
  elseif contains(agent[end-1:end], "SW")
    # Recycled Water?
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=lightyellow3]\n"))
  elseif contains(agent, "SW")
    # Recycled Water?
    write(f, string(string(ln)," [label=\"$agent\", style=filled, color=cornsilk2]\n"))
  else
    write(f, string(string(ln),"[label=\"$agent\"]\n"))
  end
end

function networkPlot2(g::AbstractGraph, title::AbstractString, revfachsh::Dict, flhash::Dict, showLinkData::Bool=true, mode::AbstractString="PC")
  f = open("$title.dot", "w")
  count = 0
  for ln in split(to_dot(g), "\n")
      if haskey(revfachsh, count)
        agent = string(revfachsh[count])
        ColorNodes(f, ln, agent)
      elseif contains(ln, "->") && showLinkData
          # Link Formatting
          od = [parse(Int, n) for n in split(ln, " -> ")]
          T = [(target(e,g),edge_index(e,g)) for e in out_edges(od[1],g)]
          for t in T
            if t[1]==od[2]
              vol = flhash[t[2]]
              write(f, string(ln," [label=\"$vol\", splines=polyline]\n"))
            end
          end
      else
        write(f, string(ln,"\n"))
      end
      count+=1
  end
  close(f)

  if mode =="MAC"
    # Add layouts: -Kfdp; -Kneato; -
    run(`/usr/local/bin/dot -Tpdf $title.dot -Kdot  -o $title.pdf`);
    run(`open -a /Applications/Preview.app/ $title.pdf`)
  end
end

function CAsubnet(g::AbstractGraph, searchid::Any, title::AbstractString, revfachsh::Dict, flhash::Dict, mode::AbstractString="PC", showLinkData::Bool=true)
  f = open("$title.dot", "w")
  count = 0
  for ln in split(to_dot(g), "\n")
      if haskey(revfachsh, count)
        # Node Formatting
        agent = string(revfachsh[count])
        ColorNodes(f, ln, agent)

      elseif contains(ln, "->") && showLinkData
        # Link Formatting
        od = [parse(Int, n) for n in split(ln, " -> ")]
        T = [(target(e,g),edge_index(e,g)) for e in out_edges(od[1],g)]
        for t in T
          if t[1]==od[2]
            vol = flhash[t[2]]
            write(f, string(ln," [label=\"$vol\", splines=polyline]\n"))
          end
        end

      else
        write(f, string(ln,"\n"))
      end
      count+=1
  end
  close(f)

  if mode =="MAC"
    # Add layouts: -Kfdp; -Kneato; -
    run(`/usr/local/bin/dot -Tpdf $title.dot -Kdot  -o $title.pdf`);
    run(`open -a /Applications/Preview.app/ $title.pdf`)
  end
end


maprange(s, a, b) = let a1 = minimum(a), a2 = maximum(a), b1 = minimum(b), b2 = maximum(b)
    round(Int, b1 + (s-a1) * (b2-b1) / (a2-a1))
end

function Energysubnet(g::AbstractGraph, titlepath::AbstractString, revfachsh::Dict, nrgDict::Dict ,mode::AbstractString="PC")
  cval = ["springgreen4","springgreen3","olivedrab1","darkgoldenrod1","brown1","firebrick3"]

  f = open("$titlepath.dot", "w")
  count = 0
  for ln in split(to_dot(g), "\n")
      if haskey(revfachsh, count)
        # Node Formatting
        agent = string(revfachsh[count])
        if haskey(nrgDict, agent)
          val = round(Int, nrgDict[agent])
          col = cval[maprange(val, 0:6000, 1:6)]
          write(f, string(string(ln)," [label=\"$agent, $val\", style=filled, color=$col]\n"))
        else
          write(f, string(string(ln)," [label=\"$agent\"]\n")) # Delete if you want white's blank
        end
      else
        write(f, string(ln,"\n"))
      end
      count+=1
  end
  close(f)

  if mode =="MAC"
    # Add layouts: -Kfdp; -Kneato; -
    run(`/usr/local/bin/dot -Tpdf $titlepath.dot -Kdot  -o $titlepath.pdf`);
    run(`open -a /Applications/Preview.app/ $titlepath.pdf`)
  end
end
