#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class SupplyAirTemperatureResetBasedOnOutdoorAirTemperature < OpenStudio::Ruleset::ModelUserScript
  
  # human readable name
  def name
    return "Supply Air Temperature Reset Based On Outdoor Air Temperature"
  end

  # human readable description
  def description
    return "Some buildings use a constant supply-air (also referred to discharge-air) temperature set point of 55F. When a building's supply fan system is operational, the supply-air temperature set point value should be automatically adjusting to internal/external conditions that will allow the supply fan to operate more efficiently. The simplest way to implement this strategy is to raise supply-air temperature when the outdoor air is cold and the building is less likely to need cooling.  Supplying this warmer air to the  terminals decreases the amount of reheat necessary at the terminal, saving heating energy."
  end

  # human readable description of modeling approach
  def modeler_description
    return "For each multi-zone system in the model, replace the scheduled supply-air temperature setpoint manager with an outdoor air reset setpoint manager.  When the outdoor temperature is above 75F, supply-air temperature is 55F.  When the outdoor temperature is below 45F, increase the supply-air temperature setpoint to 60F.  When the outdoor temperature is between 45F and 75F, vary the supply-air temperature between 55F and 60F."
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure    
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    
    # Loop through all CAV and VAV fans in the model
    fans = model.getFanConstantVolumes
    fans += model.getFanVariableVolumes
    mz_airloops = []
    airloops_already_some_type_reset = []
    airloops_sat_reset_added = []
    spaces_affected = []
    fans.each do |fan|
    
      # Skip fans that are inside terminals
      next if fan.airLoopHVAC.empty?
    
      # Get the air loop
      air_loop = fan.airLoopHVAC.get
      runner.registerInfo("Found multizone air system '#{air_loop.name}'") 
     
      # Skip single-zone air loops
      if air_loop.thermalZones.size <= 1
        runner.registerInfo("'#{air_loop.name}' is a single-zone system, SAT reset based on OAT not applicable.") 
        next
      end
    
      # Record this as a multizone system
      mz_airloops << air_loop
    
      # Skip air loops that already have some type of SAT reset,
      # (anything other than scheduled).
      unless air_loop.supplyOutletNode.setpointManagerScheduled.is_initialized
        runner.registerInfo("'#{air_loop.name}' already has some type of non-schedule-based SAT reset.")
        airloops_already_some_type_reset << air_loop
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
   
      # Add SAT reset based on OAT to this air loop
      lo_oat_f = 45
      lo_oat_c = OpenStudio::convert(lo_oat_f,"F","C").get
      sa_temp_lo_oat_f = 60
      sa_temp_lo_oat_c = OpenStudio::convert(sa_temp_lo_oat_f,"F","C").get
      hi_oat_f = 75
      hi_oat_c = OpenStudio::convert(hi_oat_f,"F","C").get
      sa_temp_hi_oat_f = 55
      sa_temp_hi_oat_c = OpenStudio::convert(sa_temp_hi_oat_f,"F","C").get
      sa_stpt_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
      sa_stpt_manager.setName("#{air_loop.name} SAT OAT reset setpoint")
      sa_stpt_manager.setSetpointatOutdoorLowTemperature(sa_temp_lo_oat_c)
      sa_stpt_manager.setOutdoorLowTemperature(lo_oat_c)
      sa_stpt_manager.setSetpointatOutdoorHighTemperature(sa_temp_hi_oat_c)
      sa_stpt_manager.setOutdoorHighTemperature(hi_oat_c)
      air_loop.supplyOutletNode.addSetpointManager(sa_stpt_manager)
      runner.registerInfo("Added SAT reset based on OAT to '#{air_loop.name}'.")
      
    end # Next fan
    
    # If the model has no multizone air loops, flag as Not Applicable
    if mz_airloops.size == 0
      runner.registerAsNotApplicable("Not Applicable - The model has no multizone air systems.")
      return true
    end
    
    # If all air loops already have SP reset, flag as Not Applicable
    if airloops_already_some_type_reset.size == mz_airloops.size
      runner.registerAsNotApplicable("Not Applicable - All multizone air systems in the model already have some type of non-schedule-based SAT reset.")
      return true
    end    
    
    # Report the initial condition
    runner.registerInitialCondition("The model started with #{airloops_sat_reset_added.size} multi-zone air systems that did not have SAT resetw.")
    
    # Report the final condition
    airloops_sat_reset_added_names = []
    airloops_sat_reset_added.each do |air_loop|
      airloops_sat_reset_added_names << air_loop.name
    end
    
    runner.registerFinalCondition("SAT reset based on OAT control was added to #{airloops_sat_reset_added.size} air systems #{airloops_sat_reset_added_names.join(", ")}.  These air systems served spaces #{spaces_affected.join(", ")}.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
SupplyAirTemperatureResetBasedOnOutdoorAirTemperature.new.registerWithApplication