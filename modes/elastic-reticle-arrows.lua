local LIB = "Elastic Reticle Arrows"
local era = EXT_GROUPLEADER.Modes[LIB]
local left, right, ui;

if not era then
   
    era = EXT_GROUPLEADER.Modes:Register(LIB)
    
    function era:Init()
        
        ui = EXT_GROUPLEADER.UI
        left, right = ui:RequestTextureFrames({
            { Texture = "elastic-reticle-arrows/left.dds", Movable = false },
            { Texture = "elastic-reticle-arrows/right.dds", Movable = false }
        })
        
    end
    
    function era:Unit()
        
        left, right = nil, nil
        
    end
    
    function era:Update(state)
        
        if state.Hidden then
            left:SetAlpha(0)
            right:SetAlpha(0)
            return
        end
        
        if state.Linear > 0 then
            
            left:SetAnchor(RIGHT, LEFT, -state.Settings.MinDistance, 0)
            left:SetDimensions(state.Settings.MinSize)
            left:SetColor(state.Color)
            left:SetAlpha(state.Settings.MinAlpha)
            
            right:SetAnchor(LEFT, RIGHT, state.Distance, 0)
            right:SetDimensions(state.Size)
            right:SetColor(state.Color)
            right:SetAlpha(state.Alpha)
            
        else
            
            left:SetAnchor(RIGHT, LEFT, -state.Distance, 0)
            left:SetDimensions(state.Size)
            left:SetColor(state.Color)
            left:SetAlpha(state.Alpha)
            
            right:SetAnchor(LEFT, RIGHT, state.Settings.MinDistance, 0)
            right:SetDimensions(state.Settings.MinSize)
            right:SetColor(state.Color)
            right:SetAlpha(state.Settings.MinAlpha)
            
        end
        
    end
    
end