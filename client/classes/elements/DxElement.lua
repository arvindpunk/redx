-- Author: Lpsd
-- File: client/classes/elements/DxElement.lua
-- Description: Base class for all dx elements

-- *******************************************************************
DxElement = inherit(Class)
-- *******************************************************************

function DxElement:virtual_constructor(x, y, width, height, relative, parent)
    self.data = {}
    self.propertyListeners = {}

    -- Used for property listeners
    local mt = getmetatable(self)
    mt.__newindex = self.set
    mt.__index = self.get
    setmetatable(self, mt)

    self.id = string.random(6) .. getTickCount()
    self.name = "default-" .. self.id
    self.__dx = true

    self.baseX, self.baseY = x, y
    self.baseWidth, self.baseHeight = width, height

    self.x, self.y = 0, 0
    self.width, self.height = 0, 0

    self.previousX, self.previousY = 0, 0
    self.previousWidth, self.previousHeight = 0, 0

    -- Relative click area
    self.clickArea = {
        x = 0,
        y = 0,
        width = width,
        height = height,
        defaultWidth = true,
        defaultHeight = true
    }    

    -- Relative drag area
    self.dragArea = {
        x = 0,
        y = 0,
        width = width,
        height = height,
        defaultWidth = true,
        defaultHeight = true
    }

    self.color = {
        default = {
            r = 0,
            g = 0,
            b = 0,
            a = 0
        },
        realtime = {
            r = 0, 
            g = 0, 
            b = 0, 
            a = 0
        }
    }

    self.parent = false
    self.children = {}

    self.scrollpane = false

    self.properties = DEFAULT_PROPERTIES

    self.events = {}

    self.renderFunctions = {
        render = {},
        preRender = {}
    }

    self.clickInitialX, self.clickInitialY = 0, 0
    self.dragging = false

    self:setPosition(x, y, relative)
    self:setSize(width, height, relative)
    
    self:addRenderFunction(self.calculateColor, true)
    self:addRenderFunction(self.calculatePosition, true)
    self:addRenderFunction(self.calculateSize, true)

    self.index = 0

    self:setParent(parent)
    self:setIndex(1)

    -- Set active property listeners
    self:addPropertyListener("x")
    self:addPropertyListener("y")
    self:addPropertyListener("width")
    self:addPropertyListener("height")

    self.fPropertyChange = function(propertyName, oldValue, newValue)
        iprint("fPropertyChange", propertyName, oldValue, newValue)
    end

    Core:getInstance():getEventManager():getEventFromName("onDxPropertyChange"):addHandler(self, self.fPropertyChange)

    return self
end

function DxElement:destructor()

end

-- *******************************************************************

function DxElement:get(property)
    local inheritedMethods = getmetatable(self).__class
    local methods = getmetatable(getmetatable(self).__class).__super[1]
    return inheritedMethods[property] or methods[property] or rawget(self.data, property)
end

function DxElement:set(property, newValue)
    rawset(self.data, property, newValue)

    if (self.propertyListeners[property]) then
        local previousValue = self["_prev_"..property]
        
        if (previousValue ~= newValue) then
            Core:getInstance():getEventManager():triggerEvent("onDxPropertyChange", self, property, previousValue, newValue)
        end

        rawset(self.data, "_prev_"..property, newValue)
    end
end

-- *******************************************************************

function DxElement:addPropertyListener(property)
    if (self.propertyListeners[property]) then
        return dxDebug("[addPropertyListener] Property listener already active", string.format("property: %s", property))
    end

    if (not self[property]) then
        return dxDebug("[addPropertyListener] Property does not exist", string.format("property: %s", property))
    end

    self.propertyListeners[property] = true
    dxDebug("[addPropertyListener] Added property listener", string.format("property: %s", property))
end

-- *******************************************************************

function DxElement:clickLeft(state)
    dxDebug("Left click", string.format("(name: %s, state: %s)", self:getName(), tostring(state)))

    local isRoot = self:isRoot()
    local cursorX, cursorY = getAbsoluteCursorPosition()

    if (state) then
        self.clickInitialX, self.clickInitialY = cursorX, cursorY

        if (isRoot) and (self:getProperty("draggable")) then
            local dragArea = self:getAbsoluteDragArea()
            if (isMouseInPosition(dragArea.x, dragArea.y, dragArea.width, dragArea.height)) then
                self.dragging = true
            end
        elseif (not isRoot) and (self.parent:getProperty("draggable_children")) then
            self.dragging = true
        end

        local clickOrder = isRoot and self:getProperty("click_order") or self:getProperty("click_order_children")
        if (clickOrder) then
            self:bringToFront()
        end
    else
        if (isFocusedElement(self)) then
            self.dragging = false
            self.baseX, self.baseY = self.x - (self.parent and self.parent.baseX or 0), self.y - (self.parent and self.parent.baseY or 0)
        end
    end

    return true
end

function DxElement:clickRight(state)
    dxDebug("Right click", string.format("(name: %s, state: %s)", self:getName(), tostring(state)))
    return true
end

function DxElement:clickMiddle(state)
    dxDebug("Middle click", string.format("(name: %s, state: %s)", self:getName(), tostring(state)))
    return true
end

-- *******************************************************************

function DxElement:setDragArea(x, y, width, height)
    x, y, width, height = (x or self.dragArea.x), (y or self.dragArea.y), (width or self.dragArea.width), (height or self.dragArea.height)

    self.dragArea = {
        x = x,
        y = y,
        width = width,
        height = height,
        defaultWidth = (width == self.dragArea.width),
        defaultHeight = (height == self.dragArea.height)
    }

    return true
end

function DxElement:getDragArea()
    return self.dragArea
end

function DxElement:getAbsoluteDragArea()
    return {
        x = (self.x + self.dragArea.x),
        y = (self.y + self.dragArea.y),
        width = self.dragArea.width,
        height = self.dragArea.height
    }
end

-- *******************************************************************

function DxElement:setClickArea(x, y, width, height)
    x, y, width, height = (x or self.clickArea.x), (y or self.clickArea.y), (width or self.clickArea.width), (height or self.clickArea.height)

    self.clickArea = {
        x = x,
        y = y,
        width = width,
        height = height,
        defaultWidth = (width == self.clickArea.width),
        defaultHeight = (height == self.clickArea.height)
    }

    return true
end

function DxElement:getClickArea()
    return self.clickArea
end

function DxElement:getAbsoluteClickArea()
    return {
        x = (self.x + self.clickArea.x),
        y = (self.y + self.clickArea.y),
        width = self.clickArea.width,
        height = self.clickArea.height
    }
end

-- *******************************************************************

function DxElement:setPosition(x, y, relative)
    local updatedX, updatedY

    if (relative) then
        x, y = tonumber(x) or self:absoluteToRelativeSize(self.baseX), tonumber(y) or self:absoluteToRelativeSize(self.baseY)
        updatedX, updatedY = self:relativeToAbsolutePosition(x, y)
    else
        updatedX, updatedY = tonumber(x) or self.baseX, tonumber(y) or self.baseY
    end

    self.baseX, self.baseY = updatedX, updatedY
    return true
end

function DxElement:setSize(width, height, relative)
    local updatedWidth, updatedHeight

    if (relative) then
        width, height = tonumber(width) or self:absoluteToRelativePosition(self.baseWidth), tonumber(height) or self:absoluteToRelativePosition(self.baseHeight)
        updatedWidth, updatedHeight = self:relativeToAbsolutePosition(width, height)
    else
        updatedWidth, updatedHeight = tonumber(width) or self.baseWidth, tonumber(height) or self.baseHeight
    end

    self.baseWidth, self.baseHeight = updatedWidth, updatedHeight

    self.dragArea.width = self.dragArea.defaultWidth and self.baseWidth or self.dragArea.width
    self.dragArea.height = self.dragArea.defaultHeight and self.baseHeight or self.dragArea.height

    return true
end

-- *******************************************************************

function DxElement:addEventHandler(eventName, attachedTo, handlerFunction, propagate, priority)
    propagate = (propagate == nil) and true or propagate
    priority = (priority == nil) and "normal" or priority
    
    handlerFunction = bind(handlerFunction, self)
    local event = addEventHandler(eventName, attachedTo, handlerFunction, propagate, priority)

    if (not event) or (type(handlerFunction) ~= "function") then
        dxDebug("Event failed to add", eventName, handlerFunction)
        return false
    end

    self.events[#self.events+1] = {
        eventName = eventName,
        attachedTo = attachedTo,
        handlerFunction = handlerFunction
    }

    return true
end

function DxElement:removeEventHandler(eventName, attachedTo, handlerFunction)
    handlerFunction = bind(handlerFunction, self)
    for i, event in ipairs(self.events) do
        if (event.eventName == eventName) and (event.attachedTo == attachedTo) and (event.handlerFunction == handlerFunction) then
            table.remove(self.events, i)
            return removeEventHandler(eventName, attachedTo, handlerFunction)
        end
    end
    return false
end

-- *******************************************************************

function DxElement:addRenderFunction(func, preRender, ...)
    if (type(func) ~= "function") then
        return false
    end

    func = bind(func, self)

    local renderType = preRender and "preRender" or "render"

    if (self.renderFunctions[renderType][func]) then
        dxDebug("Render function already exists", string.format("(priority: %s)", renderType), func)
        return false
    end

    self.renderFunctions[renderType][func] = {...}
    dxDebug("Added render function", renderType, func)
    return true
end

function DxElement:removeRenderFunction(func, preRender)
    if (type(func) ~= "function") then
        return false
    end

    func = bind(func, self)

    local renderType = preRender and "preRender" or "render"

    if (not self.renderFunctions[renderType][func]) then
        dxDebug("Render function doesn't exist", string.format("(priority: %s)", renderType), func)
        return false
    end

    self.renderFunctions[renderType][func] = nil
    return true
end

-- *******************************************************************

function DxElement:render()
    for func, args in pairs(self.renderFunctions.render) do
        func(unpack(args))
    end

    for i = #self.children, 1, -1 do
        local child = self.children[i]
        child:render()
    end
end

function DxElement:preRender()
    for func, args in pairs(self.renderFunctions.preRender) do
        func(unpack(args))
    end

    for i, child in ipairs(self.children) do
        child:preRender()
    end
end

-- *******************************************************************

function DxElement:isObstructed()
    return self:getObstructingElement() and true or false
end

function DxElement:getObstructingElement()
    if (self:isRoot()) then
        local elementIndex = 0
        for i, element in ipairs(DxRootElements) do
            if (element.index < self.index) then
                if (isMouseInPosition(element.x, element.y, element.width, element.height)) then
                    if (elementIndex == 0) then
                        elementIndex = element.index
                    end

                    if (not elementIndex) or (element.index < elementIndex) then
                        elementIndex = element.index
                    end
                end
            end
        end

        if (elementIndex ~= 0) and (elementIndex ~= self.index) then
            return DxRootElements[elementIndex]
        end
    end

    local childIndex = 0
    for i, child in ipairs(self.children) do
        if (isMouseInPosition(child.x, child.y, child.width, child.height)) then
            if (childIndex == 0) then
                childIndex = child.index
            end

            if (not childIndex) or (child.index < childIndex) then
                childIndex = child.index
            end
        end
    end

    if (childIndex ~= 0) then
        return self.children[childIndex]
    end

    return false
end

-- *******************************************************************

function DxElement:setParent(parent)
    parent = parent and parent or false

    if (parent) and (not isDxElement(parent)) then
        return false
    end

    if (parent) and (not self.parent) then
        table.remove(DxRootElements, self.index)
    end

    if (not parent) then
        table.insert(DxRootElements, 1, self)
    end

    if (not parent) and (self.parent) then
        self.parent:removeChild(self)
    end

    self.parent = parent

    if (self.parent) then
        self.parent:setChild(self)
    end

    return true
end

function DxElement:setChild(child)
    if (not isDxElement(child)) then
        return false
    end

    child:setIndex(1)
    return true
end

function DxElement:removeChild(c)
    if (not isDxElement(c)) then
        return false
    end

    for i, child in ipairs(self.children) do
        if (c == child) then
            return table.remove(self.children, i)
        end
    end
end

-- *******************************************************************

function DxElement:getIndex()
    return self.index
end

function DxElement:setIndex(index)
    index = tonumber(index)

    if (not index) or (index <= 0) then
        return false
    end

    local isRoot = self:isRoot()
    local rootTable = isRoot and DxRootElements or self.parent.children
    local currentTableIndex = self:getTableIndex()

    if (currentTableIndex) then
        table.remove(rootTable, currentTableIndex)
    end

    table.insert(rootTable, index, self)

    refreshElementIndexes()
    return true
end

-- *******************************************************************

function DxElement:getTableIndex()
    local rootTable = self:isRoot() and DxRootElements or self.parent.children
    for i, element in ipairs(rootTable) do
        if (element == self) then
            return i
        end
    end
    return false
end

-- *******************************************************************

function DxElement:setName(name)
    name = tostring(name)

    if (not name) then
        return false
    end

    self.name = name
    return true
end

function DxElement:getName()
    return self.name
end

-- *******************************************************************

function DxElement:isRoot()
    return not self.parent
end

-- *******************************************************************

function DxElement:setProperty(name, val)
    if (type(name) ~= "string") then
        return false
    end

    if (self.properties[name]) and (type(val) ~= type(self.properties[name])) then
        return false
    end

    self.properties[name] = val
    return true
end

function DxElement:getProperty(name)
    return self.properties[name]
end

-- *******************************************************************

function DxElement:setColor(r, g, b, a)
    r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)

    self.color.default.r = r and r or self.color.default.r
    self.color.default.g = g and g or self.color.default.g
    self.color.default.b = b and b or self.color.default.b
    self.color.default.a = a and a or self.color.default.a

    return true
end

-- *******************************************************************

function DxElement:bringToFront()
    return self:setIndex(1)
end

function DxElement:sendToBack()
    local rootTable = self:isRoot() and DxRootElements or self.parent.children
    return self:setIndex(#rootTable)
end

-- *******************************************************************

function DxElement:calculateColor()
    -- Extra logic required later for color interpolation
    self.color.realtime = self.color.default
end

function DxElement:calculatePosition()
    local offsetX, offsetY = 0, 0
    local cursorX, cursorY = getAbsoluteCursorPosition()

    if (self.dragging) then
        if (cursorX) and (cursorY) then
            offsetX, offsetY = cursorX - self.clickInitialX, cursorY - self.clickInitialY
        end
    end

    self.x, self.y = self.parent and (self.baseX + self.parent.x + offsetX) or (self.baseX + offsetX), self.parent and (self.baseY + self.parent.y + offsetY) or (self.baseY + offsetY)

    if (self:getProperty("force_in_bounds")) then
        local bounds = self:getBounds()
        local parentBounds = self:getParentBounds()

        if (bounds.x.min < parentBounds.x.min) then
            self.x = parentBounds.x.min
        end

        if (bounds.x.max > parentBounds.x.max) then
            self.x = parentBounds.x.max - self.width
        end

        if (bounds.y.min < parentBounds.y.min) then
            self.y = parentBounds.y.min
        end

        if (bounds.y.max > parentBounds.y.max) then
            self.y = parentBounds.y.max - self.height
        end
    end
end

function DxElement:calculateSize()
    self.width, self.height = self.baseWidth, self.baseHeight
end

-- *******************************************************************

function DxElement:getParentBounds(relative)
    if (not self.parent) then
        return {
            x = { min = 0, max = SCREEN_WIDTH },
            y = { min = 0, max = SCREEN_HEIGHT }
        }
    end

    return {
        x = { min = (not relative) and self.parent.x or 0, max = (not relative) and (self.parent.x + self.parent.width) or self.parent.width },
        y = { min = (not relative) and self.parent.y or 0, max = (not relative) and (self.parent.y + self.parent.height) or self.parent.height }
    }
end

function DxElement:getBounds(relative)
    return {
        x = { min = (not relative) and self.x or 0, max = (not relative) and (self.x + self.width) or self.width },
        y = { min = (not relative) and self.y or 0, max = (not relative) and (self.y + self.height) or self.height }
    }
end

function DxElement:getInheritedBounds()
    local bounds = self:getBounds(true)

    for i, child in ipairs(self:getInheritedChildren()) do
        local x, y = child.x - self.x, child.y - self.y

        if (x < bounds.x.min) then
            bounds.x.min = x
        end

        if (y < bounds.y.min) then
            bounds.y.min = y
        end

        if ((x + child.width) > bounds.x.max) then
            bounds.x.max = (x + child.width)
        end

        if ((y + child.height) > bounds.y.max) then
            bounds.y.max = (y + child.height)
        end
    end

    return bounds
end

-- *******************************************************************

function DxElement:getInheritedChildren()
	local children = {}
	
	for i, child in ipairs(self.children) do
		table.insert(children, child)
		
		for i, grandChild in ipairs(child:getInheritedChildren()) do
			table.insert(children, grandChild)
		end
	end

	return children
end

function DxElement:isInheritedChild(element)
	for i,e in pairs(self:getInheritedChildren()) do
		if(element == e) then
			return true
		end
	end
	return false
end

function DxElement:getInheritedChildrenByType(elementType)
	local children = {}
	for i, element in ipairs(self:getInheritedChildren()) do
		if(element.type == elementType) then
			table.insert(children, element)
		end
	end
	
	return children
end

-- *******************************************************************

function DxElement:getChildren()
	return self.children
end

function DxElement:getChildrenByType(elementType)
	local children = {}
	for i, element in ipairs(self:getChildren()) do
		if(element.type == elementType) then
			table.insert(children, element)
		end
	end
	
	return children
end

-- *******************************************************************

function DxElement:relativeToAbsolutePosition(relativeX, relativeY)
    if (not tonumber(relativeX)) or (not tonumber(relativeY)) then
        return false
    end

    if (self.parent) then
        return self.parent.x + (self.parent.width * relativeX), self.parent.y + (self.parent.height * relativeY)
    end

    return (SCREEN_WIDTH * relativeX), (SCREEN_HEIGHT * relativeY)
end

function DxElement:absoluteToRelativePosition(absoluteX, absoluteY)
    if (not tonumber(absoluteX)) or (not tonumber(absoluteY)) then
        return false
    end

    local offsetX, offsetY

    if (self.parent) then
        offsetX, offsetY = (self.x + absoluteX) - self.parent.x, (self.y + absoluteY) - self.parent.y

        -- Make sure values are 0 or above
        offsetX, offsetY = (offsetX >= 0) and offsetX or 0, (offsetY >= 0) and offsetY or 0

        return (offsetX / self.parent.width), (offsetY / self.parent.height)
    end

    offsetX, offsetY = math.clamp(absoluteX, 0, SCREEN_WIDTH), math.clamp(absoluteY, 0, SCREEN_HEIGHT)

    return (offsetX / SCREEN_WIDTH), (offsetY / SCREEN_HEIGHT)
end

-- *******************************************************************

function DxElement:relativeToAbsoluteSize(relativeWidth, relativeHeight)
    if (not tonumber(relativeWidth)) or (not tonumber(relativeHeight)) then
        return false
    end
    local rootWidth, rootHeight = self.parent and self.parent.width or SCREEN_WIDTH, self.parent and self.parent.height or SCREEN_HEIGHT
    return (relativeWidth / rootWidth), (relativeHeight / rootHeight)
end

function DxElement:absoluteToRelativeSize(absoluteWidth, absoluteHeight)
    if (not tonumber(absoluteWidth)) or (not tonumber(absoluteHeight)) then
        return false
    end
    local rootWidth, rootHeight = self.parent and self.parent.width or SCREEN_WIDTH, self.parent and self.parent.height or SCREEN_HEIGHT
    absoluteWidth, absoluteHeight = math.clamp(absoluteWidth, 0, rootWidth), math.clamp(absoluteHeight, 0, rootHeight)
    return (absoluteWidth - rootWidth) / rootWidth, (absoluteHeight - rootHeight) / rootHeight
end