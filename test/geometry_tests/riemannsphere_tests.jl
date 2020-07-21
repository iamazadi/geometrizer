p = convert(Complex, Complex(100rand(), 100rand()))
p̅ = conj(p)
z = ComplexPlane([p; p̅])
s = Spherical(z)
c = Cartesian(z)
g = Geographic(z)
r = ℝ³(1, 0, 0)


@test isapprox(z, ComplexPlane(s))
@test isapprox(z, ComplexPlane(c))
@test isapprox(z, ComplexPlane(g))
@test isapprox(s, Spherical(c))
@test isapprox(s, Spherical(g))
@test isapprox(c, Cartesian(s))
@test isapprox(c, Cartesian(g))
@test isapprox(g, Geographic(s))
@test isapprox(g, Geographic(c))

@test isapprox(ℝ³(z), ℝ³(c))
@test isapprox(ComplexPlane(r), ComplexPlane(Cartesian(r)))
