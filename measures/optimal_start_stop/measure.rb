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
          space.spaceInfiltrationDesignFlowRates.each do |infil|
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