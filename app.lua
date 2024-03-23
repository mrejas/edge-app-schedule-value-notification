function table:deepCopy()
       if type(self) ~= 'table' then return self end
       local res = setmetatable({}, getmetatable(self))
       for k, v in pairs(self) do res[table.deepCopy(k)] = table.deepCopy(v) end
       return res
end

local function matchCriteria(fn, criteria)
    local isArray = false
    local arrayMatch = false
    for k, v in pairs(criteria) do
        if math.type(k) ~= nil then
            isArray = true
            if fn.id == v then
                arrayMatch = true
                break
            end
        else
            if k == 'id' then
                if fn.id ~= v then return false end
            end
            if k == 'type' then
                if fn.type:match('^' .. v .. '$') == nil then return false end
            end
            if fn.meta[k] == nil then return false end
            if fn.meta[k]:match('^' .. v .. '$') == nil then return false end
        end
    end
    if isArray then return arrayMatch end
    return true
end

function inSchedule()
	date = dst_date()
	in_schedule = false

	if date['wday'] == 1 and not cfg.sunday then return(false) end
	if date['wday'] == 2 and not cfg.monday then return(false) end
	if date['wday'] == 3 and not cfg.tuesday then return(false) end
	if date['wday'] == 4 and not cfg.wednesday then return(false) end
	if date['wday'] == 5 and not cfg.thursday then return(false) end
	if date['wday'] == 6 and not cfg.friday then return(false) end
	if date['wday'] == 7 and not cfg.saturday then return(false) end


	if cfg.time_start <= date['hour'] and cfg.time_end > date['hour'] then
		in_schedule = true
	end

	if cfg.side == 'in' then
		return(in_schedule)
	else
		return(not in_schedule)
	end
end

function dst_date()
	time = os.date('!*t')


	if time['month'] == 4 or
		time['month'] == 5 or
		time['month'] == 6 or
		time['month'] == 7 or
		time['month'] == 8 or
		time['month'] == 9 then
		offset = 2
	end
	if time['month'] == 1 or
		time['month'] == 2 or
		time['month'] == 11 or
		time['month'] == 12 then
		offset = 1
	end
	if time['month'] == 3 then
		if time['day'] < 25 then
			offset = 1
		else
			offset = 1
			if time['wday'] == 1 then
				offset = 2 -- ingoring that dst start at 02:00.
			end
			if time['wday'] == 2 and time['day'] > 25 then
				offset = 2
			end
			if time['wday'] == 3 and time['day'] > 26 then
				offset = 2
			end
			if time['wday'] == 4 and time['day'] > 27 then
				offset = 2
			end
			if time['wday'] == 5 and time['day'] > 28 then
				offset = 2
			end
			if time['wday'] == 6 and time['day'] > 29 then
				offset = 2
			end
			if time['wday'] == 7 and time['day'] > 30 then
				offset = 2
			end
		end
	end
	if time['month'] == 10 then
		if time['day'] < 25 then
			offset = 2
		else
			offset = 2
			if time['wday'] == 1 then
				offset = 1 -- ingoring that dst start at 02:00.
			end
			if time['wday'] == 2 and time['day'] > 25 then
				offset = 1
			end
			if time['wday'] == 3 and time['day'] > 26 then
				offset = 1
			end
			if time['wday'] == 4 and time['day'] > 27 then
				offset = 1
			end
			if time['wday'] == 5 and time['day'] > 28 then
				offset = 1
			end
			if time['wday'] == 6 and time['day'] > 29 then
				offset = 1
			end
			if time['wday'] == 7 and time['day'] > 30 then
				offset = 1
			end
		end
	end


	return(os.date('!*t', os.time() + offset * 3600))
end


function findDevice(criteria)
    devices = lynx.getDevices()
    if math.type(criteria) ~= nil then
        for _, dev in ipairs(devices) do
            if dev.id == criteria then return dev end
        end
    elseif type(criteria) == 'table' then
        for _, dev in ipairs(devices) do
            if matchCriteria(dev, criteria) then return dev end
        end
    end
    return nil
end


function findFunction(criteria)
    if math.type(criteria) ~= nil then
        for _, fn in ipairs(functions) do
            if fn.id == criteria then return fn end
        end
    elseif type(criteria) == 'table' then
        for _, fn in ipairs(functions) do
            if matchCriteria(fn, criteria) then return fn end
        end
    end
    return nil
end


function findFunctions(criteria)
    local res = {}
    if type(criteria) == 'table' then
        for _, fn in ipairs(functions) do
            if matchCriteria(fn, criteria) then table.insert(res, fn) end
        end
    end
    return res
end

local topicArmed = {}
local topicFunction = {}
local edgeTrigger = {}

function handleTrigger(topic, payload, retained)
	local data = json:decode(payload)
	if cfg.overOrUnder == "under" then
		if data.value < cfg.threshold then
			topicArmed[topic] = true
		else
			topicArmed[topic] = false
		end
	elseif cfg.overOrUnder == "over" then
		if data.value > cfg.threshold then
			topicArmed[topic] = true
		else
			topicArmed[topic] = false
		end
	end
	sendNotificationIfArmed(topic, data.value, cfg.overOrUnder)
end

function onStart()
	for i, fun in ipairs(cfg.trigger_functions) do
		local triggerFunction = findFunction(fun)
		local triggerTopic = triggerFunction.meta.topic_read

		-- Keep mapping between topic and function. In the case
		-- of two functions having the same topic the last one
		-- in this loop will be used.
		topicFunction[triggerTopic] = triggerFunction

		mq:sub(triggerTopic, 0)
		mq:bind(triggerTopic, handleTrigger)
	end
end

function sendNotificationIfArmed(topic, value, action)
	if cfg.notification_output == nil then return end
	if not inSchedule() then 
		print('Out of schedule')
		return 
	end
	print('In schedule')

	local func = topicFunction[topic]
    	local dev = findDevice(tonumber(func.meta.device_id))
	local armed = topicArmed[topic]
	local sent = edgeTrigger[topic]
	if armed then
		if sent then return end
		local payloadData = {
			value = value,
			action = action,
			firing = func.meta.name,
			unit = func.meta.unit,
			note = func.meta.note,
			func = func,
			device = dev,
			threshold = cfg.threshold
		}
		lynx.notify(cfg.notification_output, payloadData)
		edgeTrigger[topic] = true
	else
    		edgeTrigger[topic] = false
	end
end
