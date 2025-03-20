#' Compute power
#' You can compute the power of your statistical analysis (params$pwr_level = NULL)
#' or the required sample size for target statistical power (nsample = NULL).
#' 
#' Effect size: You need to define at least eta square for ANOVA comparisons and 
#' effect size for t-test.
#' 
#' C. Yilmaz, 20.03.2025
#'
#' @param design list
#'     design
#'         └─ design$km <- c(k, m) # array, within factors
#'         └─ design$ngroup <- 1 # integer, number of group, only for rmanova
#'         └─ design$type <- 1 # integer, 0: between-effect; 1: within-effect; 2: interaction effect, only for rmanova
#'     if type == superpower
#'     design
#'         └─ design$defn <- "3w*3w" # 3 x 3 within-subject, for example
#'         └─ design$avg_values <- c(500, 520, 540, 490, 510, 530, 480, 500, 520) # average values for dependent variable
#'         └─ design$std = 50 # estimated standard deviation
#'         └─ design$corr_rm = 0.5 # correlation between repeated measures
#'         └─ design$labels = c("Stimulus", "A", "B", "C", "Condition", "1", "2", "3")
#' @param params list
#'     params
#'         └─ params$eta_sqr <- eta_sqr # integer
#'         └─ params$effect   <- effect size # integer
#'         └─ params$pwr_level <- 0.80 # integer, optional; NULL for power calculation
#'         └─ params$sig_level <- 0.05 # integer, optional
#' @param nsample NULL for a priori sample size, integer for power calculation
#' @param type char c("superpower", "pwr.anova", "pwr.f2", "wp")
#'
#' @returns list
#' @export
#'
#' @examples \dontrun{
#' compute.power(design, params, nsample, type)
#' }
compute.power <- function(design, params, nsample, type){
  
  # ---------------------------------------------------------------------------- #
  # When the ANOVA is the right analysis for your experimental design, Superpower
  # is the best option. However, you need to simulate the data for this analysis.
  # Therefore, you need more accurate hypotheses.
  # see https://cran.r-project.org/web/packages/Superpower/vignettes/intro_to_superpower.html
  # 
  # install.packages("Superpower")
  if(type == "superpower"){
    library(Superpower)
  
    # Experimental design
    design_result <- ANOVA_design(
    design = design$defn,  # 3x3 within-subjects 
    n = nsample,  # as a start point to find the required sample size
    mu = design$avg_values,  # average values for dependent variable
    sd = design$std,  # estimated standard deviation
    r = design$corr_rm,  # correlation between repeated measures
    labelnames = design$labels
  )
  
  # simulation for power analysis
  pwr_result <- ANOVA_power(design_result, nsims = 1000)
  }
  
  
  # ---------------------------------------------------------------------------- #
  # If simulation is not possible or not desired, a simpler way is to use pwr.
  # https://cran.r-project.org/web/packages/pwr/pwr.pdf
  # 
  # install.packages("pwr")
  if(type == "pwr.anova"){
    library(pwr)
    
    k = design$km[1] # conditions
    m = design$km[2] # sessions, stimulus type etc. if you want to compare in between sessions 
    # the effect size
    # effect  eta_squared   Cohen's f
    # small   0.01          0.10
    # medium  0.06          0.25
    # large   0.14          0.40
    eta_squared <- params$eta_sqr 
    f_value <- sqrt(eta_squared / (1 - eta_squared))
    if("effect" %in% names(params)){
      f_value <- params$effect
    }
    pwr_aimed <- 0.80 # desired power level
    if("pwr_level" %in% names(params)){
      pwr_aimed <- params$pwr_level
    }
    
    sig_level <- 0.05 # significance level / alpha value
    if("sig_level" %in% names(params)){
      sig_level <- params$sig_level
    }
    
    # calculate power for k x m design, anova
    pwr_result <- pwr.anova.test(
      k = k*m, # number of groups
      n = nsample,  # number of observations per group, i.e., sample size
      f = f_value, # effect size
      sig.level = sig_level, # alpha value
      power = pwr_aimed # desired power
    )
  }
  
  if(type == "pwr.f2"){
    library(pwr)
    
    k = design$km[1] # conditions
    m = design$km[2] # sessions, stimulus type etc. if you want to compare in between sessions 
    # the effect size
    # effect  eta_squared   Cohen's f
    # small   0.01          0.10
    # medium  0.06          0.25
    # large   0.14          0.40
    eta_squared <- params$eta_sqr 
    f_value <- sqrt(eta_squared / (1 - eta_squared))
    if("effect" %in% names(params)){
      f_value <- params$effect
    }
    pwr_aimed <- 0.80 # desired power level
    if("pwr_level" %in% names(params)){
      pwr_aimed <- params$pwr_level
    }
    
    sig_level <- 0.05 # significance level / alpha value
    if("sig_level" %in% names(params)){
      sig_level <- params$sig_level
    }
    
    # calculate power for k x m design, glm
    pwr_result <- pwr.f2.test(
      u = (k - 1)*(m - 1), # degrees of freedom for numerator: n x m design => (n - 1) * (m - 1)
      v = nsample,  # degrees of freedom for denominator, i.e., sample size
      f2 = f_value^2, # effect size
      sig.level = sig_level, # alpha value
      power = pwr_aimed # desired power
    )
  }
  
  # ---------------------------------------------------------------------------- #
  # for power analysis with rmANOVA by using WebPower
  # https://www.rdocumentation.org/packages/WebPower/versions/0.9.4/topics/wp.rmanova
  # 
  # install.packages("WebPower")
  if(type == "wp"){
    library(WebPower)
    
    k = design$km[1] # conditions
    m = design$km[2] # sessions, stimulus type etc. if you want to compare in between sessions 
    # the effect size
    # effect  eta_squared   Cohen's f
    # small   0.01          0.10
    # medium  0.06          0.25
    # large   0.14          0.40
    eta_squared <- params$eta_sqr 
    f_value <- sqrt(eta_squared / (1 - eta_squared))
    if("effect" %in% names(params)){
      f_value <- params$effect
    }
    pwr_aimed <- 0.80 # desired power level
    if("pwr_level" %in% names(params)){
      pwr_aimed <- params$pwr_level
    }
    
    sig_level <- 0.05 # significance level / alpha value
    if("sig_level" %in% names(params)){
      sig_level <- params$sig_level
    }
    
    pwr_result <- wp.rmanova(
    n = nsample,          # Compute required sample size
    ng = design$ngroup[1], # Only one group if it's a within-subjects design
    nm = k*m, # Number of measurements (n*m for n x m design)
    f = f_value,  # Effect size
    nscor = 1, # Nonsphericity correction (assumed sphericity for now)
    alpha = sig_level, # significance level, aka alpha value
    power = pwr_aimed, # desired power 
    type = design$type[1] # 0: between-effect; 1: within-effect; 2: interaction effect
    )
  }
  
  if(type == "paired.ttest"){
    library(pwr)
    
    # Multiple comparison with correction
    num_conditions <- design$km[1] * design$km[2]
    num_comparisons <- (num_conditions * (num_conditions - 1) ) / 2 
    pwr_aimed <- 0.80 # desired power level
    if("pwr_level" %in% names(params)){
      pwr_aimed <- params$pwr_level
    }
    sig_level <- 0.05 # significance level / alpha value
    if("sig_level" %in% names(params)){
      sig_level <- params$sig_level
    }
    d_value <- 0.5 # medium effect size
    if("effect" %in% names(params)){
      d_value <- params$effect
    }
    adjusted_alpha <- sig_level / num_comparisons  # Bonferroni correction
    
    # Power analysis with corrected alpha
    pwr_result <- pwr.t.test(n = nsample,  # NULL if you want to calculate a priori sample size
                             d = d_value,  # Cohen's d, effect size
                             sig.level = adjusted_alpha,  # alpha value
                             power = pwr_aimed,  # desired power level
                             type = "paired",  # type of t test
                             alternative = "two.sided")  # alternative hypothesis
    
  }
  print(pwr_result)
  return(pwr_result)
  
}

