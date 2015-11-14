load("ptool_static_pressure_reset_results.RData")
load("ptool_static_pressure_reset_metadata.RData")

building_type <- unique(results$create_doe_prototype_building.building_type)
climate_zone <- unique(results$create_doe_prototype_building.climate_zone)
building_vintage <- unique(results$create_doe_prototype_building.template)

variables <- metadata$name[which(metadata$type_of_variable == "variable")]
variables_display <- metadata$display_name_short[which(metadata$type_of_variable == "variable")]
outputs <- metadata$name[which( metadata$type_of_variable=="output")]
applicable <- outputs[which(grepl("applicable",outputs))]
outputs <- outputs[which(!grepl("applicable",outputs))]
applicable <- applicable[applicable != "create_doe_prototype_building.applicable"]
outputs_display <- metadata$display_name_short[which( metadata$type_of_variable=="output")]


for (p in 1:length(variables)){
  applicable_variable <- NULL
  for (r in 1:length(applicable)){
    if (unlist(strsplit(variables[p],"[.]"))[1] == unlist(strsplit(applicable[r],"[.]"))[1]){
      applicable_variable = applicable[r]
    }
  }
  if (is.null(applicable_variable)){
    print(paste("variable",variables[p],"not found"))
    next
  }
  png(paste(gsub(" ","_",variables_display[p]),".png",sep=""), width=10.0, height=10.0, units="in", pointsize=10, res=200)
  par(mfrow=c(4,5))
  for (m in 1:length(outputs)){
    output <- results[,outputs[m]]
    output_applicable <- results[,applicable_variable]
    n <- 1
    percent_diff <- c(0)
    failed <- 0
    for (i in 1:length(building_type)){
      for (j in 1:length(climate_zone)){
        for (k in 1:length(building_vintage)){
          output_applied <- output_applicable[intersect(intersect(intersect(which(results$create_doe_prototype_building.building_type == building_type[i]),which(results$create_doe_prototype_building.climate_zone == climate_zone[j])),which(results$create_doe_prototype_building.template == building_vintage[k])),which(results[,variables[p]] == 1))]
          if(!output_applied){
            print(paste("not applied building_type:",building_type[i],"climate_zone:",climate_zone[j],"building_vintage:",building_vintage[k]))
            next
          }
          temp1 <- building_type[i]
          temp2 <- climate_zone[j]
          temp3 <- building_vintage[k]
          applied <- NA
          baseline <- NA
          applied <- output[intersect(intersect(intersect(which(results$create_doe_prototype_building.building_type == building_type[i]),which(results$create_doe_prototype_building.climate_zone == climate_zone[j])),which(results$create_doe_prototype_building.template == building_vintage[k])),which(results[,variables[p]] == 1))]
          temp <- results
          for(x in 1:length(variables)){
            temp <- subset(temp, temp[,variables[x]]==0)
          }
          baseline <- output[intersect(intersect(which(temp$create_doe_prototype_building.building_type == building_type[i]),which(temp$create_doe_prototype_building.climate_zone == climate_zone[j])),which(temp$create_doe_prototype_building.template == building_vintage[k]))]
          if(length(baseline) != 1){
            print(paste("too many baselines found:",building_type[i],"climate_zone:",climate_zone[j],"building_vintage:",building_vintage[k]))
            stop
          }
          if((length(applied) > 0 ) && (length(baseline) > 0)){
            if(!is.na(baseline) && !is.na(applied)){
              diff <- (applied - baseline)/ (baseline) * 100
              if(!is.nan(diff) && is.finite(diff)){
                percent_diff[n] <- diff
              } else {
                percent_diff[n] <- 0
              } 
              #print(percent_diff[n])
              n <- n+1
              #cat ("Press [enter] to continue")
              #line <- readline()
            } else {
              failed = failed + 1
            }
          } else {
            failed = failed + 1
          }          
        }
      }
    }
    print(outputs[m])
    print(paste("n:",n))
    print(paste("failed:",failed))
    #png(paste(gsub(" ","_",variables_display[p]),"_",outputs_display[m],".png",sep=""), width=8, height=8.0, units="in", pointsize=10, res=200)
    #hist(percent_diff, breaks=c(-5,-2,-1,1,2,5), freq=F, main=outputs_display[m], xlab="% Difference")    
    hist(percent_diff, breaks=20, freq=T, main=outputs_display[m], xlab="% Difference")
  }
  applicable_display <- metadata$display_name_short[which( metadata$name==variables[p])]
  hist(output_applicable*1, breaks=c(0,0.25,0.75,1), freq=T, main=applicable_display, xlab="Is Measure Applicable",xaxt="n")
  axis(side=1,at=c(0,1),labels=c("False","True"))
  dev.off()
}

