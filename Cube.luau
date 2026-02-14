local Module = {}

local SideVertical = {1, 0, 3, 5}
local FrontVertical = {2, 0, 4, 5}
local Horizontal = {1, 2, 3, 4}

local FacesValue = {"W", "O", "G", "R", "B", "Y"} 

local Write = buffer.writei8
local Read = buffer.readi8

local function CopyBuffer(Buffer)
	local BufferSize = buffer.len(Buffer)

	local NewBuffer = buffer.create(BufferSize)
	buffer.copy(NewBuffer, 0, Buffer, 0, BufferSize)

	return NewBuffer
end

local function GetCubeSize(Cube)
	return math.sqrt(buffer.len(Cube) / 6)
end

local function GetOffset(Size, Face, X, Y)
	return Face * Size ^ 2 + Y * Size + X
end

Module.GetOffset = GetOffset
Module.GetCubeSize = GetCubeSize

function Module.CubeToString(Cube: buffer, ToLetters: boolean)
	local String = ""

	for Offset=0, buffer.len(Cube) - 1 do
		String ..= ToLetters and FacesValue[Read(Cube, Offset) + 1] or Offset
	end

	return String
end

function Module.PrintCube(Cube: buffer, ToLetters: boolean)
	local CubeSize = GetCubeSize(Cube)
	local FaceSize = CubeSize ^ 2
	
	local String = ""
	
	for Offset=0, FaceSize * 6 - 1 do
		local Side = Offset < FaceSize and 0
		Side = Side or (Offset > FaceSize * 5 - 1 and 5)
		Side = Side or (math.floor((Offset - FaceSize) / CubeSize) % 4) + 1
		
		local Point = (Side == 0 or Side == 5)

		local X = Offset % CubeSize
		local Y = Point and math.floor((Offset % FaceSize) / CubeSize)
		Y = Y or math.floor((Offset - FaceSize) / (CubeSize * 4))

		if Point and X == 0 then
			String ..= "\n" .. string.rep("  ", CubeSize)
		elseif not Point and (Offset - FaceSize) % (CubeSize * 4) == 0 then
			String ..= "\n"
		end 
		
		local Value = Read(
			Cube,
			GetOffset(CubeSize, Side, X, Y)
		)
		
		String ..= (ToLetters and FacesValue[Value + 1] or Value) .. " "
	end
	
	print(String)
end

function Module.RotateFace(Cube, Side, Size, Clockwise)
	local PieceSize = math.floor(Size)
	local CubeWidth = Size ^ 2
	local Offset = Side * CubeWidth
	
	local FaceCopy = buffer.create(CubeWidth)
	buffer.copy(FaceCopy, 0, Cube, Offset, CubeWidth)

	for Row=1, PieceSize do
		for Column=1, PieceSize do
			local OldPos = ((Row - 1) * PieceSize + (Column - 1))
			local NewPos = Offset + (Clockwise and 
				((Column * PieceSize) - Row) or
				((PieceSize - Column) * PieceSize + Row) - 1)
			
			Write(Cube, NewPos, Read(FaceCopy, OldPos))
		end
	end
end

Module[1] = function(Offset, Side, Level, CubeSize) -- side vertical
	local Sideway = Side == 0 or Side == 5

	CubeSize -= 1

	Offset = (Side == 5 or Side == 1) and CubeSize - Offset or Offset
	Level = Side < 2 and Level or CubeSize - Level

	return Sideway and Offset or Level, 
		Sideway and Level or Offset
end

Module[2] = function(Offset, Side, Level, CubeSize) -- vertical
	CubeSize -= 1

	return Side == 4 and CubeSize - Level or Level,
		Side == 4 and CubeSize - Offset or Offset
end

Module[3] = function(Offset, Side, Level, CubeSize) -- horizontal
	return Offset, Level
end

function Module.MoveCube(Cube: buffer, Side: number, Level: number, Sideway: boolean, Direction: number)
	local MovedCube = CopyBuffer(Cube)
	local CubeSize = GetCubeSize(Cube)

	if Side == 0 or Side == 5 then
		if Side == 5 then
			Level = CubeSize - 1 - Level
		end
		
		Side = Sideway and 1 or 2
		Sideway = false
	end
	
	if not Sideway and Side > 2 then
		Level = CubeSize - 1 - Level
	end
	Side = (Side - 1) % 2 + 1

	local IsHorizontal = (Side > 0 or Side < 5) and Sideway

	local Line = (IsHorizontal and Horizontal) or (Side == 1 and SideVertical or FrontVertical)
	local StripCalculation = ((IsHorizontal and 3) or (Side == 1 and 1 or 2))

	Level = IsHorizontal and Level or Side <= 2 and Level or CubeSize - 1 - Level

	if Level == 0 or Level == CubeSize - 1 then
		local FaceDirection = Direction < 0
		local RotatingSide

		if IsHorizontal then
			RotatingSide = Level == 0 and 0 or 5
		elseif Side == 1 then 
			RotatingSide  = Level == 0 and 4 or 2
		else
			RotatingSide = Level == 0 and 1 or 3
		end

		for i=1, math.abs(Direction) do
			Module.RotateFace(
				MovedCube, 
				RotatingSide,
				CubeSize, 
				Level == 0 and FaceDirection or Level == CubeSize - 1 and not FaceDirection
			)
		end
	end

	for i, SideToMove in Line do
		local NeighborFace = Line[(table.find(Line, SideToMove) + Direction - 1) % 4 + 1]

		for Offset=0, CubeSize - 1 do
			local OldPos = GetOffset(CubeSize, SideToMove,
				Module[StripCalculation](Offset, SideToMove, Level, CubeSize)
			)

			local NewPos = GetOffset(CubeSize, NeighborFace,
				Module[StripCalculation](Offset, NeighborFace, Level, CubeSize)
			)

			Write(MovedCube, NewPos, Read(Cube, OldPos))
		end
	end

	return MovedCube
end


function Module.SetNewMiddle(Cube, Side, Direction)
	Direction = Direction or 1
	
	local CubeSize = GetCubeSize(Cube)
	local MovedCube = CopyBuffer(Cube)

	if Side == 2 then
		return MovedCube
	end
	
	for Level=0, CubeSize - 1 do
		if Side == 0 then
			MovedCube = Module.MoveCube(MovedCube, 0, Level, false, -1 * Direction)
		elseif Side == 1 then
			MovedCube = Module.MoveCube(MovedCube, 1, Level, true, 1 * Direction)
		elseif Side == 3 then
			MovedCube = Module.MoveCube(MovedCube, 1, Level, true, -1 * Direction)
		elseif Side == 4 then
			MovedCube = Module.MoveCube(MovedCube, 1, Level, true, -2 * Direction)
		elseif Side == 5 then
			MovedCube = Module.MoveCube(MovedCube, 0, Level, false, 1 * Direction)
		end
	end

	return MovedCube
end

function Module.DoNotation(Cube: buffer, Notation: 
	"U" | "D" | "R" | "L" | "F" | "B" | 
	"U'" | "D'" | "R'" | "L'" | "F'" | "B'" | 
	string)
	
	local Side, Level, Sideway, Direction
	
	local Reverse = string.sub(Notation, #Notation, #Notation) == "'"
	
	local CubeSize = GetCubeSize(Cube)
	local Edge = CubeSize - 1
	
	local Double = false
	
	if string.lower(Notation) == Notation then
		Double = true
		Notation = string.upper(Notation)
	end
	
	Direction = tonumber(string.sub(Notation, 2, 2)) or 1
	
	if Direction > 1 then
		Notation = string.sub(Notation, 1, 1)
	end

	if Reverse then
		Notation = string.sub(Notation, 1, #Notation - 1)
	end
	
	if Notation == "U" then
		Side, Level, Sideway, Direction = 1, 0, true, -1 * Direction
	elseif Notation == "D" then
		Side, Level, Sideway, Direction = 1, Edge, true, 1 * Direction
	elseif Notation == "R" then
		Side, Level, Sideway, Direction = 2, Edge, false, 1 * Direction
	elseif Notation == "L" then
		Side, Level, Sideway, Direction = 2, 0, false, -1 * Direction
	elseif Notation == "F" then
		Side, Level, Sideway, Direction = 1, Edge, false, 1 * Direction
	elseif Notation == "B" then
		Side, Level, Sideway, Direction = 1, 0, false, -1 * Direction
	elseif Notation ~= "x" or Notation ~= "y" or Notation ~= "z" then
		error(`{Notation} is not a thing yet`)
	end
	
	if Reverse then
		Direction = -Direction
	end

	if Notation == "x" then
		return Module.SetNewMiddle(Cube, 5, Direction)
	elseif Notation == "y" then
		return Module.SetNewMiddle(Cube, 3, Direction)
	elseif Notation == "z" then
		return Module.SetNewMiddle(Cube, 1, Direction)
	end
	
	local MovedCube = Module.MoveCube(Cube, Side, Level, Sideway, Direction)
	
	if Double then
		if Level == 0 then
			Level += 1
		elseif Level == Edge then
			Level -= 1
		end
		
		MovedCube = Module.MoveCube(Cube, Side, Level, Sideway, Direction)
	end
		
	return MovedCube
end

function Module.CreateCube(Size: number, State: string?)
	local Cube = buffer.create(Size ^ 2 * 6)
	
	for Side=0, 5 do
		for Offset=1, Size ^ 2 do
			local Offset = (Side * Size ^ 2) + (Offset - 1)
			local StateColor = State and string.sub(State, Offset + 1, Offset + 1)
			
			Write(
				Cube, 
				Offset, 
				State and table.find(FacesValue, StateColor) - 1 or Side
			)
		end
	end

	return Cube
end

return Module
