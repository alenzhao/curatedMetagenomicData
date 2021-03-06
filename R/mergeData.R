#' Title
#' Merge a list of curatedMetagenomicData datasets
#'
#' @param obj
#' A list or SimpleList containing an ExpressionSet in each element
#' @param sampledelim
#' If a character vector of length one is provided, for example ":" (default) then
#' sample names in the merged ExpressionSet will combine study identifier with sample identifier
#' in the form studyID:sampleID. If not a character vector of length one,
#' then sample names from the original studies will be preserved. Can
#' be set to NULL to keep the sample names of the original studies.
#' @param studycolname
#' If a character vector of length one is provided (default: studyID), a column with this
#' name will be added to the phenoData, containing study IDs taken from
#' the names of the ExpressionSet object.
#'
#' @return an ExpressionSet object
#' @export mergeData
#' @description
#' This function merges a list of ExpressionSet objects produced by the
#' curatedMetagenomicData() function into a single ExpressionSet. It is
#' recommended to use this functions only on a list of datasets of the same
#' data type (for example, all metaphlan_bugs_list datasets).
#' @examples
#' oral <- c("BritoIL_2016.metaphlan_bugs_list.oralcavity",
#'           "Castro-NallarE_2015.metaphlan_bugs_list.oralcavity")
#' esl <- curatedMetagenomicData(oral, dryrun = FALSE)
#' eset <- mergeData(esl)
#' eset
#' pseq <- ExpressionSet2phyloseq(eset)
#' pseq
mergeData <-
    function(obj,
             sampledelim = ":",
             studycolname = "studyID") {
        if(!is(obj, "list") & !is(obj, "SimpleList"))
            stop("obj should be a list.")
        if(!all(sapply(obj, function(x) is(x, "ExpressionSet")))){
            stop("all elements of obj should be ExpressionSet objects")
        }
        if(!is(names(obj), "character") & !all(isUnique(names(obj)))){
            stop("obj should be a named list with unique names.")
        }
        mat <-
            joinListOfMatrices(lapply(obj, Biobase::exprs), columndelim = sampledelim)
        pdat <-
            joinListOfDFs(lapply(obj, Biobase::pData), rowdelim = sampledelim)
        pdat <- pdat[match(colnames(mat), rownames(pdat)), ]
        eset <-
            Biobase::ExpressionSet(assayData = mat, phenoData = AnnotatedDataFrame(pdat))
        return(eset)
    }

joinListOfMatrices <- function(obj, columndelim = ":") {
    rnames <- Reduce(union, lapply(obj, rownames))
    if (is(columndelim, "character")) {
        for (i in seq_along(obj)) {
            colnames(obj[[i]]) <-
                paste(names(obj)[i], colnames(obj[[i]]), sep = columndelim)
        }
    }
    cnames <- unlist(lapply(obj, colnames))
    names(cnames) <- NULL
    if (!all(isUnique(cnames))) {
        stop("Column names are not unique. Set columndelim to a character value")
    }
    output <- matrix(0,
                     nrow = length(rnames),
                     ncol = length(cnames),
                     dimnames = list(rnames, cnames)
    )
    for (i in seq_along(obj)) {
        output[match(rownames(obj[[i]]), rownames(output)),
               match(colnames(obj[[i]]), colnames(output))] <-
            obj[[i]]
    }
    return(output)
}

joinListOfDFs <-
    function(obj,
             rowdelim = ":",
             addstudycolumn = "studyID") {
        for (i in seq_along(obj)) {
            if (is(rowdelim, "character")) {
                rownames(obj[[i]]) <-
                    paste(names(obj)[i], rownames(obj[[i]]), sep = rowdelim)
            }
            obj[[i]]$mergedsubjectID <- rownames(obj[[i]])
        }
        FUN = function(x, y) merge(x, y, all=TRUE)
        bigdf <- Reduce(FUN, obj)
        rownames(bigdf) <- bigdf$mergedsubjectID
        bigdf <- bigdf[, -match("mergedsubjectID", colnames(bigdf))]
        if (is(addstudycolumn, "character")) {
            studyID <- lapply(seq_along(obj), function(i) {
                rep(names(obj)[i], nrow(obj[[i]]))
            })
            bigdf[[addstudycolumn]] <- do.call(c, studyID)
        }
        return(bigdf)
    }
