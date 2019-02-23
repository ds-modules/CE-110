using Gadfly
using DataFrames

function histo(data::Any, path_to_save::AbstractString, col::AbstractString="x2", keep_zeros::Bool=false)
  df = convert(DataFrame, data);

  myplot = Gadfly.plot(df[df[:x2] .> -0., :], x="x2", Geom.histogram)

  Gadfly.draw(Gadfly.PNG(path_to_save, 3inch, 3inch), myplot)
end
