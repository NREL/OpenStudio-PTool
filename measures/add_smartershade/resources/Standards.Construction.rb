
class OpenStudio::Model::Construction

  # Get the SHGC as calculated by EnergyPlus
  #
  def calculated_solar_heat_gain_coefficient
   
    construction_name = self.name.get.to_s
   
    shgc = nil

    sql = self.model.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    
      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"
    
      row_id = sql.execAndReturnFirstString(row_query)
      
      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "SHGC row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end
    
      shgc_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass SHGC'
                  AND RowName='#{row_id}'"          
    
    
      shgc = sql.execAndReturnFirstDouble(shgc_query)
      
      if shgc.is_initialized
        shgc = shgc.get
      else
        shgc = nil
      end
            
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Construction', 'Model has no sql file containing results, cannot lookup data.')
    end

    return shgc
      
  end

  # Get the VT as calculated by EnergyPlus
  #
  def calculated_visible_transmittance
   
    construction_name = self.name.get.to_s   
   
    vt = nil
      
    sql = self.model.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    
      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"
    
      row_id = sql.execAndReturnFirstString(row_query)
      
      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "VT row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end
    
      vt_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass Visible Transmittance'
                  AND RowName='#{row_id}'"          
    
    
      vt = sql.execAndReturnFirstDouble(vt_query)
      
      if vt.is_initialized
        vt = vt.get
      else
        vt = nil
      end

    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Space', 'Model has no sql file containing results, cannot lookup data.')
    end

    return vt
      
  end
  
  # Get the U-Factor as calculated by EnergyPlus
  # in W/m^2*K
  def calculated_u_factor
   
    construction_name = self.name.get.to_s   
   
    u_factor_w_per_m2_k = nil
      
    sql = self.model.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    
      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"
    
      row_id = sql.execAndReturnFirstString(row_query)
      
      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "U-Factor row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end
    
      u_factor_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass U-Factor'
                  AND RowName='#{row_id}'"          
    
    
      u_factor_w_per_m2_k = sql.execAndReturnFirstDouble(u_factor_query)
      
      if u_factor_w_per_m2_k.is_initialized
        u_factor_w_per_m2_k = u_factor_w_per_m2_k.get
      else
        u_factor_w_per_m2_k = nil
      end

    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Space', 'Model has no sql file containing results, cannot lookup data.')
    end

    return u_factor_w_per_m2_k
      
  end  
  
end        
 