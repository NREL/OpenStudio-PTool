# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class CoolRoof < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Cool Roof"
  end

  # human readable description
  def description
    return "Use a reflective roofing material to reduce thermal gain through the roof."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Loop through all roofs and set the reflectance and emissivity values to the user specified values.  The default values come from the LEED advanced energy modeling guide."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure 

    # From LEED Advanced Modeling Guide:
    # Cool roofs” (light-colored roof finishes that have low heat
    # absorption) may be modeled to show reduced heat gain.
    # Model proposed roof with solar reflectance greater than 0.70
    # and emittance greater than 0.75 with reflectivity of 0.45
    # (accounting for degradation in actual reflectivity) versus
    # default reflectivity value of 0.30.
    
    roof_thermal_emittance = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("roof_thermal_emittance",true)
    roof_thermal_emittance.setDisplayName("Roof Emittance")
    roof_thermal_emittance.setDefaultValue(0.75)
    args << roof_thermal_emittance

    roof_solar_reflectance = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("roof_solar_reflectance",true)
    roof_solar_reflectance.setDisplayName("Roof Solar Reflectance")
    roof_solar_reflectance.setDefaultValue(0.45)
    args << roof_solar_reflectance

    roof_visible_reflectance = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("roof_visible_reflectance",true)
    roof_visible_reflectance.setDisplayName("Roof Visible Reflectance")
    roof_visible_reflectance.setDefaultValue(0.45)
    args << roof_visible_reflectance  
    
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
    
    #assign the user inputs to variables
    roof_thermal_emittance = runner.getDoubleArgumentValue("roof_thermal_emittance",user_arguments)
    roof_solar_reflectance = runner.getDoubleArgumentValue("roof_solar_reflectance",user_arguments)
    roof_visible_reflectance = runner.getDoubleArgumentValue("roof_visible_reflectance",user_arguments)
    
    # Translate the user inputs to model inputs
    # Thermal Absorptance: For long wavelength radiant exchange, thermal emissivity
    # and thermal emittance are equal to thermal absorptance.
    thermal_absorptance = roof_thermal_emittance
    # Solar Absorptance: equal to 1.0 minus reflectance (for opaque materials) 
    solar_absorptance = 1.0 - roof_solar_reflectance
    # Visible Absorptance: equal to 1.0 minus reflectance
    visible_absorptance = 1.0 - roof_visible_reflectance
    
    # Loop through surfaces and modify the
    # exterior material of any roof construction
    materials_already_changed = []
    model.getSurfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" && surface.surfaceType == "RoofCeiling"
        # Skip surfaces with no construction assigned
        next if surface.construction.empty?
        cons = surface.construction.get
        # Skip surfaces that don't use a layered construction
        next if cons.to_LayeredConstruction.empty?
        cons = cons.to_LayeredConstruction.get
        layers = cons.layers
        # Skip surfaces whose construction has no layers
        next if layers.size == 0
        outside_material = layers[0]
        # Skip surfaces whose outside material isn't opaque
        next if outside_material.to_StandardOpaqueMaterial.empty?
        # Skip the material if it has already been updated
        next if materials_already_changed.include?(outside_material)
        # Update the material properties
        outside_material = outside_material.to_StandardOpaqueMaterial.get
        outside_material.setThermalAbsorptance(thermal_absorptance)
        outside_material.setSolarAbsorptance(solar_absorptance)
        outside_material.setVisibleAbsorptance(visible_absorptance)
        runner.registerInfo("Change the properties of #{outside_material.name} in #{cons.name} to reflect application of a cool roof.")
        materials_already_changed << outside_material
      end
    end    

    return true

  end
  
end

# register the measure to be used by the application
CoolRoof.new.registerWithApplication
