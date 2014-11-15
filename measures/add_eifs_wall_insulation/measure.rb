# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class AddEIFSWallInsulation < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Add EIFS Wall Insulation"
  end

  # human readable description
  def description
    return "EIFS is a a layer of insulation that is applied to the outside walls of a building.  It is typically a layer of foam insulation covered by a thin layer of fiber mesh embedded in polymer."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Determine the thickness of Polyisocyanurate insulation required to meet the specified R-value.  Find all the constructions used by exterior walls in the model, clone them, add a layer of insulation to the cloned constructioins, and then assign the construction back to the wall."
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
    
    # Make an argument for insulation R-value
    r_value_ip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("r_value_ip",true)
    r_value_ip.setDisplayName("Insulation R-value")
    r_value_ip.setUnits("ft^2*h*R/Btu")
    r_value_ip.setDefaultValue(30.0)
    args << r_value_ip

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Assign the user inputs to variables
    apply_measure = runner.getStringArgumentValue("apply_measure",user_arguments)
    r_value_ip = runner.getDoubleArgumentValue("r_value_ip",user_arguments)
    
    # This measure is not applicable if apply_measure is false
    if apply_measure == "FALSE"
      runner.registerAsNotApplicable("Not Applicable - User chose not to apply this measure via the apply_measure argument.")
      return true
    end
    
    # Check the r_value_ip for reasonableness
    if r_value_ip <= 0
      runner.registerError("R-value must be greater than 0.  You entered #{r_value_ip}.")
      return false
    end

    # Convert r_value_ip to si
    r_value_si = OpenStudio::convert(r_value_ip, "ft^2*h*R/Btu","m^2*K/W").get
       
    # Create a material for Expanded Polystyrene - Molded Beads
    # https://bcl.nrel.gov/node/34582
    # Expanded Polystyrene - Molded Beads - 1 in.,  ! Name
    # VeryRough,                ! Roughness
    # 0.0254,                   ! Thickness {m}
    # 0.0352,                   ! Conductivity {W/m-K}
    # 24,                       ! Density {kg/m3}
    # 1210,                     ! Specific Heat {J/kg-K}
    ins_layer = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    ins_layer.setRoughness("VeryRough")
    ins_layer.setConductivity(0.0352)
    ins_layer.setDensity(24.0)
    ins_layer.setSpecificHeat(1210.0)
    # Calculate the thickness required to meet the desired R-Value
    reqd_thickness_si = r_value_si * ins_layer.thermalConductivity
    reqd_thickness_ip = OpenStudio.convert(reqd_thickness_si, "m", "in").get
    ins_layer.setThickness(reqd_thickness_si)
    ins_layer.setName("Expanded Polystyrene - Molded Beads - #{reqd_thickness_ip.round(1)} in.") 
    runner.registerInfo("To achieve an R-Value of #{r_value_ip} you need #{ins_layer.name} insulation.")
    
    # Find all exterior walls and get a list of their constructions
    wall_constructions = []
    model.getSurfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" and surface.surfaceType == "Wall"
        if surface.construction.is_initialized
          wall_constructions << surface.construction.get
        end
      end
    end    
    
    # Make clones of all the wall constructions used and the add
    # insulation layer to these new constructions.
    old_to_new_construction_map = {}
    wall_constructions.uniq.each do |wall_construction|
      wall_construction_plus_ins = wall_construction.clone(model).to_Construction.get
      wall_construction_plus_ins.insertLayer(0,ins_layer)    
      old_to_new_construction_map[wall_construction] = wall_construction_plus_ins
    end
    
    # Find all exterior walls and replace their old constructions with the
    # cloned constructions that include the insulation layer.
    area_of_insulation_added_si = 0
    model.getSurfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" and surface.surfaceType == "Wall"
        if surface.construction.is_initialized
          wall_construction = surface.construction.get
          wall_construction_plus_ins = old_to_new_construction_map[wall_construction]
          surface.setConstruction(wall_construction_plus_ins)
          area_of_insulation_added_si += surface.netArea
        end
      end
    end      
    
    # This measure is not applicable if there are no exterior walls
    if area_of_insulation_added_si == 0
      runner.registerAsNotApplicable("Not Applicable - Model does not have any exterior walls to add EIFS insulation to.")
      return true
    end

    # Convert affected area to ft^2 for reporting
    area_of_insulation_added_ip = OpenStudio.convert(area_of_insulation_added_si,"m^2","ft^2").get
    
    # Report the initial condition
    runner.registerInitialCondition("The building has #{area_of_insulation_added_ip.round}ft^2 of exterior walls.")

    # Report the final condition
    runner.registerFinalCondition("#{ins_layer.name} insulation has been applied to #{area_of_insulation_added_ip.round}ft^2 of exterior walls.")
    
    return true

  end
  
end

# register the measure to be used by the application
AddEIFSWallInsulation.new.registerWithApplication
