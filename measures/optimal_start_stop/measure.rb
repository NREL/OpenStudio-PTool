#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class OptimalStartStop < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "OptimalStartStop"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    require 'json'

    def find_biggest_step_time(schedule, step_type = 'step_up', day = 'weekday')

      result = nil

      # Make sure it's a schedule:ruleset
      return result if schedule.to_ScheduleRuleset.empty?
      schedule = schedule.to_ScheduleRuleset.get
      
      # Get the default profile.  This will be
      # used unless another profile is found.
      profile = schedule.defaultDaySchedule
      
      # Get the other rules, using the saturday
      # or sunday rule as specified.
      schedule.scheduleRules.each do |rule|
        if day == 'saturday' && rule.applySaturday
          profile = rule.daySchedule
        elsif day == 'sunday' && rule.applySunday
          profile = rule.daySchedule
        elsif day == 'weekday' && (rule.applyMonday || rule.applyTuesday || rule.applyWednesday || rule.applyThursday || rule.applyFriday) 
          profile = rule.daySchedule
        end
      end  
      
      # Find the biggest change in the profile
      max_step = -999999.0
      if step_type == 'step_down'
        max_step = 999999.0
      end
      prev_value = profile.values.last
      prev_time = profile.times.last
      profile.values.zip(profile.times).each do |value,time|
        #puts "---#{value}, #{time}"
        diff = value - prev_value
        if step_type == 'step_up'
          if diff > max_step
            max_step = diff
            result = prev_time
          end
        elsif step_type == 'step_down'
          if diff < max_step
            max_step = diff
            result = prev_time
          end
        end
        prev_value = value
        prev_time = time
      end

      puts "#{day} max_#{step_type} = #{max_step}, at #{result}"
      
      if max_step == 0.0
        result = nil
      end
      
      return result

    end

    # Find the min and max profile value for a schedule
    def find_min_max_values(schedule)

      # validate schedule
      if schedule.to_ScheduleRuleset.is_initialized
        schedule = schedule.to_ScheduleRuleset.get

        # gather profiles
        profiles = []
        defaultProfile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
        profiles << defaultProfile
        rules = schedule.scheduleRules
        rules.each do |rule|
          profiles << rule.daySchedule
        end

        # test profiles
        min = nil
        max = nil
        profiles.each do |profile|
          profile.values.each do |value|
            if min.nil?
              min = value
            else
              if min > value then min = value end
            end
            if max.nil?
              max = value
            else
              if max < value then max = value end
            end
          end
        end
        result = {"min" => min, "max" => max} # this doesn't include summer and winter design day
      else
        result =  nil
      end

      return result

    end

    results = {}
    airloop_name = []

    model.getAirLoopHVACs.each do |air_loop|

      temp = {}
      puts ""
      puts "Air loop: #{air_loop.name}"

      # The HVAC operation schedule is always on if left blank
      hvac_op_sch = air_loop.availabilitySchedule
      if hvac_op_sch == model.alwaysOnDiscreteSchedule
        puts "HVAC operation sch = #{hvac_op_sch.name} is always on, skipping"
        next
      end
      #get airloop name since this airloop is appropriate
      puts "HVAC operation sch = #{hvac_op_sch.name}"
      airloop_name << "#{air_loop.name}"
      temp[:hvac_op_sch] = hvac_op_sch.name
      # Get the end values from the schedule
      # {End of Sat. HVAC Operation Time}
      sat_end = find_biggest_step_time(hvac_op_sch, 'step_down', 'saturday')
      if !sat_end.nil?
        temp[:sat_end] = sat_end.to_s
      else
        temp[:sat_end] = 25
      end  
      # {End of Sun. HVAC Operation Time}
      sun_end = find_biggest_step_time(hvac_op_sch, 'step_down', 'sunday')
      if !sun_end.nil?
        temp[:sun_end] = sun_end.to_s 
      else 
        temp[:sun_end] = 25
      end
      # {End of Weekday HVAC Operation Time} 
      wkdy_end = find_biggest_step_time(hvac_op_sch, 'step_down', 'weekday')
      if !wkdy_end.nil?
        temp[:wkdy_end] = wkdy_end.to_s
      else
        temp[:wkdy_end] = 25
      end
      zone_names = []
      unoc_htg_sp_zone = nil
      unoc_htg_sp = 99.9
      unoc_clg_sp = -99.9
      zones = []
      air_loop.thermalZones.each do |zone|
        temp2 = {}
        zone_names << zone.name.get
      
        # Get the zone thermostat
        tstat = zone.thermostatSetpointDualSetpoint
        next if tstat.empty?
        tstat = tstat.get
        
        # Find the zone on this loop with the coldest
        # unoccupied heating setpoint.
        htg_sch = tstat.heatingSetpointTemperatureSchedule
        if htg_sch.is_initialized
          min_htg = find_min_max_values(htg_sch.get)['min']
          temp2[:unoc_htg_sp] = min_htg
          temp2[:unoc_htg_sp_name] = htg_sch.get.name.get
          # if min_htg < unoc_htg_sp
            # unoc_htg_sp = min_htg
            # unoc_htg_sp_zone = zone
            # temp2[:unoc_htg_sp] = unoc_htg_sp.to_s
          # end
        end
        
        # Find the zone on this loop with the hottest
        # unoccupied cooling setpoint.
        clg_sch = tstat.coolingSetpointTemperatureSchedule
        if clg_sch.is_initialized
          max_clg = find_min_max_values(clg_sch.get)['max']
          temp2[:unoc_clg_sp] = max_clg
          temp2[:unoc_clg_sp_name] = clg_sch.get.name.get
          # if max_clg > unoc_clg_sp
            # unoc_clg_sp = max_clg
            # temp2[:unoc_clg_sp] = unoc_clg_sp
          # end
        end

        # Zone Name X (with unique thermostat)?
        # {Zone Name X Unoccupied Heating Set Point},
        # {Zone Name X Unoccupied Cooling Set Point}, 
        
        # {Zone Name X Unoccupied Infiltration Schedule Value},   
        zn_min_infil = 999.9
        zn_min_infil_name = nil
        zone.spaces.each do |space|
          runner.registerInfo("#{space.name}")
          space.spaceInfiltrationDesignFlowRates.each do |infil|
            runner.registerInfo("#{space.name} - infil = #{infil.name}")
            infil_sch = infil.schedule
            if infil_sch.is_initialized
              min_infil = find_min_max_values(infil_sch.get)['min']
              if min_infil < zn_min_infil
                zn_min_infil = min_infil
                zn_min_infil_name = infil_sch.get.name.get
              end
            end
          end
        end
        if zn_min_infil == 999.9
          puts "#{zone.name} min infiltration frac = 1"
          temp2[:zn_min_infil] = 1
          #add schedule since it dont exist
          #zone.spaces.each do |space|
          sch = OpenStudio::Model::ScheduleRuleset.new(model)
          sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),1)
          new_space_type_infil = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
          new_space_type_infil.setSchedule(sch)
          #new_space_type_infil.setSpace(space)
          #zn_min_infil_name = new_space_type_infil.get.name.get
        else
          puts "#{zone.name} min infiltration frac = #{zn_min_infil}"
          temp2[:zn_min_infil] = zn_min_infil
        end
        temp2[:zn_min_infil_name] = zn_min_infil_name
        temp2[:zone_name] = zone.name.get
        zones << temp2
      end

      puts "zones = #{zones}"
     
      # {Air Loop Name Unoccupied OA Value},
      # {Corresponding Minimum Outdoor Air Schedule Name},
      # Get the OA system and OA controller
      oa_sys = air_loop.airLoopHVACOutdoorAirSystem
      if oa_sys.is_initialized
        oa_sys = oa_sys.get
        oa_control = oa_sys.getControllerOutdoorAir
        min_oa_sch = oa_control.minimumOutdoorAirSchedule
        # min OA sch
        if min_oa_sch.is_initialized
          puts "min_oa_sch = #{min_oa_sch.get.name}"
          puts "min_oa_frac = #{find_min_max_values(min_oa_sch.get)['min']}"
          temp[:min_oa_sch] = min_oa_sch.get.name.to_s 
          temp[:min_oa_frac] = find_min_max_values(min_oa_sch.get)['min']
        end
      end
      
      # Corresponding HVAC Availability Schedule Schedule
      puts "HVAC avail sch = #{hvac_op_sch.name}"
      temp[:hvac_op_sch] = hvac_op_sch.name.to_s

      # Add this:
      # ZoneList,
      # {Air Loop} Zone List,  !- Name
      # {Zone X},        !- Zone 1 Name
      # {Zone Y};        !- Zone 2 Name
      puts "ZoneList"
      puts "#{air_loop.name} Zone List"
      zone_names.each do |zone_name|
        puts zone_name
      end
      temp[:zones] = zones
      #put results in results object
      results["#{air_loop.name}"] = temp
    end
    


    #save airloop parsing results to ems_results.json
    runner.registerInfo("Saving ems_results.json")
    FileUtils.mkdir_p(File.dirname("ems_results.json")) unless Dir.exist?(File.dirname("ems_results.json"))
    File.open("ems_results.json", 'w') {|f| f << JSON.pretty_generate(results)}
    
    if results.empty?
       runner.registerWarning("No airloops are appropriate for this measure")
       runner.registerAsNotApplicable("No airloops are appropriate for this measure")
       #save blank ems_advanced_rtu_controls.ems file so Eplus measure does not crash
       ems_string = ""
       runner.registerInfo("Saving blank optimal_start_stop file")
       FileUtils.mkdir_p(File.dirname("optimal_start_stop.ems")) unless Dir.exist?(File.dirname("optimal_start_stop.ems"))
       File.open("optimal_start_stop.ems", "w") do |f|
         f.write(ems_string)
       end
       return true
    end
    
    runner.registerInfo("Making EMS string for Integrated Waterside Economizer")
    #start making the EMS code
    ems_string = ""  #clear out the ems_string
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Sensor," + "\n"
    ems_string << "    OAT,                     !- Name" + "\n"
    ems_string << "    *,                       !- Output:Variable or Output:Meter Index Key Name" + "\n"
    ems_string << "    Site Outdoor Air Drybulb Temperature;  !- Output:Variable or Output:Meter Name" + "\n"
    ems_string << "\n" 
    results.each_with_index do |(key, value), i|
     
    ems_string << "EnergyManagementSystem:ProgramCallingManager," + "\n"
    ems_string << "    #{results.keys[i]}_Optimal_Stop_Control,    !- Name" + "\n"
    ems_string << "    AfterPredictorBeforeHVACManagers,  !- EnergyPlus Model Calling Point" + "\n"
    ems_string << "    #{results.keys[i]}_Optimal_Stop;            !- Program Name 1" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Program," + "\n"
    ems_string << "   #{results.keys[i]}_Optimal_Stop,            !- Name" + "\n"
    ems_string << "    ! Identify when the HVAC system is scheduled to turn off, and account for DST" + "\n"
    ems_string << "    SET SaturdayHVACEnd = #{value[:sat_end]}  - DaylightSavings,  !- Program Line 1" + "\n"
    ems_string << "    SET SundayHVACEnd = #{value[:sun_end]}  - DaylightSavings,  !- Program Line 1" + "\n"
    ems_string << "    SET WeekdayHVACEnd = #{value[:wkdy_end]} - DaylightSavings,   !- Program Line 2" + "\n"
    ems_string << "    ! Set the earliest you are willing to stop the HVAC system (1 hour in this case)" + "\n"
    ems_string << "    SET MinimumEarlyStop = 1,  !- A4" + "\n"
    ems_string << "    ! Set the earliest time for the HVAC system to shut off depending on the day of the week" + "\n"
    ems_string << "    IF DayOfWeek == 1 || Holiday == 1,         !- A9" + "\n"
    ems_string << "        SET MinimumStop = SundayHVACEnd - MinimumEarlyStop,  !- A10" + "\n"
    ems_string << "    ELSEIF DayOfWeek == 7,         !- A11" + "\n"
    ems_string << "        SET MinimumStop = SaturdayHVACEnd - MinimumEarlyStop,  !- A12" + "\n"
    ems_string << "    ELSE,          !- A13" + "\n"
    ems_string << "        SET MinimumStop = WeekdayHVACEnd - MinimumEarlyStop,  !- A14 " + "\n"
    ems_string << "    ENDIF,                   !- A15" + "\n"
    ems_string << "    ! Initialize variables" + "\n"
    ems_string << "    SET #{results.keys[i]}_HVAC_OP = Null,        !- A16" + "\n"
    value[:zones].each do |zone|
      ems_string << "    SET #{zone[:zone_name]}_HSet = null," + "\n"
      ems_string << "    SET #{zone[:zone_name]}_CSet = null," + "\n"
      ems_string << "    SET #{zone[:zone_name]}_Infil = null," + "\n"
    end
    ems_string << "    SET #{results.keys[i]}_MinOA = null," + "\n"
    ems_string << "    ! Use OAT and the current time to determine if the HVAC system should be shut off" + "\n"
    ems_string << "    IF  CurrentTime >= MinimumStop," + "\n"
    ems_string << "        IF  OAT <= 2 || OAT > 28,    !- A19" + "\n"
    ems_string << "            SET HourPlus = MinimumEarlyStop,  !- A20" + "\n"
    ems_string << "        ELSEIF OAT <= 12,          !- A21" + "\n"
    ems_string << "            SET HourPlus = MinimumEarlyStop * (12 - OAT)/10,  !- A22" + "\n"
    ems_string << "        ELSEIF OAT <= 18,          !- A23" + "\n"
    ems_string << "            SET HourPlus = 0,          !- A24" + "\n"
    ems_string << "        ELSE,                    !- A25" + "\n"
    ems_string << "            SET HourPlus = MinimumEarlyStop * (OAT - 18)/10,  !- A26" + "\n"
    ems_string << "        ENDIF,                   !- A27" + "\n"
    ems_string << "        IF CurrentTime > MinimumStop + HourPlus,  !- A28" + "\n"
    ems_string << "            SET #{results.keys[i]}_HVAC_OP = 0,           !- A33" + "\n"
    value[:zones].each do |zone|
      ems_string << "            SET #{zone[:zone_name]}_HSet = #{zone[:unoc_htg_sp]}," + "\n"
      ems_string << "            SET #{zone[:zone_name]}_CSet = #{zone[:unoc_clg_sp]}, " + "\n"
      ems_string << "            SET #{zone[:zone_name]}_Infil = #{zone[:zn_min_infil]}, " + "\n"
    end
    ems_string << "            SET #{results.keys[i]}_MinOA = #{value[:min_oa_frac]}, " + "\n"
    ems_string << "        ENDIF,                   !- A36" + "\n"
    ems_string << "    ENDIF;                   !- A37" + "\n"
    ems_string << "\n"
    ems_string << "EnergyManagementSystem:Actuator," + "\n"
    ems_string << "   #{results.keys[i]}_MinOA," + "\n"
    ems_string << "    #{value[:min_oa_sch]}," + "\n"
    ems_string << "    Schedule:Year," + "\n"
    ems_string << "    Schedule Value;" + "\n"
    ems_string << "\n"
    value[:zones].each do |zone|
      ems_string << "EnergyManagementSystem:Actuator," + "\n"
      ems_string << "    #{zone[:zone_name]}_Infil," + "\n"
      ems_string << "    #{zone[:zn_min_infil_name]}," + "\n"
      ems_string << "    Schedule:Compact," + "\n"
      ems_string << "    Schedule Value;" + "\n"
      ems_string << "\n"
    end
    ems_string << "EnergyManagementSystem:Actuator," + "\n"
    ems_string << "    #{results.keys[i]}_HVAC_OP,                 !- Name" + "\n"
    ems_string << "    #{value[:hvac_op_sch]},       !- Actuated Component Unique Name" + "\n"
    ems_string << "    Schedule:Year,        !- Actuated Component Type" + "\n"
    ems_string << "    Schedule Value;          !- Actuated Component Control Type" + "\n"
    ems_string << "\n"
    value[:zones].each do |zone|
      ems_string << "EnergyManagementSystem:Actuator," + "\n"
      ems_string << "    #{zone[:zone_name]}_HSet,                    !- Name" + "\n"
      ems_string << "    #{zone[:unoc_htg_sp_name]},  !- Actuated Component Unique Name" + "\n"
      ems_string << "    Schedule:Year,        !- Actuated Component Type" + "\n"
      ems_string << "    Schedule Value;          !- Actuated Component Control Type" + "\n"
      ems_string << "\n"
      ems_string << "EnergyManagementSystem:Actuator," + "\n"
      ems_string << "    #{zone[:zone_name]}_CSet,                    !- Name" + "\n"
      ems_string << "    #{zone[:unoc_clg_sp_name]},  !- Actuated Component Unique Name" + "\n"
      ems_string << "    Schedule:Year,        !- Actuated Component Type" + "\n"
      ems_string << "    Schedule Value;          !- Actuated Component Control Type" + "\n"
      ems_string << "\n"
    end
    end    
       
    #save EMS snippet
    runner.registerInfo("Saving optimal_start_stop file")
    FileUtils.mkdir_p(File.dirname("optimal_start_stop.ems")) unless Dir.exist?(File.dirname("optimal_start_stop.ems"))
    File.open("optimal_start_stop.ems", "w") do |f|
      f.write(ems_string)
    end   
    
    
    #unique initial conditions based on
    #runner.registerInitialCondition("The building has #{results.length} constant air volume units for which this measure is applicable.")

    #reporting final condition of model
    #runner.registerFinalCondition("VSDs and associated controls were applied to  #{results.length} single-zone, constant air volume units in the model.  Airloops affected were #{airloop_name}")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
OptimalStartStop.new.registerWithApplication