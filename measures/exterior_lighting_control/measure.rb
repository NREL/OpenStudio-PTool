# Developed by Ambient Energy for NREL

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
    return "TODO"
  end

  # human readable description of modeling approach
  def modeler_description
    return "TODO"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #none per DOE

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

  	# initialize variables
  	ext_ltg_pwr_reduction = 0.3
  	hr_on = 0
  	min_on = 0
  	hr_off = 6
  	min_off = 0
  	max_hrs = []
    min_hrs = []

    # get model objects from model classes
	  ext_lights = model.getExteriorLightss #my precious
	  ext_lights_defs = model.getExteriorLightsDefinitions
	  sch_rulesets = model.getScheduleRulesets
    spaces = model.getSpaces
    space_types = model.getSpaceTypes
    space_types_used = []

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

			max_hrs << Helpers.get_min_max_time(occ_sch)["max"]
	    min_hrs << Helpers.get_min_max_time(occ_sch)["min"]

    end #thermal zones

    # get min and max times for occupancy schedules 
    sch_rulesets.each do|sch_ruleset|

    	if sch_ruleset.name.to_s.include? "Occ" #TODO
    		max_hrs << Helpers.get_min_max_time(sch_ruleset)["max"]
    		min_hrs << Helpers.get_min_max_time(sch_ruleset)["min"]
  		end

		end

		# earliest and latest times
		max_hr = max_hrs.max
		min_hr = min_hrs.min
#		puts "MAX HR = #{max_hr}"
#		puts "MIN HR = #{min_hr}"

		# determine open and close times

		# create schedule (could use OsLib_Schedules.rb functions)
    ext_lights_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    ext_lights_sch.setName("Exterior Lights Schedule")
		default_day = ext_lights_sch.defaultDaySchedule
		default_day.addValue(OpenStudio::Time.new(hr_on, hr_off, min_on, min_off), (1-ext_ltg_pwr_reduction))

		# set schedule	  
		if ext_lights.empty?

			runner.registerAsNotApplicable("No exterior lights objects found in model.")
			return true

		else

			ext_lights.each do |el|

				if el.controlOption == "AstronomicalClock"
					runner.registerInfo("Changing control option for exterior lights object: #{el.name}")
					el.setControlOption("ScheduleNameOnly")
				end

				runner.registerInfo("Changing schedule for exterior lights object: #{el.name}")
				el.setSchedule(ext_lights_sch)

			end

		end

  end #run method

end #class

# register the measure to be used by the application
ExteriorLightingControl.new.registerWithApplication
