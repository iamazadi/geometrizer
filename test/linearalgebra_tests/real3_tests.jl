u, v, w = ℝ³(rand(3)), ℝ³(rand(3)), ℝ³(rand(3))
zero = ℝ³([0.0; 0.0; 0.0])
α, β = rand(2)


@test isapprox(u + (v + w), (u + v) + w) # 1. associativity of addition
@test isapprox(u + v, v + u) # 2. commutativity of addition
@test isapprox(u + zero, u) # 3. the zero vector
@test isapprox(u - u, zero) # 4. the inverse element
@test isapprox(α * (u + v), α * u + α * v) # 5. distributivity Ι
@test isapprox((α + β) * u, α * u + β * u) # 6. distributivity ΙΙ
@test isapprox(α * (β * u), (α * β) * u) # 7. associativity of scalar multiplication
@test isapprox(1u, u) # 8. the unit scalar 1