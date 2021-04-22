-- Author: Lpsd (https://github.com/Lpsd/)
-- See the LICENSE file @ root directory

-- Constants
SCREEN_WIDTH, SCREEN_HEIGHT = false, false
DEBUG = true

DX_TYPES = {
    "RECT",
    "SCROLLPANE",
    "SCROLLBAR",
    "WINDOW",
}

enum(DX_TYPES, "DX")

-- *******************************************************************

-- Store all DxElements
DxRootElements = {}
DxFocusedElements = {}

DxCore = false

-- *******************************************************************

function init()
    SCREEN_WIDTH, SCREEN_HEIGHT = guiGetScreenSize()
    
    -- Initialize the core
    DxCore = Core:getInstance()

    -- Loads the default properties
    loadDefaultProperties()

    local tick = getTickCount()

    -- Testing
    dxTest()

    iprint("Test took " .. tostring(getTickCount() - tick) .. "ms")
end
addEventHandler("onClientResourceStart", resourceRoot, init)

-- *******************************************************************

function dxTest()
    window = DxWindow:new(300, 300, 200, 200)

    window:setDraggable(true)
    window:setDraggableChildren(true)

    item = DxRect:new(75, 75, 75, 75, false, window)

    window2 = DxWindow:new(600, 300, 200, 200)

    window2:setDraggable(true)
    window2:setDraggableChildren(true)

    item2 = DxRect:new(35, 35, 75, 75, false, window2)
    item3 = DxRect:new(35, 35, 75, 75, false, item2)
    item3:setColor(66, 66, 66)

    setTimer(function()
        item3:setParent(item)
    end, 2000, 1)
end
-- *******************************************************************

bindKey("F2", "down", function()
    showCursor(not isCursorShowing())
end)

-- *******************************************************************

-- Helper functions
function isFocusedElement(e)
    for i, element in ipairs(DxFocusedElements) do
        if e == element then
            return true
        end
    end
    return false
end

function refreshElementIndexes()
    for i, element in ipairs(DxRootElements) do
        element.index = element:getTableIndex()
        refreshElementChildIndexes(element)
    end 
end

function refreshElementChildIndexes(element)
    for i, child in ipairs(element.children) do
        child.index = child:getTableIndex()
    end
end