# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class BrushlessDCCompressorMotors < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Low Pressure Drop Air Filters"
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
    
    # Make an argument for the percent COP increase
    cop_increase_percentage = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("cop_increase_percentage",true)
    cop_increase_percentage.setDisplayName("COP Increase Percentage")
    cop_increase_percentage.setUnits("%")
    cop_increase_percentage.setDefaultValue(2.0)
    args << cop_increase_percentage

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
    cop_increase_percentage = runner.getDoubleArgumentValue("cop_increase_percentage",user_arguments)

    # Convert the percent COP increase to a multiplier
    cop_mult = (100 + cop_increase_percentage)/100
    
    # This measure is not applicable if apply_measure is false
    if apply_measure == "FALSE"
      runner.registerAsNotApplicable("Not Applicable - User chose not to apply this measure via the apply_measure argument.")
      return true
    end  
    
    # Check arguments for reasonableness
    if cop_increase_percentage <= 0 || cop_increase_percentage >= 100 
      runner.registerError("COP Increase Percentage must be between 0 and 100")
      return false
    end

    # Loop through all single speed and two speed DX coils
    # and increase their COP by the specified percentage 
    # to reflect higher efficiency compressor motors.
    dx_coils = []
    
    # Two Speed DX Coils
    model.getCoilCoolingDXTwoSpeeds.each do |dx_coil|
      dx_coils << dx_coil
      # Change the high speed COP
      initial_high_cop = dx_coil.ratedHighSpeedCOP
      if initial_high_cop.is_initialized
        initial_high_cop = initial_high_cop.get
        new_high_cop = initial_high_cop * cop_mult
        dx_coil.setRatedHighSpeedCOP(new_high_cop)
        runner.registerInfo("Increased the high speed COP of #{dx_coil.name} from #{initial_high_cop} to #{new_high_cop}.")
      end
      # Change the low speed COP
      initial_low_cop = dx_coil.ratedLowSpeedCOP
      if initial_low_cop.is_initialized
        initial_low_cop = initial_low_cop.get
        new_low_cop = initial_low_cop * cop_mult
        dx_coil.setRatedLowSpeedCOP(new_low_cop)
        runner.registerInfo("Increased the low speed COP of #{dx_coil.name} from #{initial_low_cop} to #{new_low_cop}.")
      end
    end  
          
    # Single Speed DX Coils
    model.getCoilCoolingDXSingleSpeeds.each do |dx_coil|
      dx_coils << dx_coil
      # Change the COP
      initial_cop = dx_coil.ratedCOP
      if initial_cop.is_initialized
        initial_cop = initial_cop.get
        new_cop = OpenStudio::OptionalDouble.new(initial_cop * cop_mult)
        dx_coil.setRatedCOP(new_cop)
        runner.registerInfo("Increased the COP of #{dx_coil.name} from #{initial_cop} to #{new_cop}.")
      end
    end
    
    # Not applicable if no dx coils
    if dx_coils.size == 0
      runner.registerAsNotApplicable("This measure is not applicable because there were no airloops in the building.")
      return true    
    end

    # Report final condition
    runner.registerFinalCondition("Increased the COP in #{dx_coils.size} DX cooling coils by #{cop_increase_percentage}% to reflect the increased efficiency of Brushless DC Motors.")

    return true

  end
  
end

# register the measure to be used by the application
BrushlessDCCompressorMotors.new.registerWithApplication
