# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require_relative 'resources/HVACSizing.Model'
require_relative 'resources/Standards.Construction'

# start the measure
class AddSmarterShade < OpenStudio::Ruleset::ModelUserScript
	
	# human readable name
	def name
		return "Add SmarterShade"
	end
	
	# human readable description
	def description
		return "Add SmarterShade to Exterior Windows"
	end
	
	# human readable description of modeling approach
	def modeler_description
		return "Add SmarterShade switchable film cartridge to interior side of all exterior windows, by applying a shading control, and two constructions to represent the original window/IGU with the SmarterShade in its clear and tinted states."
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

    # make choice argument for facade
    choices = OpenStudio::StringVector.new
    choices << 'North'
    choices << 'East'
    choices << 'South'
    choices << 'West'
    choices << 'S+W'
    choices << 'E+S+W'

    facade = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("facade", choices,true)
    facade.setDisplayName("Cardinal Direction(s).")
    facade.setDefaultValue("South")
    args << facade

    
    return args
	end
	
	# define what happens when the measure is run
	def run(model, runner, user_arguments)
		super(model, runner, user_arguments)
		    
	    # assign the user inputs to variables
	    # Return N/A if not selected to run
	    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
	    if run_measure == 0
	      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
	      return true     
	    end
	    # facade selection
	    facade = runner.getStringArgumentValue('facade',user_arguments)   
 
		# Run the sizing run
	    if model.runSizingRun("#{Dir.pwd}/SizingRun") == false
	      runner.registerError("Sizing Run for determining the VT and SHGC failed to complete - check eplusout.err to debug.")
	      return false
	    end

		# Init
		shgc = 0.0
		vt = 0.0
		u_factor = 0.0		
		
		# Set 'factors' for performance change with addition of SS units
		# U-factor based on "cellular blind" and WINDOW6 calculations
		# TODO base these factors on mo'betta measured data and existing model constructions, 
		# and alternate SmarterShade applications. Also make into user args.
		ss_factor_vt_clear = 0.450
		ss_factor_vt_tinted = 0.009
		ss_factor_shgc_clear = 0.770
		ss_factor_shgc_tinted = 0.510
		ss_factor_u_clear = 0.570
		ss_factor_u_tinted = 0.570
			
	    # Look up the SGHC and VT for all the 
	    # fenestration constructions in the model 
	    # from the E+ output SQL file.
	    model.getConstructions.each do |const|
	      next unless const.isFenestration
	      next unless const.getNetArea > 0.0
	      shgc = const.calculated_solar_heat_gain_coefficient
	      vt = const.calculated_visible_transmittance
	      u_factor = const.calculated_u_factor
	      runner.registerInfo("#{const.name} = *#{const.name.get.to_s.upcase}*")
	      runner.registerInfo("--E+ calc'd VT = #{vt}")
	      runner.registerInfo("--E+ calc'd SHGC = #{shgc}")
	      runner.registerInfo("--E+ calc'd U-Factor = #{u_factor} W/m^2*K")
      
			# Create the new window constructions
			# - clear state 
			window_material = OpenStudio::Model::SimpleGlazing.new(model)
			window_material.setVisibleTransmittance(vt * ss_factor_vt_clear)
			window_material.setSolarHeatGainCoefficient(shgc * ss_factor_shgc_clear)
			window_material.setUFactor(u_factor * ss_factor_u_clear)
			window_material.setName("Simple Glazing System Mat for #{const.name} with SmarterShade (Clear State) U-#{u_factor * ss_factor_u_clear.round(2)} SHGC #{shgc * ss_factor_shgc_clear.round(2)} VLT #{vt * ss_factor_vt_clear.round(2)}")
			runner.registerInfo("Created Simple Glazing System Mat for #{const.name} with SmarterShade (Clear State) U-#{u_factor * ss_factor_u_clear.round(2)} SHGC #{shgc * ss_factor_shgc_clear.round(2)} VLT #{vt * ss_factor_vt_clear.round(2)}")
			window_construction = OpenStudio::Model::Construction.new(model)
			window_construction.setName("Window with SmarterShade (Clear State) U: #{u_factor * ss_factor_u_clear.round(2)} SHGC: #{shgc * ss_factor_shgc_clear.round(2)} VLT: #{vt * ss_factor_vt_clear.round(2)}")
			window_construction.insertLayer(0, window_material)
			
			# - tinted state 
			window_material2 = OpenStudio::Model::SimpleGlazing.new(model)
			window_material2.setVisibleTransmittance(vt * ss_factor_vt_tinted)
			window_material2.setSolarHeatGainCoefficient(shgc * ss_factor_shgc_tinted)
			window_material2.setUFactor(u_factor * ss_factor_u_tinted)
			window_material2.setName("Simple Glazing System Mat for #{const.name} with SmarterShade (Tinted State) U-#{u_factor * ss_factor_u_tinted.round(2)} SHGC #{shgc * ss_factor_shgc_tinted.round(2)} VLT #{vt * ss_factor_vt_tinted.round(2)}")
			runner.registerInfo("Created Simple Glazing System Mat for #{const.name} with SmarterShade (Tinted State) U-#{u_factor * ss_factor_u_tinted.round(2)} SHGC #{shgc * ss_factor_shgc_tinted.round(2)} VLT #{vt * ss_factor_vt_tinted.round(2)}")
			window_construction2 = OpenStudio::Model::Construction.new(model)
			window_construction2.setName("Window with SmarterShade (Tinted State) U: #{u_factor * ss_factor_u_tinted.round(2)} SHGC: #{shgc * ss_factor_shgc_tinted.round(2)} VLT: #{vt * ss_factor_vt_tinted.round(2)}")
			window_construction2.insertLayer(0, window_material2)
		 
			# make shading control with the ss(tinted) construction
			shading_control = OpenStudio::Model::ShadingControl.new(window_construction2)
			shading_control.setName("SmarterShade on #{const.name}")
			shading_control.setShadingType("SwitchableGlazing")
			shading_control.setShadingControlType("OnIfHighSolarOnWindow")
			shading_control.setSetpoint(27)
      		runner.registerInfo("Created shading control '#{shading_control.name.get}'.")

			# loop through sub surfaces and assign new ss clear state window construction
			total_area_changed_si = 0
			model.getSubSurfaces.each do |sub_surface|
				# get the absoluteAzimuth for the surface so we can categorize it
				absoluteAzimuth =  OpenStudio::convert(sub_surface.azimuth,"rad","deg").get + sub_surface.space.get.directionofRelativeNorth + model.getBuilding.northAxis
				until absoluteAzimuth < 360.0
					absoluteAzimuth = absoluteAzimuth - 360.0
				end
				if facade == "North"
					next if not (absoluteAzimuth >= 315.0 or absoluteAzimuth < 45.0)
				elsif facade == "East"
					next if not (absoluteAzimuth >= 45.0 and absoluteAzimuth < 135.0)
				elsif facade == "South"
					next if not (absoluteAzimuth >= 135.0 and absoluteAzimuth < 225.0)
				elsif facade == "West"
					next if not (absoluteAzimuth >= 225.0 and absoluteAzimuth < 315.0)
				elsif facade == "S+W"
					next if not (absoluteAzimuth >= 135.0 and absoluteAzimuth < 315.0)
				elsif facade == "E+S+W"
					next if not (absoluteAzimuth >= 45.0 and absoluteAzimuth < 315.0)
				else
					runner.registerError("Unexpected value of facade: " + facade + ".")
					return false
				end
				place_shade = true

				if !sub_surface.construction.empty? && sub_surface.construction.get.handle.to_s == const.handle.to_s && sub_surface.outsideBoundaryCondition == "Outdoors" && (sub_surface.subSurfaceType == "FixedWindow" || sub_surface.subSurfaceType == "OperableWindow")
					sub_surface.setConstruction(window_construction)
					# apply shading control to all windows with this original const.
					sub_surface.setShadingControl(shading_control)
					total_area_changed_si += sub_surface.grossArea
				end				
				runner.registerInfo("Applied SmarterShade unit to exterior window with construction '#{const.name}', #{sub_surface.grossArea.round(0)}m^2")
			end
			runner.registerInfo("SmarterShade added to #{total_area_changed_si.round(2)}m^2 of building envelope.") if total_area_changed_si > 0
      
    	end
	end
end

# register the measure to be used by the application
AddSmarterShade.new.registerWithApplication
