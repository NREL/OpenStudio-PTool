# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class ElevatorCabLightingControls < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Elevator Cab Lighting Controls"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) reduces the lighting power density in elevators by switching from low efficacy incandescent lamps to LEDs."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This EEM replaces the elevator lighting definition from the baseline value (assumed to coincide with 88 W/elevator cab, or 3.14 W/ft^2) to one representing 100% high-efficacy fixtures, with an effective lighting power of 32 W/elevator cab. The measure identifies the electric equipment load definition whose name includes the words elevator lights and replaces that definition with a new one meeting the high efficacy lighting power. Instance multipliers are applied as per the original load."
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

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    
    init_power = nil
    #get all electric equipment load definitions
    model.getElectricEquipmentDefinitions.each do |equip|
      if equip.name.get.include?("Elevator Lights")
        init_power = equip.designLevel
        if !init_power.empty?
          init_power = init_power.get
        else
          runner.registerWarning("Elevator Lighting Load Definition not defined at a design level.")
        end
      end
    end

    # create new electric equipment load definition for efficient elevator lights
    elev_lights_eff = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elev_lights_eff.setName("High-Efficacy Elevator Lights")
    elev_lights_eff.setDesignLevel(32) #per PNNL Design document for 100% efficacy elevator cab lighting
    runner.registerInfo("Created new Electric Equipment Definition: #{elev_lights_eff.name}.")

    # set counters
    exist_power = 0
    new_power = 0
    lgt_ct = 0
    elev_ct = 0

    # loop through spaces and get electric equipment loads
    model.getSpaces.each do |space|
      elec_equip = space.electricEquipment
      #if elec_equip.is_initialized
      #  elec_equip = elec_equip.get
      #end
      mult = nil
      # check equipment load instances for elevator lights
      elec_equip.each do |equip|
        if equip.name.get.include?("Elevator Lights")
          lgt_ct += 1
          # get existing definition info
          mult = equip.multiplier.to_i
          elev_ct += mult
          existing_def = equip.electricEquipmentDefinition
          exist_light_power = existing_def.designLevel.to_i
          exist_power += exist_light_power * mult
          # change load definition
          equip.setElectricEquipmentDefinition(elev_lights_eff)
          runner.registerInfo("")
          new_power += (elev_lights_eff.designLevel.to_i * mult)
        end
      end
    end

    runner.registerInitialCondition("The initial model contained #{lgt_ct} elevator lighting load instances with a total building elevator lighting power (including multipliers) of #{exist_power} Watts.")

    runner.registerFinalCondition("Elevator lighting power has been changed from #{exist_power} W to #{new_power} W for approximately #{elev_ct} elevator cabs.")


    return true

  end

end

# register the measure to be used by the application
ElevatorCabLightingControls.new.registerWithApplication
