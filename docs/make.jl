
using Documenter: Documenter, deploydocs, makedocs, DocMeta.setdocmeta!
using Luxor:
    Drawing, Point, circle, finish, julia_blue, julia_green,
    julia_purple, julia_red, ngon, origin, rotate, sethue
using Speculator

const assets = joinpath(@__DIR__, "source", "assets")
const repetitions = 4

mkpath(assets)

Drawing(400, 400, :svg, joinpath(assets, "logo.svg"))
origin()
rotate(-π / 2)

for ((i, point), color) in zip(enumerate(ngon(Point(0, 0), 150, 12; vertices = true)), repeat([
   julia_purple, julia_green, julia_red, julia_blue
], 3))
   sethue(color)
   circle(point, 2i + 8; action = :fill)
end

finish()

setdocmeta!(Speculator, :DocTestSetup, :(using Speculator))

makedocs(; modules = [Speculator], format = Documenter.HTML(; edit_link = "main"), pages = [
    "Speculator.jl" => "index.md", "References" => "references.md"
], sitename = "Speculator.jl", source = "source")

deploydocs(; devurl = "development", repo = "github.com/jakobjpeters/Speculator.jl.git")
