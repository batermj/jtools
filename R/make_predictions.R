
#' @rdname make_predictions
#' @export

make_predictions <- function(model, ...) {

  UseMethod("make_predictions")

}

#### Default method ########################################################

#' @title Generate predicted data for plotting results of regression models
#'
#' @description This is an alternate interface to the underlying tools that
#'   make up [interact_plot()], [effect_plot()], and [cat_plot()].
#'   `make_predictions` creates the data to be plotted and adds information
#'   to the original data to make it more amenable for plotting with the
#'   predicted data.
#'
#' @inheritParams interact_plot
#' @param pred The name of the predictor variable involved
#'  in the interaction. This must be a string.
#'
#' @param modx The name of the moderator variable involved
#'  in the interaction. This must be a string.
#'
#' @param mod2 Optional. The name of the second moderator
#'  variable involved in the interaction. This can be a bare name or string.
#'
#' @param predvals Which values of the predictor should be included in the
#'   plot? By default, all levels are included.
#'
#' @param preds.per.level For continuous predictors, a series of equally
#'  spaced points across the observed range of the predictor are used to
#'  create the lines for each level of the moderator. Use this to choose
#'  how many points are used for that. Default is 100, but for complicated
#'  models larger numbers may better capture the curvature.
#'
#' @param ... Ignored.
#'
#'
#'
#' @family plotting tools
#' @importFrom stats coef coefficients lm predict sd qnorm getCall model.offset
#' @importFrom stats median ecdf quantile get_all_vars complete.cases
#' @rdname make_predictions
#' @export

make_predictions.default <-
  function(model, pred, predvals = NULL,
           modx = NULL, modxvals = NULL,
           mod2 = NULL, mod2vals = NULL,
           centered = "all", data = NULL, plot.points = FALSE, interval = FALSE,
           int.width = .95, outcome.scale = "response", linearity.check = FALSE,
           robust = FALSE, cluster = NULL, vcov = NULL, set.offset = 1,
           pred.labels = NULL, modx.labels = NULL, mod2.labels = NULL,
           int.type = c("confidence","prediction"), preds.per.level = 100,
           ...) {

  # Avoid CRAN barking
  d <- facvars <- wts <- wname <- NULL

  # This internal function has side effects that create
  # objects in this environment
  data_checks(model = model, data = data, predvals = predvals,
              modxvals = modxvals, mod2vals = mod2vals,
              pred.labels = pred.labels, modx.labels = modx.labels,
              mod2.labels = mod2.labels)

  # # Check for factor predictor
  # if (is.factor(d[[pred]])) {
  #   # I could assume the factor is properly ordered, but that's too risky
  #   stop("Focal predictor (\"pred\") cannot be a factor. Either",
  #        " use it as modx, convert it to a numeric dummy variable,",
  #        " or use the cat_plot function for factor by factor interaction",
  #        " plots.")
  # }

#### Prep data for predictions ##############################################

  prepped <- prep_data(model = model, d = d, pred = pred, modx = modx,
                       mod2 = mod2, modxvals = modxvals, mod2vals = mod2vals,
                       survey = FALSE, modx.labels = modx.labels,
                       mod2.labels = mod2.labels, wname = wname,
                       weights = weights, wts = wts,
                       linearity.check = linearity.check,
                       interval = interval, set.offset = set.offset,
                       facvars = facvars, centered = centered,
                       preds.per.level = preds.per.level,
                       predvals = predvals, pred.labels = pred.labels)

  pm <- prepped$pm
  d <- prepped$d
  resp <- prepped$resp
  facmod <- prepped$facmod
  modxvals2 <- prepped$modxvals2
  modx.labels <- prepped$modx.labels
  mod2vals2 <- prepped$mod2vals2
  mod2.labels <- prepped$mod2.labels

#### Predicting with update models ############################################

  # Create predicted values based on specified levels of the moderator,
  # focal predictor

  if (!is.null(modx)) {
    pms <- split(pm, pm[[modx]])
  } else {
    pms <- list(pm)
  }

  if (!is.null(mod2)) {
    pms <- unlist(
        lapply(pms, function(x, y) {split(x, x[[y]])}, y = mod2),
        recursive = FALSE
      )
  }

  for (i in seq_along(pms)) {

    if (robust == FALSE) {
      predicted <- as.data.frame(predict(model, newdata = pms[[i]],
                                         se.fit = interval,
                                         interval = int.type[1],
                                         type = outcome.scale))
    } else {

      if (is.null(vcov)) {
        the_vcov <- do_robust(model, robust, cluster, data)$vcov
      } else {
        the_vcov <- vcov
      }

      predicted <- as.data.frame(predict_rob(model, newdata = pms[[i]],
                                             se.fit = interval,
                                             interval = int.type[1],
                                             type = outcome.scale,
                                             .vcov = the_vcov))
    }

    pms[[i]][[resp]] <- predicted[[1]] # this is the actual values

    ## Convert the confidence percentile to a number of S.E. to multiply by
    intw <- 1 - ((1 - int.width)/2)
    ses <- qnorm(intw, 0, 1)

    # See minimum and maximum values for plotting intervals
    if (interval == TRUE) { # only create SE columns if intervals are needed
        pms[[i]][["ymax"]] <- pms[[i]][[resp]] + (predicted[["se.fit"]]) * ses
        pms[[i]][["ymin"]] <- pms[[i]][[resp]] - (predicted[["se.fit"]]) * ses
    } else {
      # Do nothing
    }

    pms[[i]] <- pms[[i]][complete.cases(pms[[i]]),]

  }

  pm <- do.call("rbind", pms)

  # Labels for values of moderator
  if (!is.null(modx)) {
    pm[[modx]] <- factor(pm[[modx]], levels = modxvals2, labels = modx.labels)
  }
  if (facmod == TRUE) {
    d[[modx]] <- factor(d[[modx]], levels = modxvals2, labels = modx.labels)
  }
  if (!is.null(modx)) {
    pm$modx_group <- pm[[modx]]
  }

  # Setting labels for second moderator
  if (!is.null(mod2)) {

    # Convert character moderators to factor
    if (is.character(d[[mod2]])) {
      d[[mod2]] <- factor(d[[mod2]], levels = mod2vals2, labels = mod2.labels)
    }

    pm[[mod2]] <- factor(pm[[mod2]], levels = mod2vals2, labels = mod2.labels)

  }

  # Get rid of those ugly row names
  row.names(pm) <- seq(nrow(pm))

  # Set up return object
  out <- list(predicted = pm, original = d)
  out <- structure(out, modx.labels = modx.labels, mod2.labels = mod2.labels,
                   pred = pred, modx = modx, mod2 = mod2, resp = resp,
                   linearity.check = linearity.check, weights = wts,
                   modxvals2 = modxvals2, mod2vals2 = mod2vals2)
  class(out) <- "predictions"

  return(out)

}


#### svyglm method ##########################################################

#' @export

make_predictions.svyglm <-
  function(model, pred, predvals = NULL, modx = NULL, modxvals = NULL,
    mod2 = NULL, mod2vals = NULL, centered = "all", data = NULL,
    plot.points = FALSE, interval = FALSE, int.width = .95,
    outcome.scale = "response", linearity.check = FALSE, set.offset = 1,
    pred.labels = NULL, modx.labels = NULL, mod2.labels = NULL,
    int.type = c("confidence","prediction"), preds.per.level = 100, ...) {

  design <- model$survey.design
  # assign("design", design, pos = parent.frame())
  d <- design$variables

  # weights? a bit misleading, but FALSE for svyglm
  weights <- FALSE
  wname <- NULL
  wts <- weights(design) # for use with points.plot aesthetic

  facvars <- names(which(sapply(d, is.factor)))

  # # Check for factor predictor
  # if (is.factor(d[[pred]])) {
  #   # I could assume the factor is properly ordered, but that's too risky
  #   stop("Focal predictor (\"pred\") cannot be a factor. Either",
  #        " use it as modx, convert it to a numeric dummy variable,",
  #        " or use the cat_plot function for factor by factor interaction",
  #        " plots.")
  # }

  # offset?
  if (!is.null(model.offset(model.frame(model)))) {

    off <- TRUE
    offname <- get_offname(model, TRUE)

  } else {

    off <- FALSE
    offname <- NULL

  }

#### Prep data for predictions ##############################################

  prepped <- prep_data(model = model, d = d, pred = pred, modx = modx,
                       mod2 = mod2, modxvals = modxvals, mod2vals = mod2vals,
                       survey = TRUE, modx.labels = modx.labels,
                       mod2.labels = mod2.labels, wname = wname,
                       weights = weights, wts = wts,
                       linearity.check = linearity.check,
                       interval = interval, set.offset = set.offset,
                       facvars = facvars, centered = centered,
                       preds.per.level = preds.per.level,
                       predvals = predvals, pred.labels = pred.labels)

  pm <- prepped$pm
  d <- prepped$d
  resp <- prepped$resp
  facmod <- prepped$facmod
  modxvals2 <- prepped$modxvals2
  modx.labels <- prepped$modx.labels
  mod2vals2 <- prepped$mod2vals2
  mod2.labels <- prepped$mod2.labels

#### Predicting with update models ############################################

  # Create predicted values based on specified levels of the moderator,
  # focal predictor

  if (!is.null(modx)) {
    pms <- split(pm, pm[[modx]])
  } else {
    pms <- list(pm)
  }

  if (!is.null(mod2)) {
    pms <- unlist(
      lapply(pms, function(x, y) {split(x, x[[y]])}, y = mod2),
      recursive = FALSE
    )
  }

  for (i in seq_along(pms)) {

    predicted <- as.data.frame(predict(model, newdata = pms[[i]],
                                       se.fit = TRUE, interval = int.type[1],
                                       type = outcome.scale))

    pms[[i]][[resp]] <- predicted[[1]] # this is the actual values

    ## Convert the confidence percentile to a number of S.E. to multiply by
    intw <- 1 - ((1 - int.width)/2)
    ses <- qnorm(intw, 0, 1)

    # See minimum and maximum values for plotting intervals
    if (interval == TRUE) { # only create SE columns if intervals are needed
        pms[[i]][["ymax"]] <- pms[[i]][[resp]] + (predicted[["SE"]]) * ses
        pms[[i]][["ymin"]] <- pms[[i]][[resp]] - (predicted[["SE"]]) * ses
    } else {
        # Do nothing
    }

    pms[[i]] <- pms[[i]][complete.cases(pms[[i]]),]

  }

  pm <- do.call("rbind", pms)

  # Labels for values of moderator
  if (!is.null(modx)) {
    pm[[modx]] <- factor(pm[[modx]], levels = modxvals2, labels = modx.labels)
  }
  if (facmod == TRUE) {
    d[[modx]] <- factor(d[[modx]], levels = modxvals2, labels = modx.labels)
  }
  if (!is.null(modx)) {
    pm$modx_group <- pm[[modx]]
  }

  # Setting labels for second moderator
  if (!is.null(mod2)) {

    pm[[mod2]] <- factor(pm[[mod2]], levels = mod2vals2, labels = mod2.labels)

    d[[mod2]] <- d$mod2_group

  }

  # Get rid of those ugly row names
  row.names(pm) <- seq(nrow(pm))

  # Set up return object
  out <- list(predicted = pm, original = d)
  out <- structure(out, modx.labels = modx.labels, mod2.labels = mod2.labels,
                   pred = pred, modx = modx, mod2 = mod2, resp = resp,
                   linearity.check = linearity.check, weights = wts,
                   modxvals2 = modxvals2, mod2vals2 = mod2vals2)
  class(out) <- "predictions"

  return(out)

}

#### merMod method ##########################################################

#' @export

make_predictions.merMod <-
  function(model, pred, predvals = NULL, modx = NULL, modxvals = NULL,
           mod2 = NULL, mod2vals = NULL, centered = "all", data = NULL,
           plot.points = FALSE, interval = FALSE,
           int.width = .95, outcome.scale = "response", linearity.check = FALSE,
           set.offset = 1, pred.labels = NULL, modx.labels = NULL,
           mod2.labels = NULL, int.type = c("confidence","prediction"),
           preds.per.level = 100, boot = FALSE, sims = 100, ...) {

  # Avoid CRAN barking
  d <- facvars <- wts <- wname <- NULL

  # This internal function has side effects that create
  # objects in this environment
  data_checks(model = model, data = data, predvals = predvals,
              modxvals = modxvals, mod2vals = mod2vals,
              pred.labels = pred.labels, modx.labels = modx.labels,
              mod2.labels = mod2.labels)

#### Prep data for predictions ##############################################

  prepped <- prep_data(model = model, d = d, pred = pred, modx = modx,
                       mod2 = mod2, modxvals = modxvals, mod2vals = mod2vals,
                       survey = FALSE, modx.labels = modx.labels,
                       mod2.labels = mod2.labels, wname = wname,
                       weights = weights, wts = wts,
                       linearity.check = linearity.check,
                       interval = interval, set.offset = set.offset,
                       facvars = facvars, centered = centered,
                       preds.per.level = preds.per.level,
                       predvals = predvals, pred.labels = pred.labels)

  pm <- prepped$pm
  d <- prepped$d
  resp <- prepped$resp
  facmod <- prepped$facmod
  modxvals2 <- prepped$modxvals2
  modx.labels <- prepped$modx.labels
  mod2vals2 <- prepped$mod2vals2
  mod2.labels <- prepped$mod2.labels

#### Predicting with update models ############################################

  # Create predicted values based on specified levels of the moderator,
  # focal predictor

  if (!is.null(modx)) {
    pms <- split(pm, pm[[modx]])
  } else {
    pms <- list(pm)
  }

  if (!is.null(mod2)) {
    pms <- unlist(
      lapply(pms, function(x, y) {split(x, x[[y]])}, y = mod2),
      recursive = FALSE
    )
  }

  for (i in seq_along(pms)) {


    if (interval == FALSE) {
      predicted <- as.data.frame(predict(model, newdata = pms[[i]],
                                  type = outcome.scale, allow.new.levels = F,
                                  re.form = ~0))

      pms[[i]][[resp]] <- predicted[[1]] # this is the actual values

    } else if (interval == TRUE) {
      # only create SE columns if intervals are needed

      message("Confidence intervals for merMod models is an experimental ",
              "feature.\nThe intervals reflect only the ",
              bold("variance of the fixed effects"), ", not\n",
              "the random effects.")
      predicted <- predict_mer(model, newdata = pms[[i]],
                               use_re_var = FALSE, se.fit = TRUE,
                               allow.new.levels = FALSE, type = outcome.scale,
                               re.form = ~0,
                               boot = FALSE, sims = sims, ...)

      ## Convert the confidence percentile to a number of S.E. to multiply by
      intw <- 1 - ((1 - int.width)/2)
      ses <- qnorm(intw, 0, 1)

      pms[[i]][[resp]] <- predicted[[1]] # this is the actual values
      pms[[i]][["ymax"]] <- pms[[i]][[resp]] + (predicted[["se.fit"]]) * ses
      pms[[i]][["ymin"]] <- pms[[i]][[resp]] - (predicted[["se.fit"]]) * ses

    }

    # pms[[i]] <- pms[[i]][complete.cases(pms[[i]]),]

  }

  # Binding those separate frames
  pmic <- do.call("rbind", pms)
  # Storing the complete cases in a variable
  completes <- complete.cases(pmic)
  # If boot is false, then the prediction frame is the complete cases
  if (boot == FALSE) {pm <- pmic[completes,]}

  # Need to do bootstrap separately so all the sims happen in one run
  # Otherwise, the amount of simulations will be misleading and the progress
  # bar won't make sense.
  if (interval == TRUE && boot == TRUE) {

    cat("Bootstrap progress:\n")
    predicted <- predict_mer(model, newdata = pm,
                             use_re_var = FALSE, se.fit = TRUE,
                             allow.new.levels = FALSE, type = outcome.scale,
                             re.form = ~0,
                             boot = TRUE, sims = sims, ...)

    raw_boot <- predicted

    # Set the predicted values at the median
    fit <- sapply(as.data.frame(raw_boot), median)
    upper <- sapply(as.data.frame(raw_boot), quantile, probs = intw)
    lower <- sapply(as.data.frame(raw_boot), quantile, probs = 1 - intw)

    # Add to predicted frame
    pm[[resp]] <- fit
    pm[["ymax"]] <- upper
    pm[["ymin"]] <- lower

    # Drop the cases that should be missing if I had done it piecewise
    pm <- pm[completes,]

  } else {
    raw_boot <- NULL
  }

  # Labels for values of moderator
  if (!is.null(modx)) {
    pm[[modx]] <- factor(pm[[modx]], levels = modxvals2, labels = modx.labels)
  }
  if (facmod == TRUE) {
    d[[modx]] <- factor(d[[modx]], levels = modxvals2, labels = modx.labels)
  }
  if (!is.null(modx)) {
    pm$modx_group <- pm[[modx]]
  }

  # Setting labels for second moderator
  if (!is.null(mod2)) {

    pm[[mod2]] <- factor(pm[[mod2]], levels = mod2vals2, labels = mod2.labels)


    d[[mod2]] <- d$mod2_group


  }

  # Get rid of those ugly row names
  row.names(pm) <- seq(nrow(pm))

  # Set up return object
  out <- list(predicted = pm, original = d)
  out <- structure(out, modx.labels = modx.labels, mod2.labels = mod2.labels,
                   pred = pred, modx = modx, mod2 = mod2, resp = resp,
                   linearity.check = linearity.check, weights = wts,
                   modxvals2 = modxvals2, mod2vals2 = mod2vals2)
  class(out) <- "predictions"

  return(out)

}