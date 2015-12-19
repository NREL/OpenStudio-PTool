#start the measure
class AdvancedWindows < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Advanced Windows"
  end

  # human readable description
  def description
    return "The appropriate high performance windows can reduce energy consumption in some buildings by decreasing heat loss and heat gain.  It is important to ensure that the combinations of properties tested through this measure are physically realistic; the measure will not check this."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure applied user-specified window properties to all exterior windows in the model.  It is important to ensure that the combinations of properties tested through this measure are physically realistic; the measure will not check this."
  end  
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure   
    
    window_r_value_ip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("window_r_value_ip",true)
    window_r_value_ip.setDisplayName("Window R-Value")
    window_r_value_ip.setUnits("ft^2*h*R/Btu")
    window_r_value_ip.setDefaultValue(10.0)
    args << window_r_value_ip

    window_shgc = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("window_shgc",true)
    window_shgc.setDisplayName("Window SHGC")
    window_shgc.setDefaultValue(0.5)
    args << window_shgc

    window_vlt = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("window_vlt",true)
    window_vlt.setDisplayName("Window VLT")
    window_vlt.setDefaultValue(0.6)
    args << window_vlt

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
    
    #assign the user inputs to variables
    window_r_value_ip = runner.getDoubleArgumentValue("window_r_value_ip",user_arguments)
    window_shgc = runner.getDoubleArgumentValue("window_shgc",user_arguments)
    window_vlt = runner.getDoubleArgumentValue("window_vlt",user_arguments)    
    
    # Convert R-Value to SI units
    window_r_value_si = OpenStudio.convert(window_r_value_ip, "ft^2*h*R/Btu","m^2*K/W").get
    window_u_value_si = 1/window_r_value_si

    # Create the new window construction
    window_material = OpenStudio::Model::SimpleGlazing.new(model)
    window_material.setName("Simple Glazing Material R-#{window_r_value_ip} SHGC #{window_shgc} VLT #{window_vlt}")
    window_material.setUFactor(window_u_value_si)
    window_material.setSolarHeatGainCoefficient(window_shgc)
    window_material.setVisibleTransmittance(window_vlt)
    window_construction = OpenStudio::Model::Construction.new(model)
    window_construction.setName("Window R-#{window_r_value_ip} SHGC #{window_shgc} VLT #{window_vlt}")
    window_construction.insertLayer(0, window_material)
     
    # loop through sub surfaces and hard-assign
    # new window construction.
    total_area_changed_si = 0
    model.getSubSurfaces.each do |sub_surface|
      if sub_surface.outsideBoundaryCondition == "Outdoors" && (sub_surface.subSurfaceType == "FixedWindow" || sub_surface.subSurfaceType == "OperableWindow")
        sub_surface.setConstruction(window_construction)
        total_area_changed_si += sub_surface.grossArea
      end
    end
    
    total_area_changed_ip = OpenStudio.convert(total_area_changed_si, "m^2", "ft^2").get
    runner.registerFinalCondition("Changed #{total_area_changed_ip.round} ft2 of windows to R-#{window_r_value_ip.round(1)}, SHGC = #{window_shgc}, VLT = #{window_vlt}")
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AdvancedWindows.new.registerWithApplication
