using DynamicGrids, Test

@testset "Fonts" begin
	@test_throws ArgumentError TextConfig(; font="not_a_font")
	@test_throws ArgumentError TextConfig(; font=:not_a_string)
end
