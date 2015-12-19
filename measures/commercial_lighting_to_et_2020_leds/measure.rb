# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class CommercialLightingToET2020LEDs < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Commercial Lighting To ET2020 LEDs"
  end

  # human readable description
  def description
    return "Light-emitting diodes (LEDs), a type of solid-state lighting (SSL), offer the electric lighting market a new and revolutionary light source that saves energy and improves light quality, performance, and service. Today, white-light LEDs are competing or are poised to compete successfully with conventional lighting sources across a variety of general illumination applications due to their ability to offer high quality and cost-effective performance.  By 2020 DOE ET has an efficacy goal of 193 lm/W, which is roughly double the current state-of-the-art T8 linear fluorescent lighting."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Assume that the starting point technology is primarily 90.1-2013 T8 lighting, with an efficacy of 90 lm/W.  According to Table 5.2, LED Efficacy Improvement, in (1), 2015 LED luminaire efficacy is projected to be 193 lm/W.  Calculate the total lighting power of the model and divide by this initial efficacy to determine the total number of lumens needed.    Assuming that this same number of lumens should be provided by LED lighting, divide by the LED efficacy to determine the total wattage of LEDs that would be necessary to achieve the same lighting.  Reduce the overall building lighting power by the resulting multiplier.  IE new LPD = old LPD * (1 - 90 lm/W /193 lm/W). This is a very crude estimate of the impact of current LED technology.  In order to perform a more nuanced analysis, lighting in the prototype buildings should be broken down by use type (general space lighting, task lighting, etc.) and by currently assumed technology (T12, T8, metal halide, etc.).  If this breakdown were available, each type of lighting could be modified according to its own efficacy characteristics.  Additionally, this measure does not account for the impact of LEDs on outdoor lighting."
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
 
    initial_efficacy = 90.0 # 90 lm/W assuming 90.1-2013 T8 lighting
    target_efficacy = 193.0 # 193 lm/W, from http://apps1.eere.energy.gov/buildings/publications/pdfs/ssl/ssl_energy-savings-report_jan-2012.pdf
 
    runner.registerInfo("The initial lighting efficacy is assumed to be #{initial_efficacy.round(1)} lm/W.")
    runner.registerInfo("The target lighting efficacy is #{target_efficacy.round(1)} lm/W.")

    # report initial condition of model
    initial_lighting_power = model.getBuilding.lightingPower
    runner.registerInitialCondition("The building started with #{initial_lighting_power.round} W of lighting.")
    
    # Determine the wattage multiplier (assumes that providing same 
    # number of lumens is adequate to light space, and that the light
    # would be adequately dispersed by the fixtures.
    ltg_pwr_multiplier = initial_efficacy/target_efficacy
    runner.registerInfo("A multiplier of #{ltg_pwr_multiplier.round(2)} will be used to change the lighting power in the model.")
  
    # Loop through all lights definitions in the model
    # and change the lighting power based on the multiplier.
    model.getLightsDefinitions.each do |lights_def|
      if lights_def.lightingLevel.is_initialized
        lights_def.setLightingLevel(lights_def.lightingLevel.get * ltg_pwr_multiplier)
      elsif lights_def.wattsperSpaceFloorArea.is_initialized
        lights_def.setWattsperSpaceFloorArea(lights_def.wattsperSpaceFloorArea.get * ltg_pwr_multiplier)
      elsif lights_def.wattsperPerson.is_initialized
        lights_def.setWattsperPerson(lights_def.wattsperPerson.get * ltg_pwr_multiplier)
      else
        runner.registerWarning("'#{lights_def.name}' uses no power. Its performance was not altered.")
      end
    end

    # report final condition of model
    final_lighting_power = model.getBuilding.lightingPower
    runner.registerFinalCondition("The building finished with #{final_lighting_power.round} W of lighting.")

    return true

  end
  
end

# register the measure to be used by the application
CommercialLightingToET2020LEDs.new.registerWithApplication
