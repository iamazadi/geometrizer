using LinearAlgebra
using FileIO
using Colors
using AbstractPlotting
using Makie
using CSV
using StatsBase
using ReferenceFrameRotations
using Porta


"""
sample(dataframe, max)

Samples points from a dataframe with the given dataframe and the maximum number
of samples limit. The second column of the dataframe should contain longitudes
and the third one latitudes (in degrees.)
"""
function sample(dataframe, max)
    total_longitudes = dataframe[dataframe[:shapeid].<0.1, 2] ./ 180 .* pi
    total_latitudes = dataframe[dataframe[:shapeid].<0.1, 3] ./ 180 .* pi
    sampled_longitudes = Array{Float64}(undef, max)
    sampled_latitudes = Array{Float64}(undef, max)
    count = length(total_longitudes)
    if count > max
        sample!(total_longitudes,
                sampled_longitudes,
                replace=false,
                ordered=true)
        sample!(total_latitudes,
                sampled_latitudes,
                replace=false,
                ordered=true)
        longitudes = sampled_longitudes
        latitudes = sampled_latitudes
    else
        longitudes = total_longitudes
        latitudes = total_latitudes
    end
    count = length(longitudes)
    points = Array{Float64}(undef, count, 2)
    for i in 1:count
        points[i, :] = [longitudes[i], latitudes[i]]
    end
    points
end


"""
π(z, w)

Sends a point on a unit 3-sphere to a point on a unit 2-sphere with the given
complex numbers representing a unit quaternion. S³ ↦ S² (x,y,z)
"""
function π(z, w)
    x₁ = real(z)
    x₂ = imag(z)
    x₃ = real(w)
    x₄ = imag(w)
    [2(x₁*x₃ + x₂*x₄), 2(x₂*x₃ - x₁*x₄), x₁^2+x₂^2-x₃^2-x₄^2]
end


"""
σ(ϕ, θ; β=0)

Sends a point on a 2-sphere to a point on a 3-sphere with the given longitude
and latitude coordinate in radians. S² ↦ S³
"""
function σ(ϕ, θ; β=0)
    exp(-im * (β + ϕ)) * sqrt((1 + sin(θ)) / 2), sqrt((1 - sin(θ)) / 2)
end


"""
τ(ϕ, θ; β=0)

Sends a point on a 2-sphere to a point on a 3-sphere with the given longitude
and latitude coordinate in radians. S² ↦ S³
"""
function τ(ϕ, θ; β=0)
    sqrt((1 + sin(θ)) / 2), exp(im * (β + ϕ)) * sqrt((1 - sin(θ)) / 2)
end


"""
S¹action(α, z, w)

Performs a group action corresponding to moving along the circumference of a
circle with the given angle and the complex numbers representing a unit
quaternion on a 3-sphere.
"""
function S¹action(α, z, w)
    exp(im * α) * z, exp(im * α) * w
end


"""
λ(z, w)

Sends a point on a 3-sphere to a point in the plane x₄=0 with the given complex
numbers representing a unit quaternion. This is the stereographic projection.
S³ ↦ R³
"""
function λ(z, w)
    [real(z), imag(z), real(w)] ./ (1 - imag(w))
end


"""
get_manifold(points, segments, distance, cut)

Calculates a grid of points in R³ for constructing a surface in a specific way
with the given points in the base space (a 2-sphere,) the number of cross
sections, the distance from the z axis and the angle that determines how much
of the grid is the leftover after the cut.
"""
function get_manifold(points, segments, distance, cut)
    samples = size(points, 1)
    leftover_segments = Integer(floor((cut / 2pi) * segments))
    manifold_segments = segments - leftover_segments
    manifold = Array{Float64}(undef, manifold_segments, samples, 3)
    leftover = Array{Float64}(undef, leftover_segments, samples, 3)
    α = (2pi-cut) / (manifold_segments-1)
    γ = cut / (leftover_segments-1)
    for i in 1:samples
            ϕ, θ = points[i, :]
        z, w = σ(ϕ, -θ)
        for j in 1:segments
            if j ≤ manifold_segments
                x₁ = (real(z) + distance) * sin(α*(j-1))
                x₂ = (real(z) + distance) * cos(α*(j-1))
                x₃ = imag(z)
                manifold[j, i, :] = [x₁, x₂, x₃]
                if j != manifold_segments
                    z, w = S¹action(α, z, w)
                end
            else
                index = j-manifold_segments
                x₁ = (real(z) + distance) * sin((2pi-cut)+γ*(index-1))
                x₂ = (real(z) + distance) * cos((2pi-cut)+γ*(index-1))
                x₃ = imag(z)
                leftover[index, i, :] = [x₁, x₂, x₃]
                z, w = S¹action(γ, z, w)
            end
        end
    end
    manifold, leftover
end

# The scene object that contains other visual objects
universe = Scene(backgroundcolor = :black, show_axis=false)
# Use a slider for rotating the base space in an interactive way
sg, og = textslider(0:0.05:2pi, "g", start = 0)

# The maximum number of points to sample from the dataset for each country
max_samples = 300
# The number of cross sections for constructing a manifold
segments = 90
# Made with Natural Earth.
# Free vector and raster map data @ naturalearthdata.com.
countries = Dict("iran" => [1.0, 0.0, 0.0], # red
                 "us" => [0.494, 1.0, 0.0], # green
                 "china" => [1.0, 0.639, 0.0], # orange
                 "ukraine" => [0.0, 0.894, 1.0], # cyan
                 "australia" => [1.0, 0.804, 0.0], # orange
                 "germany" => [0.914, 0.0, 1.0], # purple
                 "israel" => [0.0, 1.0, 0.075]) # green
# The path to the dataset
path = "data/natural_earth_vector"
# The angle to cut the manifolds for a better visualization
cut = 2pi/360*80
# The distance from the z axis
distance = 2
# Construct a manifold for each country in the dictionary
for country in countries
    dataframe = CSV.read(joinpath(path, "$(country[1])-nodes.csv"))
    points = sample(dataframe, max_samples)
    samples = size(points, 1)
    specific = RGBAf0(country[2]..., 1.0)
    ghost = RGBAf0(country[2]..., 0.5)
    inverse = RGBAf0((1 .- country[2])..., 1.0)
    
    rotated = @lift begin
        R = similar(points)
        for i in 1:samples
                  ϕ, θ = points[i, :]
            R[i, :] = [ϕ + $og, θ]
        end
        R
    end
    
    leftover_segments = Integer(floor((cut / 2pi) * segments))
    manifold_segments = segments - leftover_segments
    manifold_color = fill(specific, manifold_segments, samples)
    manifolds = @lift(get_manifold($rotated, segments, distance, cut))
    manifold = @lift($manifolds[1])
    surface!(universe,
             @lift($manifold[:, :, 1]),
             @lift($manifold[:, :, 2]),
             @lift($manifold[:, :, 3]),
             color = manifold_color)
    if country[1] in ["iran", "us", "australia"]
        ghost_color = fill(ghost, leftover_segments, samples)
        leftover = @lift($manifolds[2])
        surface!(universe,
                 @lift($leftover[:, :, 1]),
                 @lift($leftover[:, :, 2]),
                 @lift($leftover[:, :, 3]),
                 color = ghost_color,
                 transparency = true)
     end
end

# Construct the 2 disks that show the base map
disk_segments = 20
disk_samples = 60
# Parameters for aligning the base map and the fibers
longitude_align = -pi/2
latitude_align = 0.35
lspace = range(0, stop = 2pi, length = disk_samples)
disk1 = @lift begin
    p = Array{Float64}(undef, disk_segments, disk_samples, 3)
    for i in 1:disk_segments
        p[i, :, 1] = [0 for j in lspace]
        p[i, :, 2] = [(i+latitude_align)/disk_segments*
                      sin(j+$og+longitude_align) + distance for j in lspace]
        p[i, :, 3] = [(i+latitude_align)/disk_segments*
                      cos(j+$og+longitude_align) for j in lspace]
    end
    p
end

disk2 = @lift begin
    p = Array{Float64}(undef, disk_segments, disk_samples, 3)
    for i in 1:disk_segments
        p[i, :, 1] = [((i+latitude_align)/disk_segments*
                       sin(j+$og+longitude_align+cut)+distance)*sin(2pi-cut)
                      for j in lspace]
        p[i, :, 2] = [((i+latitude_align)/disk_segments*
                       sin(j+$og+longitude_align+cut)+distance)*cos(2pi-cut)
                      for j in lspace]
        p[i, :, 3] = [(i+latitude_align)/disk_segments*
                      cos(j+$og+longitude_align+cut) for j in lspace]
    end
    p
end

# Construct the 2 disks that show the guidance grid
grid1 = @lift begin
    p = Array{Float64}(undef, disk_segments, disk_samples, 3)
    for i in 1:disk_segments
        p[i, :, 1] = [0 for j in lspace]
        p[i, :, 2] = [2i/disk_segments*sin(j+$og+longitude_align)+distance
                      for j in lspace]
        p[i, :, 3] = [2i/disk_segments*cos(j+$og+longitude_align)
                      for j in lspace]
    end
    p
end

grid2 = @lift begin
    p = Array{Float64}(undef, disk_segments, disk_samples, 3)
    for i in 1:disk_segments
        p[i, :, 1] = [(2i/disk_segments*
                       sin(j+$og+longitude_align+cut)+distance)*sin(2pi-cut)
                      for j in lspace]
        p[i, :, 2] = [(2i/disk_segments*
                       sin(j+$og+longitude_align+cut)+distance)*cos(2pi-cut)
                      for j in lspace]
        p[i, :, 3] = [2i/disk_segments*cos(j+$og+longitude_align+cut)
                      for j in lspace]
    end
    p
end

base_image = load("data/BaseMap.png")
grid_image = load("data/boqugrid.png")

surface!(universe,
         @lift($disk1[:, :, 1]),
         @lift($disk1[:, :, 2]),
         @lift($disk1[:, :, 3]),
         color = base_image,
         transparency = false,
         shading = false)
         
surface!(universe,
         @lift($disk2[:, :, 1]),
         @lift($disk2[:, :, 2]),
         @lift($disk2[:, :, 3]),
         color = base_image,
         transparency = false,
         shading = false)

surface!(universe,
         @lift($grid1[:, :, 1]),
         @lift($grid1[:, :, 2]),
         @lift($grid1[:, :, 3]),
         color = grid_image,
         transparency = false,
         shading = false)

surface!(universe,
         @lift($grid2[:, :, 1]),
         @lift($grid2[:, :, 2]),
         @lift($grid2[:, :, 3]),
         color = grid_image,
         transparency = false,
         shading = false)

# Instantiate a horizontal box for holding the visuals and the controls
scene = hbox(universe,
             vbox(sg),
             parent = Scene(resolution = (400, 400)))

# update eye position
eye_position, lookat, upvector = Vec3f0(-4, 4, 4), Vec3f0(0), Vec3f0(0, 0, 1.0)
update_cam!(universe, eye_position, lookat)
universe.center = false # prevent scene from recentering on display

# Add stars to the scene to fill the background with something
stars = 10_000
scatter!(
    universe,
    map(i-> (randn(Point3f0) .- 0.5) .* 10, 1:stars),
    glowwidth = 1, glowcolor = (:white, 0.1), color = rand(stars),
    colormap = [(:white, 0.4), (:blue, 0.4), (:gold, 0.4)],
    markersize = rand(range(0.0001, stop = 0.025, length = 100), stars),
    show_axis = false, transparency = true
)

record(universe, "planet.gif") do io
    frames = 100
    for i in 1:frames
        og[] = i*2pi/frames # animate scene
        rotate_cam!(universe, 4pi/frames, 0.0, 0.0)
        recordframe!(io) # record a new frame
    end
end
