% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/j_summary.R
\name{summ.lm}
\alias{summ.lm}
\alias{j_summ.lm}
\title{Regression summaries with options}
\usage{
\method{summ}{lm}(model, standardize = FALSE, vifs = FALSE,
  confint = FALSE, ci.width = 0.95, robust = FALSE, robust.type = "HC3",
  cluster = NULL, digits = getOption("jtools-digits", default = 3),
  pvals = TRUE, n.sd = 1, center = FALSE, standardize.response = FALSE,
  part.corr = FALSE, model.info = TRUE, model.fit = TRUE,
  model.check = FALSE, ...)
}
\arguments{
\item{model}{A \code{lm} object.}

\item{standardize}{If \code{TRUE}, adds a column to output with standardized regression
coefficients. Default is \code{FALSE}.}

\item{vifs}{If \code{TRUE}, adds a column to output with variance inflation
factors (VIF). Default is \code{FALSE}.}

\item{confint}{Show confidence intervals instead of standard errors? Default
is \code{FALSE}.}

\item{ci.width}{A number between 0 and 1 that signifies the width of the
desired confidence interval. Default is \code{.95}, which corresponds
to a 95\% confidence interval. Ignored if \code{confint = FALSE}.}

\item{robust}{If \code{TRUE}, reports heteroskedasticity-robust standard errors
  instead of conventional SEs. These are also known as Huber-White standard
  errors.

  Default is \code{FALSE}.

  This requires the \code{sandwich} and \code{lmtest} packages to compute the
   standard errors.}

\item{robust.type}{Only used if \code{robust=TRUE}. Specifies the type of
robust standard errors to be used by \code{sandwich}. By default, set to
\code{"HC3"}. See details for more on options.}

\item{cluster}{For clustered standard errors, provide the column name of
the cluster variable in the input data frame (as a string). Alternately,
provide a vector of clusters.}

\item{digits}{An integer specifying the number of digits past the decimal to
report in
the output. Default is 3. You can change the default number of digits for
all jtools functions with \code{options("jtools-digits" = digits)} where
digits is the desired number.}

\item{pvals}{Show p values and significance stars? If \code{FALSE}, these
are not printed. Default is \code{TRUE}, except for merMod objects (see
details).}

\item{n.sd}{If \code{standardize = TRUE}, how many standard deviations should
predictors be divided by? Default is 1, though some suggest 2.}

\item{center}{If you want coefficients for mean-centered variables but don't
want to standardize, set this to \code{TRUE}.}

\item{standardize.response}{Should standardization apply to response variable?
Default is \code{FALSE}.}

\item{part.corr}{Print partial (labeled "partial.r") and semipartial (labeled
"part.r") correlations with the table?
Default is \code{FALSE}. See details about these quantities when robust
standard errors are used.}

\item{model.info}{Toggles printing of basic information on sample size, name of
DV, and number of predictors.}

\item{model.fit}{Toggles printing of R-squared and adjusted R-squared.}

\item{model.check}{Toggles whether to perform Breusch-Pagan test for heteroskedasticity
and print number of high-leverage observations. See details for more info.}

\item{...}{This just captures extra arguments that may only work for other
types of models.}
}
\value{
If saved, users can access most of the items that are returned in the
  output (and without rounding).

 \item{coeftable}{The outputted table of variables and coefficients}
 \item{model}{The model for which statistics are displayed. This would be
   most useful in cases in which \code{standardize = TRUE}.}

 Much other information can be accessed as attributes.
}
\description{
\code{summ} prints output for a regression model in a fashion similar to
\code{summary}, but formatted differently with more options.
}
\details{
By default, this function will print the following items to the console:
\itemize{
  \item The sample size
  \item The name of the outcome variable
  \item The R-squared value plus adjusted R-squared
  \item A table with regression coefficients, standard errors, t-values, and
   p values.
}

 There are several options available for \code{robust.type}. The heavy lifting
 is done by \code{\link[sandwich]{vcovHC}}, where those are better described.
 Put simply, you may choose from \code{"HC0"} to \code{"HC5"}. Based on the
 recommendation of the developers of \pkg{sandwich}, the default is set to
 \code{"HC3"}. Stata's default is \code{"HC1"}, so that choice may be better
 if the goal is to replicate Stata's output. Any option that is understood by
 \code{vcovHC} will be accepted. Cluster-robust standard errors are computed
 if \code{cluster} is set to the name of the input data's cluster variable
 or is a vector of clusters.

 The \code{standardize} and \code{center} options are performed via refitting
 the model with \code{\link{scale_lm}} and \code{\link{center_lm}},
 respectively. Each of those in turn uses \code{\link{gscale}} for the
 mean-centering and scaling.

 If using \code{part.corr = TRUE}, then you will get these two common
 effect size metrics on the far right two columns of the output table.
 However, it should be noted that these do not go hand in hand with
 robust standard error estimators. The standard error of the coefficient
 doesn't change the point estimate, just the uncertainty. However,
 this function uses \emph{t}-statistics in its calculation of the
 partial and semipartial correlation. This provides what amounts to a
 heteroskedasticity-adjusted set of estimates, but I am unaware of any
 statistical publication that validates this type of use. Please
 use these as a heuristic when used alongside robust standard errors; do
 not report the "robust" partial and semipartial correlations in
 publications.

 There are two pieces of information given for \code{model.check}, provided that
 the model is an \code{lm} object. First, a Breusch-Pagan test is performed with
 \code{\link[car]{ncvTest}}. This is a
 hypothesis test for which the alternative hypothesis is heteroskedastic errors.
 The test becomes much more likely to be statistically significant as the sample
 size increases; however, the homoskedasticity assumption becomes less important
 to inference as sample size increases (Lumley, Diehr, Emerson, & Lu, 2002).
 Take the result of the test as a cue to check graphical checks rather than a
 definitive decision. Note that the use of robust standard errors can account
 for heteroskedasticity, though some oppose this approach (see King & Roberts,
 2015).

 The second piece of information provided by setting \code{model.check} to
 \code{TRUE} is the number of high leverage observations. There are no hard
 and fast rules for determining high leverage either, but in this case it is
 based on Cook's Distance. All Cook's Distance values greater than (4/N) are
 included in the count. Again, this is not a recommendation to locate and
 remove such observations, but rather to look more closely with graphical and
 other methods.
}
\examples{
# Create lm object
fit <- lm(Income ~ Frost + Illiteracy + Murder, data = as.data.frame(state.x77))

# Print the output with standardized coefficients and 2 digits past the decimal
summ(fit, standardize = TRUE, digits = 2)

}
\references{
King, G., & Roberts, M. E. (2015). How robust standard errors expose
 methodological
 problems they do not fix, and what to do about it. \emph{Political
  Analysis},
  \emph{23}(2), 159–179. \url{https://doi.org/10.1093/pan/mpu015}

Lumley, T., Diehr, P., Emerson, S., & Chen, L. (2002). The Importance of the
Normality Assumption in Large Public Health Data Sets.
 \emph{Annual Review of
 Public Health}, \emph{23}, 151–169.
 \url{https://doi.org/10.1146/annurev.publhealth.23.100901.140546}
}
\seealso{
\code{\link{scale_lm}} can simply perform the standardization if
 preferred.

 \code{\link{gscale}} does the heavy lifting for mean-centering and scaling
 behind the scenes.
}
\author{
Jacob Long <\email{long.1377@osu.edu}>
}