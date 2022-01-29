using DynamicGrids, FreeTypeAbstraction, Test

@testset "Fonts" begin
	@test DynamicGrids.autofont() isa FreeTypeAbstraction.FTFont
	face = DynamicGrids.autofont()
	name = face.family_name
 	@testset "TextConfig accepts font as String" begin
		@test name isa String
		textconfig = TextConfig(; font=name)
		@test textconfig.face isa FreeTypeAbstraction.FTFont
	end
 	@testset "TextConfig accepts font as FTFont" begin
		@test face isa FreeTypeAbstraction.FTFont
		textconfig = TextConfig(; font=face)
		@test textconfig.face === face
	end
	@test_throws ArgumentError TextConfig(; font="not_a_font")
	@test_throws ArgumentError TextConfig(; font=:not_a_string)
end
