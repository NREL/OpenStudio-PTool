# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class SolarCogenerationAndDaylighting < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Solar Cogeneration And Daylighting"
  end

  # human readable description
  def description
    return "Solar cogeneration and daylighting refers to using a concave concentrating mirror on the roof to focus light into a fiberoptic cable, which is run from the roof to light fixtures throughout the building to provide an alternative to electric lighting during sunny times.  Additionally, the light in the IR spectrum is directed onto a PV cell to generate electricity.  See http://www.jxcrystals.com/old_Solar/munich2.pdf for a more detailed description."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Reduces runtime fraction of lights by user-specified amount during the user-specified time period (typically daytime).  This is an attempt to represent the impact of using the light collected on the roof instead of electric lighting.  This modeling approach does not capture the impact of using a PV cell to turn the IR spectrum of the captured light into electricity."
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

    # make an argument for fractional value during specified time
    pct_red = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("pct_red",true)
    pct_red.setDisplayName("Percent Daytime Lighting Runtime Fraction Reduction")
    pct_red.setDefaultValue(50.0)
    args << pct_red

    # start time
    start_hr = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("start_hr",true)
    start_hr.setDisplayName("Time to start reduction")
    start_hr.setUnits("24hr, use decimal for sub hour")
    start_hr.setDefaultValue(9.0)
    args << start_hr

    # end time
    end_hr = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("end_hr",true)
    end_hr.setDisplayName("Time to end reduction")
    end_hr.setUnits("24hr, use decimal for sub hour")
    end_hr.setDefaultValue(16.0)
    args << end_hr

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
    pct_red = runner.getDoubleArgumentValue("pct_red",user_arguments)
    start_hr = runner.getDoubleArgumentValue("start_hr",user_arguments)
    end_hr = runner.getDoubleArgumentValue("end_hr",user_arguments)
    
    # This measure is not applicable if apply_measure is false
    if apply_measure == "FALSE"
      runner.registerAsNotApplicable("Not Applicable - User chose not to apply this measure via the apply_measure argument.")
      return true
    end

    #check the fraction for reasonableness
    if not 0 <= pct_red and pct_red <= 100
      runner.registerError("Percent reduction value needs to be between 0 and 100.")
      return false
    end

    #check start_hr for reasonableness and round to 15 minutes
    start_red_hr = nil
    start_red_min = nil
    if not 0 <= start_hr and start_hr <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24")
      return false
    else
      rounded_start_hr = ((start_hr*4).round)/4.0
      if not start_hr == rounded_start_hr
        runner.registerInfo("Start time rounded to nearest 15 minutes: #{rounded_start_hr}")
      end
      start_red_hr = rounded_start_hr.truncate
      start_red_min = (rounded_start_hr - start_red_hr)*60
      start_red_min = start_red_min.to_i
    end

    #check end_hr for reasonableness and round to 15 minutes
    end_red_hr = nil
    end_red_min = nil    
    if not 0 <= end_hr and end_hr <= 24
      runner.registerError("Time in hours needs to be between or equal to 0 and 24.")
      return false
    elsif end_hr > end_hr
      runner.registerError("Please enter an end time later in the day than end time.")
      return false
    else
      rounded_end_hr = ((end_hr*4).round)/4.0
      if not end_hr == rounded_end_hr
        runner.registerInfo("End time rounded to nearest 15 minutes: #{rounded_end_hr}")
      end
      end_red_hr = rounded_end_hr.truncate
      end_red_min = (rounded_end_hr - end_red_hr)*60
      end_red_min = end_red_min.to_i
    end

    # Translate the percent reduction into a multiplier
    red_mult = pct_red/100

    # Get schedules from all lights.
    original_lights_schs = []
    model.getLightss.each do |lights|
      if lights.schedule.is_initialized
        lights_sch = lights.schedule.get
        original_lights_schs << lights_sch
      end
    end

    # loop through the unique list of lights schedules, cloning
    # and reducing schedule fraction during the specified time range.
    original_lights_schs_new_schs = {}
    original_lights_schs.uniq.each do |lights_sch|
      if lights_sch.to_ScheduleRuleset.is_initialized
        new_lights_sch = lights_sch.clone(model).to_ScheduleRuleset.get
        new_lights_sch.setName("#{lights_sch.name} with Solar Cogeneration and Daylighting")
        original_lights_schs_new_schs[lights_sch] = new_lights_sch
        new_lights_sch = new_lights_sch.to_ScheduleRuleset.get
        
        # method to adjust the values in a day schedule by a 
        # specified percentage during a range of hours.
        def reduce_schedule(day_sch, red_mult, start_red_hr, start_red_min, end_red_hr, end_red_min)
          start_time = OpenStudio::Time.new(0, start_red_hr, start_red_min, 0)
          end_time = OpenStudio::Time.new(0, end_red_hr, end_red_min, 0)

          # Get the original values at the desired start and end times
          # and put points into the schedule at those times.
          day_sch.addValue(start_time, day_sch.getValue(start_time))
          day_sch.addValue(end_time, day_sch.getValue(end_time))
          
          # Store the original time/values then clear the schedule
          times = day_sch.times
          values = day_sch.values
          day_sch.clearValues

          # Modify the time/values and add back to the schedule
          for i in 0..(values.length - 1)
            if times[i] > start_time and times[i] <= end_time # Inside range
              day_sch.addValue(times[i], values[i] * red_mult)
            else
              day_sch.addValue(times[i], values[i])
            end
          end

        end #end reduce schedule

        # Reduce default day schedule
        if new_lights_sch.scheduleRules.size == 0
          runner.registerWarning("Schedule '#{new_lights_sch.name}' applies to all days.  It has been treated as a Weekday schedule.")
        end
        reduce_schedule(new_lights_sch.defaultDaySchedule, red_mult, start_red_hr, start_red_min, end_red_hr, end_red_min)
        
        # Reduce all other schedule rules
        new_lights_sch.scheduleRules.each do |sch_rule|
          reduce_schedule(sch_rule.daySchedule, red_mult, start_red_hr, start_red_min, end_red_hr, end_red_min)
        end
     
      end  
    end #end of original_lights_schs.uniq.each do

    #loop through all lights instances, replacing old lights schedules with the reduced schedules
    model.getLightss.each do |lights|
      if lights.schedule.empty?
        runner.registerWarning("There was no schedule assigned for the lights object named '#{lights.name}. No schedule was added.'")
      else
        old_lights_sch = lights.schedule.get
        lights.setSchedule(original_lights_schs_new_schs[old_lights_sch])
        runner.registerInfo("Schedule for the lights object named '#{lights.name}' was reduced to simulate the application of Solar Cogeneration and Daylighting.")
      end
    end

    # NA if the model has no lights
    if model.getLightss.size == 0
      runner.registerNotAsApplicable("Not Applicable - There are no lights in the model.")
    end

    # Reporting final condition of model
    runner.registerFinalCondition("#{original_lights_schs.uniq.size} schedule(s) were edited to reflect the addition of Solar Cogeneration and Daylighting to the building.")
    
    return true

  end
  
end

# register the measure to be used by the application
SolarCogenerationAndDaylighting.new.registerWithApplication
