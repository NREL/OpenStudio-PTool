
class SupplyAirTemperatureResetBasedOnOutdoorAirTemperature < OpenStudio::Ruleset::ModelUserScript
  
  def check_applicability(model)

      #information for debugging 
      measure_name = "SupplyAirTemperatureResetBasedOnOutdoorAirTemperature"
      measure_uid = "6b169642-c52a-47ac-b045-abcbb90cbf9b"
      measure_applicability = false

      #store output messages
      messages = []
                    
      # Loop through all CAV and VAV fans in the model
      fans = model.getFanConstantVolumes
      fans += model.getFanVariableVolumes
      mz_airloops = []
      airloops_already_sat_reset = []
      airloops_sat_reset_added = []
      spaces_affected = []
      fans.each do |fan|
      
        # Skip fans that are inside terminals
        next if fan.airLoopHVAC.empty?
      
        # Get the air loop
        air_loop = fan.airLoopHVAC.get
        messages << "***Found multizone air system '#{air_loop.name}'***"
       
        # Skip single-zone air loops
        if air_loop.thermalZones.size <= 1
          messages << "  '#{air_loop.name}' is a single-zone system, SAT reset based on OAT not applicable."
          next
        end
      
        # Record this as a multizone VAV system
        mz_airloops << air_loop
      
        # Skip air loops that already have SAT reset based on OAT
        if air_loop.supplyOutletNode.setpointManagerOutdoorAirReset.is_initialized
          messages << "  '#{air_loop.name}' already has SAT reset based on OAT."
          airloops_already_sat_reset << air_loop
          next
        end
        
        # If at this point, SAT reset based on OAT should be applied
        airloops_sat_reset_added << air_loop

        # Register all the spaces on this airloop
        air_loop.thermalZones.each do |zone|
          zone.spaces.each do |space|
            spaces_affected << "#{space.name}"
          end
        end   
     
      end # Next fan
    
      # Summarize the results of the check
      messages << "******SUMMARY******"
    
      # If the model has no multizone air loops, flag as Not Applicable
      if mz_airloops.size == 0
        measure_applicability = false
        messages << "Not Applicable - The model has no multizone VAV air systems."
        debug_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
        debug_hash["measure"]["uid"] = measure_uid
        debug_hash["measure"]["name"] = measure_name
        debug_hash["measure"]["applicable"] = measure_applicability
        debug_hash["measure"]["messages"] = messages
        result_hash = nil
        return [result_hash,debug_hash] 
      end       

      # If all air loops already have SP reset, flag as Not Applicable
      if airloops_already_sat_reset.size == mz_airloops.size
        measure_applicability = false
        messages << "Not Applicable - All multizone VAV air systems in the model already have SAT reset based on OAT."
        debug_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
        debug_hash["measure"]["uid"] = measure_uid
        debug_hash["measure"]["name"] = measure_name
        debug_hash["measure"]["applicable"] = measure_applicability
        debug_hash["measure"]["messages"] = messages
        result_hash = nil
        return [result_hash,debug_hash] 
      end   
       
      #report the applicability determination
      if spaces_affected.size > 0
        measure_applicability = true
        result_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
        result_hash["measure"]["uid"] = measure_uid
        result_hash["measure"]["name"] = measure_name
        result_hash["measure"]["spaces"] = spaces_affected
      else
        result_hash = nil
      end
      
      #send the debugging output
      debug_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
      debug_hash["measure"]["uid"] = measure_uid
      debug_hash["measure"]["name"] = measure_name
      debug_hash["measure"]["applicable"] = measure_applicability
      debug_hash["measure"]["messages"] = messages
   
   
      return [result_hash,debug_hash]
   
    end #end check_applicability

end #SupplyAirTemperatureResetBasedOnOutdoorAirTemperature