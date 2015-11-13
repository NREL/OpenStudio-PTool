# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# require modules
require "#{File.dirname(__FILE__)}/resources/Helpers"

# start the measure
class ExteriorLightingControl < OpenStudio::Ruleset::ModelUserScript

	# include modules
  include Helpers

  # human readable name
  def name
    return "Exterior Lighting Control"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) reduces all exterior lighting to 30% of its peak power between midnight or within 1 hour of business closing, whichever is later, and until 6 am or business opening, whichever is earlier, and during any period activity is not detected for a time longer than 15 minutes."
  end

  # human readable description of modeling approach
  def modeler_description
    return "TODO"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    
  	# initialize variables
  	ext_ltg_pwr_reduction = 0.3
  	hr_on = 0
  	min_on = 0
  	hr_off = 6
  	min_off = 0
  	max_hrs = []
    min_hrs = []
    ext_lights_sch_name = "Exterior Lights Schedule"
    ext_lights_count = 0
    ext_lights_changed = 0

    # get model objects from model classes
	  ext_lights = model.getExteriorLightss #my precious

		# DO STUFF

		# determine building open and close times
		# https://github.com/NREL/OpenStudio-PTool/blob/master/measures/predictive_thermostats/measure.rb
		model.getThermalZones.each do |zone|

      # Skip zones that have no occupants
      # or have occupants with no schedule
      people = []
      zone.spaces.each do |space|
        people += space.people
        if space.spaceType.is_initialized
          people += space.spaceType.get.people
        end
      end
      if people.size == 0
#        runner.registerInfo("Zone #{zone.name} has no people, predictive thermostat not applicable.")
        next
      end
      occ = people[0]
      if occ.numberofPeopleSchedule.empty?
#        runner.registerInfo("Zone #{zone.name} has people but no occupancy schedule, predictive thermostat not applicable.")
        next
      end
      occ_sch = occ.numberofPeopleSchedule.get

			max_hrs << Helpers.get_min_max_time(occ_sch)["max_time"]
	    min_hrs << Helpers.get_min_max_time(occ_sch)["min_time"]

    end #thermal zones

		# determine absolute earliest and latest occupied times
		max_hr = max_hrs.max
		min_hr = min_hrs.min

		# compare occupancy min/max and adjust from fixed 0000-0600 if necessary
    #TODO

		# create schedule, could use OsLib_Schedules.rb functions
    runner.registerInfo("Adding new schedule to model: #{ext_lights_sch_name}")
    ext_lights_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    ext_lights_sch.setName(ext_lights_sch_name)
		default_day = ext_lights_sch.defaultDaySchedule
		default_day.addValue(OpenStudio::Time.new(hr_on, hr_off, min_on, min_off), (1-ext_ltg_pwr_reduction))

    # set controls, could be more DRY
		if ext_lights.empty?

			runner.registerAsNotApplicable("No exterior lights objects found in model.")
			return true

		else

			ext_lights.each do |el|

        ext_lights_count += 1
        runner.registerInfo("Applying exterior lighting controls to: #{el.name}")

        if el.controlOption == "AstronomicalClock"

          runner.registerInfo("=> control option set to: AstronomicalClock")
          runner.registerInfo("=> setting control option to: ScheduleNameOnly")
          el.setControlOption("ScheduleNameOnly")
          runner.registerInfo("=> setting schedule to: #{ext_lights_sch.name}")
          el.setSchedule(ext_lights_sch)
          ext_lights_changed += 1

        elsif el.controlOption == "ScheduleNameOnly"

          runner.registerInfo("=> control option set to: ScheduleNameOnly")
          runner.registerInfo("=> setting schedule to: #{ext_lights_sch.name}")
          el.setSchedule(ext_lights_sch)
          ext_lights_changed += 1

        else

          runner.registerInfo("=> control option set to: blank")
          runner.registerInfo("=> setting control option to: ScheduleNameOnly")
          el.setControlOption("ScheduleNameOnly")
          runner.registerInfo("=> setting schedule to: #{ext_lights_sch.name}")
          el.setSchedule(ext_lights_sch)
          ext_lights_changed += 1

        end

			end

		end
'TODO: causes run time error in 1.9.0
    # report initial condition
    runner.registerInitialCondition("Number of exterior lights objects in model = #{ext_lights_count}")

    # report final condition
    runner.registerFinalCondition("Number of exterior lights objects changed = #{ext_lights_changed}")
'
  end #run method

end #class

# register the measure to be used by the application
ExteriorLightingControl.new.registerWithApplication
