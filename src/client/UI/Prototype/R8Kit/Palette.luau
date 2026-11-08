--!strict
-- R8Kit.Palette (Lane 3 Round 8): the colours of the two upgrade cards, from GENERATION-NOTES' palette (cream #FFF4DA, navy
-- #14213F, red #E74843, kerb white #FFF8EE, glossy orange, green #49C857, gold #F7C64C) and the pixel samples of R8-IMG-01.
--   local P = Palette   P.Navy, P.Cream, ...

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

return table.freeze({
	Navy = rgb(20, 33, 63), -- #14213F outlines and text
	NavyDeep = rgb(11, 22, 53), -- #0B1635 the darkest outline
	Cream = rgb(250, 235, 217), -- #FAEBD9 the card panel
	CreamLight = rgb(255, 244, 218), -- #FFF4DA
	CreamShade = rgb(236, 214, 184), -- inner edge of a pill
	Red = rgb(231, 72, 67), -- #E74843
	RedBright = rgb(253, 40, 54), -- #FD2836
	RedDeep = rgb(170, 28, 38),
	White = rgb(255, 248, 238), -- #FFF8EE kerb white
	OrangeTop = rgb(255, 178, 58), -- #FFB23A
	OrangeMid = rgb(253, 155, 37), -- #FD9B25 (sample)
	OrangeBottom = rgb(244, 119, 22), -- #F47716
	Green = rgb(73, 200, 87), -- #49C857
	GreenLight = rgb(134, 242, 60), -- the lime top of the big numbers
	GreenDeep = rgb(26, 150, 52),
	Gold = rgb(247, 198, 76), -- #F7C64C
	GoldBright = rgb(255, 227, 37), -- #FFE325 (sample)
	GoldDeep = rgb(214, 148, 20),
	GreyTop = rgb(212, 215, 224),
	GreyBottom = rgb(150, 154, 166), -- the cannot-afford button
	Grey = rgb(162, 165, 174), -- #A2A5AE empty pip
	Asphalt = rgb(51, 57, 67), -- #333943
	Chrome = rgb(169, 179, 203), -- #A9B3CB bezel bolts
	Yellow = rgb(255, 218, 25), -- #FFDA19
	Blue = rgb(8, 104, 228), -- #0868E4
	Sky = rgb(120, 196, 255),
	Danger = rgb(229, 72, 77),
})
