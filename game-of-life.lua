-- MIT License

-- Copyright (c) 2021 David Fletcher

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- GLOBALS
local BLACK = app.pixelColor.rgba(0, 0, 0)
local WHITE = app.pixelColor.rgba(255, 255, 255)

-- MAP FUNCTIONS
local function getNeighborOffsets(x, y, rows, cols)
    local up = -1
    local left = -1
    local down = 1
    local right = 1

    if (y == 1) then
        left = rows - 1
    end

    if (y == rows) then
        right = 1 - rows
    end

    if (x == 1) then
        up = cols - 1
    end

    if (x == cols) then
        down = 1 - cols
    end

    return up, down, left, right
end

local function initMap(rows, cols)
    local map = {}

    for i=1,cols do
        map[i] = {}
        for j=1,rows do
            map[i][j] = { state=false, neighbors=0 }
        end
    end

    return map
end

local function copyMap(map, rows, cols)
    local newMap = {}
    
    for i=1,cols do
        newMap[i] = {}
        for j=1,rows do
            newMap[i][j] = {}
            newMap[i][j].state = map[i][j].state
            newMap[i][j].neighbors = map[i][j].neighbors
        end
    end

    return newMap
end

local function setCel(map, x, y, rows, cols)
    map[x][y].state = true

    -- update neighbor counts
    up, down, left, right = getNeighborOffsets(x, y, rows, cols)

    map[x+up][y].neighbors = map[x+up][y].neighbors + 1
    map[x+down][y].neighbors = map[x+down][y].neighbors + 1
    map[x][y+left].neighbors = map[x][y+left].neighbors + 1
    map[x][y+right].neighbors = map[x][y+right].neighbors + 1
    map[x+up][y+left].neighbors = map[x+up][y+left].neighbors + 1
    map[x+down][y+left].neighbors = map[x+down][y+left].neighbors + 1
    map[x+up][y+right].neighbors = map[x+up][y+right].neighbors + 1
    map[x+down][y+right].neighbors = map[x+down][y+right].neighbors + 1
end

local function unsetCel(map, x, y, rows, cols)
    map[x][y].state = false

    -- update neighbor counts
    up, down, left, right = getNeighborOffsets(x, y, rows, cols)

    map[x+up][y].neighbors = map[x+up][y].neighbors - 1
    map[x+down][y].neighbors = map[x+down][y].neighbors - 1
    map[x][y+left].neighbors = map[x][y+left].neighbors - 1
    map[x][y+right].neighbors = map[x][y+right].neighbors - 1
    map[x+up][y+left].neighbors = map[x+up][y+left].neighbors - 1
    map[x+down][y+left].neighbors = map[x+down][y+left].neighbors - 1
    map[x+up][y+right].neighbors = map[x+up][y+right].neighbors - 1
    map[x+down][y+right].neighbors = map[x+down][y+right].neighbors - 1
end

local function isCelSet(map, x, y)
    return map[y][x].state
end

local function initGeneration(map, rows, cols)
    math.randomseed(os.time())
    for i=1,cols do
        for j=1,rows do
            local r = math.random(1,10)
            if (r % 4 == 0) then
                setCel(map, i, j, rows, cols)
            end
        end
    end
end

local function nextGeneration(map, rows, cols)
    local nextMap = copyMap(map, rows, cols)
    for i=1,cols do
        for j=1,rows do
            local cel = map[i][j]
            local skip = (cel.neighbors == 0) and (not cel.state)
            if (not skip) and (cel.state) and ((cel.neighbors < 2) or (cel.neighbors > 3)) then
                unsetCel(nextMap, i, j, rows, cols)
            elseif (not skip) and (not cel.state) and (cel.neighbors == 3) then
                setCel(nextMap, i, j, rows, cols)
            end
        end
    end

    return nextMap
end

local function getMapCoordinates(pixel)
    -- our map is 1-indexed, but the screen is 0-indexed
    -- we need to add 1 to the pixel's coordinates
    local x = pixel.x + 1
    local y = pixel.y + 1

    return x, y
end

-- SCREEN FUNCTION
local function initScreen(image)
    for pixel in image:pixels() do
        pixel(WHITE)
    end
end

local function drawMap(map, image)
    for pixel in image:pixels() do
        local x, y = getMapCoordinates(pixel)
        if (isCelSet(map, x, y)) then
            pixel(BLACK)
        end
    end
end

-- USER INTERFACE
local function mainWindow()
    local dialog = Dialog("Conway's Game of Life")
    
    dialog:separator {
        id="params",
        text="Parameters"
    }

    dialog:number {
        id="iterations",
        label="# of generations:",
        decimals=0
    }

    dialog:number {
        id="rows",
        label="Width:",
        decimals=0
    }

    dialog:number {
        id="cols",
        label="Height:",
        decimals=0
    }

    dialog:separator {
        id="acions",
        text="Actions"
    }

    dialog:button {
        id="cancel",
        text="Cancel"
    }

    dialog:button {
        id="generate",
        text="Generate"
    }

    return dialog
end

-- MAIN CODE

local window = mainWindow()
window:show{ wait=true }

-- if we committed to running the window
if (window.data.generate) then
    -- create a new file
    local rows = window.data.rows
    local cols = window.data.cols
    local sprite = Sprite(rows, cols)
    sprite.filename = app.fs.joinPath(app.fs.currentPath, "conways-gol-"..window.data.iterations..".png")

    local cel = app.activeCel
    cel.image = Image(rows, cols)

    -- initialization
    initScreen(cel.image)
    local map = initMap(rows, cols)

    -- draw the first generation
    initGeneration(map, rows, cols)
    drawMap(map, cel.image)

    -- loop through the next generations
    for i=2,window.data.iterations do
        local cel = app.activeSprite:newCel(app.activeLayer, app.activeSprite:newEmptyFrame())
        cel.image = Image(rows, cols)
        initScreen(cel.image)
        map = nextGeneration(map, rows, cols)
        drawMap(map, cel.image)
    end
end