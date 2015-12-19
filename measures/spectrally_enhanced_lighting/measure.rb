#start the measure
class SpectrallyEnhancedLighting < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Spectrally Enhanced Lighting"
  end
  
  # human readable description
  def description
    return "Spectrally Enhanced Lighting is a design method that capitalizes on naturally occurring gains in visual efficiency as a consequence of the spectral content of higher CCT light sources. These gains can be translated directly into improved energy efficiency by employing lamps with higher CCT and Color Rendering Index (CRI), such as the 5000K, 80-85 CRI (850) lamp (1).  These lamps can be installed at lighting levels 20% lower than traditional linear fluorescent lighting without occupant acceptance issues."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Find all of the lights in the building, and reduce their powers by the user-specified fraction (default 20%) This default comes from a DOE-funded study.  Do not apply this lighting power reduction in hospital operating rooms or other areas where lighting quality is not similar to that used in offices."
  end  

  # Define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure 

    # Make an argument for reduction percentage
    lighting_power_reduction_percent = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("lighting_power_reduction_percent",true)
    lighting_power_reduction_percent.setDisplayName("Lighting Power Reduction Percentage")
    lighting_power_reduction_percent.setUnits("%")
    lighting_power_reduction_percent.setDefaultValue(20.0)
    args << lighting_power_reduction_percent

    return args
  end

  # Define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    

    lighting_power_reduction_percent = runner.getDoubleArgumentValue("lighting_power_reduction_percent",user_arguments)

     
    
    # Check the lighting_power_reduction_percent and for reasonableness
    if lighting_power_reduction_percent > 100 || lighting_power_reduction_percent < 0
      runner.registerError("Please Enter a Value between 0 and 100 for the Lighting Power Reduction Percentage.")
      return false
    end

    # Report initial condition
    building = model.getBuilding
    building_lighting_power = building.lightingPower
    building_LPD = OpenStudio.convert(building.lightingPowerPerFloorArea,"W/m^2","W/ft^2").get
    runner.registerInitialCondition("The model's initial lighting power was #{building_lighting_power.round} W, a lighting power density of #{building_LPD.round(1)} W/ft^2.")

    # Loop through space types and if they are
    # space types where SEL applies, lower the LPD of
    # the lights definition by the specified percentage.
    lights_defs_sel_added = []
    original_to_sel_lights_defs = {}
    model.getSpaceTypes.each do |space_type|
      # Skip space types that contain no spaces
      next if not space_type.spaces.size > 0
      # Skip spaces where the space type is not identified
      next if space_type.standardsSpaceType.empty?
      # Skip space types where SEL isn't appropriate
      standards_space_type = space_type.standardsSpaceType.get
      space_types_sel_inappropriate = [
        "Anesthesia",
        "Banquet",
        "CleanWork",
        "ER_Exam",
        "ER_NurseStn",
        "ER_Trauma",
        "ER_Triage",
        "Exercise",
        "GuestLounge",
        "GuestRoom",
        "OR",
        "PACU",
        "Storage"
      ]
      if space_types_sel_inappropriate.include?(standards_space_type)
        runner.registerInfo("SEL not applicable to #{space_type.name}, it will not be applied here.")
      end 
       
      # Get the light definitions used by this
      # space type and make clones with reduced LPD
      # to represent SEL.
      space_type.lights.each do |light|
        exist_light_def = light.lightsDefinition
        new_def = nil
        if lights_defs_sel_added.include?(exist_light_def)
          new_def = original_to_sel_lights_defs[exist_light_def]
        else
        
          # Clone lights def and add to hash
          new_def = exist_light_def.clone(model)
          new_def = new_def.to_LightsDefinition.get
          new_def.setName("#{exist_light_def.name} SEL")
          original_to_sel_lights_defs[exist_light_def] = new_def

          # Reduce the LPD of the new lights def
          if new_def.lightingLevel.is_initialized
            new_def.setLightingLevel(new_def.lightingLevel.get - new_def.lightingLevel.get*lighting_power_reduction_percent*0.01)
          elsif new_def.wattsperSpaceFloorArea.is_initialized
            new_def.setWattsperSpaceFloorArea(new_def.wattsperSpaceFloorArea.get - new_def.wattsperSpaceFloorArea.get*lighting_power_reduction_percent*0.01)
          elsif new_def.wattsperPerson.is_initialized
            new_def.setWattsperPerson(new_def.wattsperPerson.get - new_def.wattsperPerson.get*lighting_power_reduction_percent*0.01)
          else
            runner.registerWarning("'#{new_def.name}' is used by one or more instances and has no load values. Its performance was not altered.")
          end
          lights_defs_sel_added << exist_light_def
          runner.registerInfo("Reduced LPD of #{exist_light_def.name} by #{lighting_power_reduction_percent}% to represent SEL.")

        end

        # Link the new definition to the lights instance
        updated_instance = light.setLightsDefinition(new_def.to_LightsDefinition.get)
        
      end #end lights.each do

    end #end space types each do
    
    # Not applicable if no lights definitions were modified
    if lights_defs_sel_added.size == 0
      runner.registerAsNotApplicable("SEL was not applicable to any spaces in the model.")
    end

    # Report final condition
    final_building = model.getBuilding
    final_building_lighting_power = final_building.lightingPower
    final_building_LPD = OpenStudio.convert(final_building.lightingPowerPerFloorArea,"W/m^2","W/ft^2").get
    runner.registerFinalCondition("The model's initial lighting power was #{final_building_lighting_power.round} W, a lighting power density of #{final_building_LPD.round(1)} W/ft^2.")
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
SpectrallyEnhancedLighting.new.registerWithApplication
