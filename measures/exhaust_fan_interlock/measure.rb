# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class ExhaustFanInterlock < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Exhaust Fan Interlock"
  end

  # human readable description
  def description
    return "Exhaust fans that are not aligned with schedule of operations of the companion supply fan can impact the airflows of central air handlers by decreasing the flow of return air and sometimes increasing the outdoor air flow rate. A common operational practice is to interlock (or align) the operations of any exhaust fans with the companion system used to condition and pressurize a space. This measure examines all Fan:ZoneExhaust objects present in a model and coordinates the availability of the exhaust fan with the system supply fan. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "For any thermal zones having zone equipment objects of type Fan:ZoneExhaust, this energy efficiency measure (EEM) maps the schedule used to define the availability of the associated Air Loop to the Availability Schedule attribute of the zone exhaust fan object. "
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
	
	# assigning the arrays
	air_loops_array =[]
	fan_exhaust_array = []
	changed_sch_array_true = []
	changed_sch_array_false = []
	
	#STEP1
	@all_airloops = model.getAirLoopHVACs   # getting all airloops
	air_loops_array << @all_airloops
	@all_airloops.each do |loop| 
		@airloops_availability_sch = loop.availabilitySchedule # availability schedule for all airloops
		@thermal_zones = loop.thermalZones # all thermal zones assigned to airloops
		@thermal_zones.each do |eqip_zn| 
			@thermal_zones_equipment = eqip_zn.equipment # zone equipments assigned to thermal zones
				@thermal_zones_equipment.each do |exh_fan|
					if exh_fan.to_FanZoneExhaust.is_initialized
						@fan_exhaust = exh_fan.to_FanZoneExhaust.get # getting all fan exhaust to related thermal zones
						fan_exhaust_array << @fan_exhaust				
						if @fan_exhaust.availabilitySchedule.is_initialized
							fan_exh_avail_sch = @fan_exhaust.availabilitySchedule.get # availability schedule of exhausts
							changed_sch = @fan_exhaust.setAvailabilitySchedule(@airloops_availability_sch) # changing fan schedules to airloop availability schedules
							runner.registerInfo("Availability Schdule for OS:FanZoneExhaust named: '#{@fan_exhaust.name}' has been changed to '#{@airloops_availability_sch.name}' from '#{fan_exh_avail_sch.name}'.")
							if changed_sch == true # condition 
								changed_sch_array_true << changed_sch
								elsif changed_sch_array_false << changed_sch
							end
						end #end fan exhaust availability if loop
					end  # end fan exhaust 
				end # end thermal zone equipment do loop
		end		 #end thermal zone loop
	end	#end do airloop
	
	# not applicable message if there is no airloop or zone exhaust equipment
	if
		fan_exhaust_array.length == 0 or air_loops_array.length == 0
		runner.registerAsNotApplicable("Measure is not applicable.")
		return true
	end #end the not applicable if condition	

		
    # report initial condition of model
    runner.registerInitialCondition("The initial model contained #{fan_exhaust_array.length} 'Fan:ZoneExhaust' object for which this measure is applicable.")

    # report final condition of model
    runner.registerFinalCondition("The Availability schedules for #{changed_sch_array_true.length} 'Fan:ZoneExhaust' schedule(s) were altered to match the availability schedules of supply fans. The unchanged 'Fan: ZoneExhaust' object(s) = #{changed_sch_array_false.length}.")
    return true

  end
  
end

# register the measure to be used by the application
ExhaustFanInterlock.new.registerWithApplication
