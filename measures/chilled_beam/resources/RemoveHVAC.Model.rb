
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

   def removeHVAC()

    # Remove all airloops 
    self.getAirLoopHVACs.each do |air_loop|
      air_loop.remove
    end

    # Remove all zone equipment
    self.getThermalZones.each do |zone|
      zone.equipment.each do |equip|
        if equip.to_FanZoneExhaust.is_initialized
        else  
          equip.remove
        end
      end
    end       

    # Remove plant loops, except those used for SWH
    self.getPlantLoops.each do |plant_loop|
      used_for_SWH_or_refrigeration = false
      
      # If the demand side of a plant loop has water use connections, 
      # it is used for service water heating
      plant_loop.demandComponents.each do |comp|
        if comp.to_WaterUseConnections.is_initialized
          used_for_SWH_or_refrigeration = true
        end
      end
      
      # If the supply side of a desuperheater, 
      # it is attached to a refrigeration system
      plant_loop.supplyComponents.each do |comp|
        if comp.to_CoilWaterHeatingDesuperheater.is_initialized
          used_for_SWH_or_refrigeration = true
        end      
      end
      
      if used_for_SWH_or_refrigeration == false
        plant_loop.remove
      end
      
    end
      
  end
  
end
