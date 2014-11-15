# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class WirelessLightingOccupancySensors < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Wireless Lighting Occupancy Sensors"
  end

  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make an argument to apply/not apply this measure
    chs = OpenStudio::StringVector.new
    chs << "TRUE"
    chs << "FALSE"
    apply_measure = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('apply_measure', chs, true)
    apply_measure.setDisplayName("Apply Measure?")
    apply_measure.setDefaultValue("TRUE")
    args << apply_measure 
    
    # Make an argument for the number of lamps
    percent_runtime_reduction = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("percent_runtime_reduction",true)
    percent_runtime_reduction.setDisplayName("Percent Runtime Reduction due to Occupancy Sensors")
    percent_runtime_reduction.setUnits("%")
    percent_runtime_reduction.setDefaultValue(15.0)
    args << percent_runtime_reduction

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Assign the user inputs to variables
    apply_measure = runner.getStringArgumentValue("apply_measure",user_arguments)
    percent_runtime_reduction = runner.getDoubleArgumentValue("percent_runtime_reduction",user_arguments)

    # This measure is not applicable if apply_measure is false
    if apply_measure == "FALSE"
      runner.registerAsNotApplicable("Not Applicable - User chose not to apply this measure via the apply_measure argument.")
      return true
    end  
    
    # Check arguments for reasonableness
    if percent_runtime_reduction >= 100
      runner.registerError("Percent runtime reduction must be less than 100.")
      return false
    end

    # Find all the original schedules (before occ sensors installed)
    original_lts_schedules = []
    model.getLightss.each do |light_fixture|
      if light_fixture.schedule.is_initialized
        original_lts_schedules << light_fixture.schedule.get
      end
    end    

    # Make copies of all the original lights schedules, reduced to include occ sensor impact
    original_schs_new_schs = {}
    original_lts_schedules.uniq.each do |orig_sch|
      # Copy the original schedule
      new_sch = orig_sch.clone.to_ScheduleRuleset.get
      new_sch.setName("#{new_sch.name.get} with occ sensor")
      # Reduce each value in each profile (except the design days) by the specified amount
      runner.registerInfo("Reducing values in '#{orig_sch.name}' schedule by #{percent_runtime_reduction}% to represent occ sensor installation.")
      day_profiles = []
      day_profiles << new_sch.defaultDaySchedule
      new_sch.scheduleRules.each do |rule|
        day_profiles << rule.daySchedule
      end
      multiplier = (100 - percent_runtime_reduction)/100
      day_profiles.each do |day_profile|
        #runner.registerInfo("#{day_profile.name}")
        times_vals = day_profile.times.zip(day_profile.values)
        #runner.registerInfo("original time/values = #{times_vals}")
        times_vals.each do |time,val|
          day_profile.addValue(time, val * multiplier)
        end
        #runner.registerInfo("new time/values = #{day_profile.times.zip(day_profile.values)}")
      end    
      #log the relationship between the old sch and the new, reduced sch
      original_schs_new_schs[orig_sch] = new_sch
    end
    
    # Replace the old schedules with the new, reduced schedules
    spaces_sensors_added_to = []
    model.getLightss.each do |light_fixture|
      next if light_fixture.schedule.empty?
      lights_sch = light_fixture.schedule.get
      new_sch = original_schs_new_schs[lights_sch]
      if new_sch
        runner.registerInfo("Added occupancy sensor for '#{light_fixture.name}'")
        light_fixture.setSchedule(new_sch)
        spaces_sensors_added_to << light_fixture.space
      end
    end
    
    # Report if the measure is not applicable
    num_sensors_added = spaces_sensors_added_to.uniq.size
    if spaces_sensors_added_to.size == 0
      runner.registerAsNotApplicable("This measure is not applicable because there were no lights in the building.")
      return true
    end  
        
    # Report final condition
    runner.registerFinalCondition("Added occupancy sensors to #{num_sensors_added} spaces in the building.")

    return true

  end
  
end

# register the measure to be used by the application
WirelessLightingOccupancySensors.new.registerWithApplication
