# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class AddDemandControlVentilation < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Add Demand Control Ventilation"
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

    # This measure is not applicable if apply_measure is false
    if apply_measure == "FALSE"
      runner.registerAsNotApplicable("Not Applicable - User chose not to apply this measure via the apply_measure argument.")
      return true
    end
    
    # Loop through all air loops
    # and add DCV if applicable
    air_loops = []
    air_loops_already_dcv = []
    air_loops_dcv_added = []
    model.getAirLoopHVACs.each do |air_loop|
    
      air_loops << air_loop
    
      # DCV Not Applicable for AHUs that already have DCV
      # or that have no OA intake.
      controller_oa = nil
      controller_mv = nil
      if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
        oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
        controller_oa = oa_system.getControllerOutdoorAir      
        controller_mv = controller_oa.controllerMechanicalVentilation
        if controller_mv.demandControlledVentilation == true
          air_loops_already_dcv << air_loop
          runner.registerInfo("DCV not applicable to '#{air_loop.name}' because DCV already enabled.")
          next
        end
      else
        runner.registerInfo("DCV not applicable to '#{air_loop.name}' because it has no OA intake.")
        next
      end

      # DCV Not Applicable to constant volume systems
      # for this particular measure.     
      if air_loop.supplyComponents("OS:Fan:VariableVolume".to_IddObjectType).size == 0
        runner.registerInfo("DCV not applicable to '#{air_loop.name}' because it is not a VAV system.")
        next
      end
      
      # DCV is applicable to this airloop
      # Change the min flow rate in the controller outdoor air
      controller_oa.setMinimumOutdoorAirFlowRate(0.0)
       
      # Enable DCV in the controller mechanical ventilation
      controller_mv.setDemandControlledVentilation(true)
      runner.registerInfo("Enabled DCV for '#{air_loop.name}'.")
      air_loops_dcv_added << air_loop
            
    end # Next air loop  
      
    # If the model has no air loops, flag as Not Applicable
    if air_loops.size == 0
      runner.registerAsNotApplicable("Not Applicable - The model has no air loops.")
      return true
    end
    
    # If all air loops already have DCV, flag as Not Applicable
    if air_loops_already_dcv.size == air_loops.size
      runner.registerAsNotApplicable("Not Applicable - All air loops already have DCV.")
      return true
    end    

    # If no air loops are eligible for DCV, flag as Not Applicable
    if air_loops_dcv_added.size == 0
      runner.registerAsNotApplicable("Not Applicable - DCV was not applicable to any air loops in the model.")
      return true
    end

    # Report the initial condition
    runner.registerInitialCondition("Model has #{air_loops.size} air loops, #{air_loops_already_dcv.size} of which already have DCV enabled.")
    
    # Report the final condition
    runner.registerFinalCondition("#{air_loops_dcv_added.size} air loops had DCV enabled.")
      
    return true

  end
  
end

# register the measure to be used by the application
AddDemandControlVentilation.new.registerWithApplication
