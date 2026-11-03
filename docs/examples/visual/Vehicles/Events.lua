--[[!
@fqxn Examples.Vehicles.Events
@desc Application callbacks are ordinary Lua closures so native snapshots can save them.
    Capture the owning instance, rather than a compiled LXC method reference.
!]]
local Events = {};
--[[!
@fqxn Examples.Vehicles.Events.inspection
@desc Creates a saveable callback that resolves the restored owner’s public method when fired.
@param Examples.Vehicles.Vehicle oVehicle Owning vehicle identity.
@ret function fInspection Ordinary Lua event callback.
!]]
function Events.inspection(oVehicle)
    -- Eventrix preserves this closure's lexical environment; a registered event
    -- environment does not replace where VEHICLE_ENV_LABEL is looked up.
    local function fInspection()
        oVehicle.recordInspection(VEHICLE_ENV_LABEL or "Framework default environment");
    end
    return fInspection;
end
return Events;
