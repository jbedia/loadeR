#     loadGridData.R Load a user-defined spatio-temporal slice from a gridded dataset
#
#     Copyright (C) 2018 Santander Meteorology Group (http://www.meteo.unican.es)
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program. If not, see <http://www.gnu.org/licenses/>.


#' @title Load a grid from a gridded dataset
#' @description Load a user-defined spatio-temporal slice from a gridded dataset
#' @template templateParams
#' @param members A vector of integers indicating the members to be loaded.
#'  Default to \code{NULL}, which loads all available members if the dataset contains members (i.e. in case a Ensemble Axis is defined).
#'  For instance, \code{members=1:5} will retrieve the first five members of dataset.
#'   Note that unlike \code{\link{loadSeasonalForecast}}, discontinuous member selections (e.g. \code{members=c(1,5,7)}) are NOT allowed. 
#'   If the requested dataset has no Ensemble Axis (or it is a static field, e.g. orography) it will be ignored.
#' @param dictionary Default to FALSE, if TRUE a dictionary is used and the .dic file is stored in the same path than the
#' dataset. If the .dic file is stored elsewhere, then the argument is the full path to the .dic file (including the extension,
#' e.g.: \code{"/path/to/the/dictionary_file.dic"}). This is the case for instance when the dataset is stored in a remote URL,
#' and we have a locally stored dictionary for that particular dataset. If FALSE no variable homogenization takes place,
#' and the raw variable, as originally stored in the dataset, will be returned. See details for dictionary specification.
#' @param time A character vector indicating the temporal filtering/aggregation 
#' of the output data. Default to \code{"none"}, which returns the original time 
#' series as stored in the dataset. For sub-daily variables, instantantaneous data at 
#' selected verification times can be filtered using one of the character strings 
#' \code{"00"}, \code{"03"}, \code{"06"}, \code{"09"}, \code{"12"}, \code{"15"},
#'  \code{"18"}, \code{"21"},and \code{"00"} when applicable. If daily aggregated data are 
#' required use \code{"DD"}. If the requested variable is static (e.g. orography) it will be ignored. 
#' See the next arguments for time aggregation options.
#' @param aggr.d Character string. Function of aggregation of sub-daily data for daily data calculation. 
#' Currently accepted values are \code{"none"}, \code{"mean"}, \code{"min"}, \code{"max"} and \code{"sum"}.
#' @param aggr.m Same as \code{aggr.d}, bun indicating the aggregation function to compute monthly from daily data.
#' If \code{aggr.m = "none"} (the default), no monthly aggregation is undertaken.
#' @param threshold Optional, only needed if absolute/relative frequencies are required. A float number defining the threshold
#'  used by  \code{condition} (the next argument).
#' @param condition Optional, only needed if absolute/relative frequencies are required. Inequality operator to be applied considering the given threshold.
#'  \code{"GT"} = greater than the value of \code{threshold}, \code{"GE"} = greater or equal,
#'   \code{"LT"} = lower than, \code{"LE"} = lower or equal than
#' @template templateReturnGridData
#' @template templateDicDetails  
#' @template templateTimeAggr
#' @template templateGeolocation
#' @export
#' @author J. Bedia, S. Herrera, M. Iturbide, J.M. Gutierrez 
#' @family loading
#' @family loading.grid
#' 
#' @importFrom stats na.exclude
#' @importFrom utils packageVersion tail
#' 
#' @examples \dontrun{
#' #Download dataset
#' dir.create("mydirectory")
#' download.file("http://meteo.unican.es/work/loadeR/data/Iberia_NCEP.tar.gz", 
#' destfile = "mydirectory/Iberia_NCEP.tar.gz")
#' # Extract files from the tar.gz file
#' untar("mydirectory/NCEP_Iberia.tar.gz", exdir = "mydirectory")
#' # First, the path to the ncml file is defined:
#' ncep <- "mydirectory/Iberia_NCEP/Iberia_NCEP.ncml"
#' # Load air temperature at 850 millibar isobaric surface pressure level from the built-in
#' # NCEP dataset, for the Iberian Peninsula in summer (JJA):
#' grid <- loadGridData(ncep, var = "ta@@850", dictionary = TRUE, lonLim = c(-10,5),
#'    latLim = c(35.5, 44.5), season = 6:8, years = 1981:2010)
#' str(grid)   
#' # Calculation of monthly mean temperature:
#' grid.mm <- loadGridData(ncep, var = "ta@@850", dictionary = TRUE, lonLim = c(-10,5),
#'                          latLim = c(35.5, 44.5), season = 6:8,
#'                          years = 1981:2010, aggr.m = "mean")
#' str(grid.mm)
#' 
#' # Same but using the original variable (not harmonized via dictionary):
#' di <- dataInventory(ncep)
#' names(di)
#' UDG.vocabulary()
#' # Variable is named 'T', instead of the standard name 'ta' in the vocabulary
#' # Vertical level is indicated using the '@@' symbol:
#' non.standard.grid <- loadGridData(ncep, var = "T@@850", dictionary = FALSE, lonLim = c(-10,5),
#'                                   latLim = c(35.5, 44.5), season = 6:8, 
#'                                   years = 1981:2010, aggr.m = "mean")
#' str(non.standard.grid$Variable)
#' # Note the units are now in Kelvin, as originally stored
#' ## Example of data load from a remote repository via OPeNDAP (NASA dataserver)
#  Definition of the OPeNDAP URL of the dataset
#' ds <- "http://dataserver3.nccs.nasa.gov/thredds/dodsC/bypass/NEX-GDDP/bcsd/rcp85/r1i1p1/tasmax/MIROC-ESM.ncml"
#' # Monthly mean maximum summer 2m temperature at 12:00 UTC over the Iberian Peninsula:
#' # (CMIP5 MIROC-ESM model, RCP 8.5)
#' tasmax <- loadGridData(dataset = ds,
#'                        var = "tasmax",
#'                        lonLim = c(-10,5),
#'                        latLim = c(35,44),
#'                        season = 6:8,
#'                        years = 2021,
#'                        time = "12",
#'                        aggr.m = "mean")
#' 
#'
#'## Example loading frequency data based on threshold exceedances:
#'# This example will use remote data from the EOBS dataset loaded from the KNMI's OPenDAP server
#'# Note that the URL of the dataset is not persistent, and changes with updated versions,
#'# so this example is not guaranteed to work in the future. You can check the latest dataset
#'# version and its corresponding URL at the following link:
#'# <http://www.ecad.eu/download/ensembles/download.php>

#'require(transformeR)
#'require(visualizeR)
#'ds <- "http://opendap.knmi.nl/knmi/thredds/dodsC/e-obs_0.50regular/tx_0.50deg_reg_v16.0.nc"

#'# The following call will load the annual number of days above 25 degrees C
#'# (Number of summer days, 'SU' according to ETCCDI/CRD climate change indices
#'# <http://etccdi.pacificclimate.org/list_27_indices.shtml>)

#'tx25 <- loadGridData(dataset = ds,
#'                     var = "tx",
#'                     lonLim = c(-10,5),
#'                     latLim = c(35,44),
#'                     season = 1:12,
#'                     years = 1981:1990,
#'                     aggr.m = "sum", 
#'                     threshold = 25,
#'                     condition = "GT")
#'
#'# Note the use of threshold = 25, and condition = "GT" (i.e. strictly Greater Than)
#'# In the next lines the data are annualy aggregated and the correposnding climatological
#'# map is displayed:
#'
#'tx25.annual <- aggregateGrid(tx25, aggr.y = list(FUN = "sum"))
#'spatialPlot(climatology(tx25.annual), main = "Number of Summer Days 1981-1990")
#'
#'# Note that the relative frequency (i.e., proportion of days instead of absolute frequency),
#'# can be obtained by just indicating the argument 'aggr.m = "mean"'
#' }


loadGridData <- function(dataset,
                         var,
                         dictionary = FALSE,
                         lonLim = NULL,
                         latLim = NULL,
                         season = NULL,
                         years = NULL,
                         members = NULL,
                         time = "none",
                         aggr.d = "none",
                         aggr.m = "none",
                         condition = NULL,
                         threshold = NULL) {
      if (dataset %in% UDG.datasets()$name) {
            datasetind <- which(UDG.datasets()$name == dataset)
            dataset <- as.character(UDG.datasets()$url[datasetind])
      }
      time <- match.arg(time, choices = c("none","00","03","06","09","12","15","18","21","DD"))
      aggr.d <- match.arg(aggr.d, choices = c("none", "mean", "min", "max", "sum"))
      if (time != "DD" & aggr.d != "none") {
            aggr.d <- "none"
            message("NOTE: Argument 'aggr.d' ignored as 'time' was set to ", time)
      }
      aggr.m <- match.arg(aggr.m, choices = c("none", "mean", "min", "max", "sum"))
      # Count aggregations
      if (!is.null(condition)) {
        condition <- match.arg(condition, choices = c("GT", "GE", "LT", "LE"))
        if (is.null(threshold)) {
          stop("A 'threshold' argument value is required given 'condition', with no default", call. = FALSE)
        }
        if (!is.numeric(threshold)) stop("Invalid non-numeric 'threshold' argument value", call. = FALSE)
        if (aggr.m == "none") stop("Invalid 'aggr.m' argument value given 'threshold' and 'condition'", call. = FALSE)
      }
      aux.level <- findVerticalLevel(var)
      var <- aux.level$var
      level <- aux.level$level
      # Dictionary lookup -------------
      cd <- check.dictionary(dataset, var, dictionary, time)
      shortName <- cd$shortName
      dic <- cd$dic
      if (!is.null(season) && (min(season) < 1 | max(season) > 12)) {
            stop("Invalid season definition", call. = FALSE)
      }
      # Discover dataset -------------
      gds <- openDataset(dataset)
      grid <- gds$findGridByShortName(shortName)
      if (is.null(grid)) {
            stop("Variable requested not found\nCheck 'dataInventory' output and/or dictionary 'identifier'.", call. = FALSE)
      }
      # Spatial collocation -------------
      latLon <- getLatLonDomain(grid, lonLim, latLim)
      proj <- grid$getCoordinateSystem()$getProjection()
      if (!proj$isLatLon()) latLon <- adjustRCMgrid(gds, latLon, lonLim, latLim)
      # Read data -------------------
      out <- loadGridDataset(var, grid, dic, level, season, years, members,
                             time, latLon, aggr.d, aggr.m, threshold, condition)
      # Metadata: projection and spatial resolution -------------
      proj <- proj$toString()
      attr(out$xyCoords, which = "projection") <- proj
      attr(out$xyCoords, "resX") <- (tail(out$xyCoords$x, 1) - out$xyCoords$x[1]) / (length(out$xyCoords$x) - 1)
      attr(out$xyCoords, "resY") <- (tail(out$xyCoords$y, 1) - out$xyCoords$y[1]) / (length(out$xyCoords$y) - 1)
      if ("lon" %in% names(out$xyCoords)) {
            attr(out$xyCoords, "resLON") <- NA 
            attr(out$xyCoords, "resLAT") <- NA
      } 
      gds$close()
      # Dimension ordering -------------
      tab <- c("member", "time", "level", "lat", "lon")
      x <- attr(out$Data, "dimensions")
      if (length(x) > 1) {
            b <- na.exclude(match(tab, x))
            dimNames <- x[b]
            out$Data <- aperm(out$Data, perm = b)    
            attr(out$Data, "dimensions")  <- dimNames
      }
      # Member attributes -----------------------------
      if (!is.null(members)) {
            out$Members <- paste0("Member_", members)
            inits <- vector("list", length(members))
            names(inits) <- out$Members
            out$InitializationDates <- inits
      }
      # Source Dataset and other metadata -------------
      attr(out, "dataset") <- dataset
      attr(out, "R_package_desc") <- paste0("loadeR-v", packageVersion("loadeR"))
      attr(out, "R_package_URL") <- "https://github.com/SantanderMetGroup/loadeR"
      attr(out, "R_package_ref") <- "http://dx.doi.org/10.1016/j.cliser.2017.07.001"
      if (grepl("http://meteo\\.unican\\.es", dataset)) {
            attr(out, "source") <- "User Data Gateway"
            attr(out, "URL") <- "<http://meteo.unican.es/trac/wiki/udg>"
      }
      message("[",Sys.time(),"]", " Done")
      return(out)
}     
# End



#' Loads a user-defined subset of a gridded CDM dataset
#' 
#' Loads a user-defined subset from a gridded dataset compliant with the Common
#'  Data Model interface
#' 
#' @author J. Bedia 
#' @export
#' @keywords internal
#' @importFrom rJava .jnull

loadGridDataset <- function(var, grid, dic, level, season, years, members, time, latLon, aggr.d, aggr.m, threshold, condition) {
      ## Check for members 
      ens.axis <- grid$getCoordinateSystem()$getEnsembleAxis()
      if (is.null(ens.axis)) {
            if (!is.null(members)) warning("NOTE: The grid does not contain an Ensemble Axis: 'member' argument was ignored")
            memberPars <- .jnull()
      } else {
            all.members <- ens.axis$getCoordValues()
            if (!all((members - 1) %in% all.members)) stop("Invalid member selection. See 'dataInventory' for details on available members.", call. = FALSE)
            memberPars <- getMemberDomain(grid, members, continuous = TRUE)
      }
      timePars <- getTimeDomain(grid, dic, season, years, time, aggr.d, aggr.m, threshold, condition)
      levelPars <- getVerticalLevelPars(grid, level)
      cube <- makeSubset(grid, timePars, levelPars, latLon, memberPars)
      timePars <- NULL
      isStandard <- FALSE
      if (!is.null(dic)) isStandard <- TRUE
      if (isStandard & is.null(threshold)) {
            cube$mdArray <- dictionaryTransformGrid(dic, timePars = cube$timePars, mdArray = cube$mdArray)
      } 
      if (isTRUE(latLon$revLat)) {
            cube$mdArray <- revArrayLatDim(cube$mdArray)
      }
      Variable <- list("varName" = var, "level" = levelPars$level)
      attr(Variable, "use_dictionary") <- isStandard
      attr(Variable, "description") <- grid$getDescription()
      if (isStandard) {
            vocabulary <- UDG.vocabulary()
            attr(Variable, "units") <- as.character(vocabulary[grep(paste0("^", var, "$"), vocabulary$identifier), 3])
            attr(Variable, "longname") <- as.character(vocabulary[grep(paste0("^", var, "$"), vocabulary$identifier), 2])
      } else {
            attr(Variable, "units") <- grid$getUnitsString()
            attr(Variable, "longname") <- grid$getFullName()
      }
      attr(Variable, "daily_agg_cellfun") <- cube$timePars$aggr.d
      attr(Variable, "monthly_agg_cellfun") <- cube$timePars$aggr.m
      attr(Variable, "verification_time") <- time
      out <- list("Variable" = Variable, "Data" = cube$mdArray, "xyCoords" = latLon$xyCoords, "Dates" = adjustDates(cube$timePars))
      return(out)
}
# End


#' Adjust time/start dates of a loaded object
#' @param timePars Object containing the relevant time parameters
#' @return A list with dates (POSIXct) start and end, defining the interval [start, end)
#' @details Sub-daily information is displayed only in case of subdaily data
#' @author J Bedia 
#' @keywords internal
#' @export

# timePars <- cube$timePars
adjustDates <- function(timePars) {
      interval <- 0
      if (timePars$aggr.m != "none") {
            mon.len <- sapply(timePars$dateSliceList, ndays)
            interval <- mon.len * 86400
      } else if (timePars$aggr.d != "none") {
            timePars$dateSliceList <- format(as.Date(substr(timePars$dateSliceList, 1, 10)), format = "%Y-%m-%d %H:%M:%S", usetz = TRUE) 
            interval <- 86400
      }
      formato <- ifelse(interval[1] == 0, "%Y-%m-%d %H:%M:%S", "%Y-%m-%d")
      dates.end <- format(as.POSIXct(as.POSIXlt(timePars$dateSliceList, tz = "GMT") + interval), format = formato, usetz = TRUE)
      dates.start <- format(as.POSIXct(as.POSIXlt(timePars$dateSliceList, tz = "GMT"), tz = "GMT"), format = formato, usetz = TRUE)
      return(list("start" = dates.start, "end" = dates.end))
}
# End


#' Calculate the number of days of the current month
#' @param d A date (character) in format YYYY-MM-DD...
#' @return The number of days of the current month
#' @references 
#' \url{http://stackoverflow.com/questions/6243088/find-out-the-number-of-days-of-a-month-in-r}
#' @export

ndays <- function(d) {
      as.difftime(tail((28:31)[which(!is.na(as.Date(paste0(substr(d, 1, 8), 28:31), '%Y-%m-%d')))], 1), units = "days")
}
#End
