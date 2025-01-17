# pROC: Tools Receiver operating characteristic (ROC curves) with
# (partial) area under the curve, confidence intervals and comparison. 
# Copyright (C) 2010-2014 Xavier Robin, Alexandre Hainard, Natacha Turck,
# Natalia Tiberti, Frédérique Lisacek, Jean-Charles Sanchez
# and Markus Müller
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

coords <- function(...)
  UseMethod("coords")

coords.smooth.roc <- function(smooth.roc,
                              x,
                              input=c("specificity", "sensitivity"),
                              ret=c("specificity", "sensitivity"),
                              as.list=FALSE,
                              drop=TRUE,
                              best.method=c("youden", "closest.topleft"),
                              best.weights=c(1, 0.5),
                              transpose = FALSE,
                              ...) {
  # make sure x was provided
  if (missing(x))
    stop("'x' must be a numeric or character vector.")
  
  # Warn about future change in transpose <https://github.com/xrobin/pROC/issues/54>
  if (missing(transpose) || is.null(transpose)) {
    transpose <- FALSE
    warning("An upcoming version of pROC will set the 'transpose' argument to FALSE by default. Set transpose = TRUE explicitly to keep the current behavior, or transpose = FALSE to adopt the new one and silence this warning. Type help(coords_transpose) for additional information.")
  }
  
  # match input 
  input <- match.arg(input)
  # match return
  ret <- roc.utils.match.coords.ret.args(ret, threshold = FALSE)

  if (is.character(x)) {
    x <- match.arg(x, c("best")) # no thresholds in smoothed roc: only best is possible
    partial.auc <- attr(smooth.roc$auc, "partial.auc")

    # cheat: allow the user to pass "topleft"
    best.method <- match.arg(best.method[1], c("youden", "closest.topleft", "topleft"))
    if (best.method == "topleft") {
    	best.method <- "closest.topleft"
    }
    optim.crit <- roc.utils.optim.crit(smooth.roc$sensitivities, smooth.roc$specificities,
    								   ifelse(smooth.roc$percent, 100, 1),
    								   best.weights, best.method)
    
    if (is.null(smooth.roc$auc) || identical(partial.auc, FALSE)) {
      se <- smooth.roc$sensitivities[optim.crit==max(optim.crit)]
      sp <- smooth.roc$specificities[optim.crit==max(optim.crit)]
      optim.crit <- optim.crit[optim.crit==max(optim.crit)]
    }
    else {
      if (attr(smooth.roc$auc, "partial.auc.focus") == "sensitivity") {
        optim.crit.partial <- (optim.crit)[smooth.roc$se <= partial.auc[1] & smooth.roc$se >= partial.auc[2]]
        se <- smooth.roc$sensitivities[smooth.roc$sensitivities <= partial.auc[1] & smooth.roc$sensitivities >= partial.auc[2]][optim.crit.partial==max(optim.crit.partial)]
        sp <- smooth.roc$specificities[smooth.roc$sensitivities <= partial.auc[1] & smooth.roc$sensitivities >= partial.auc[2]][optim.crit.partial==max(optim.crit.partial)]
        optim.crit <- optim.crit[smooth.roc$sensitivities <= partial.auc[1] & smooth.roc$sensitivities >= partial.auc[2]][optim.crit.partial==max(optim.crit.partial)]
      }
      else {
        optim.crit.partial <- (optim.crit)[smooth.roc$sp <= partial.auc[1] & smooth.roc$sp >= partial.auc[2]]
        se <- smooth.roc$sensitivities[smooth.roc$specificities <= partial.auc[1] & smooth.roc$specificities >= partial.auc[2]][optim.crit.partial==max(optim.crit.partial)]
        sp <- smooth.roc$specificities[smooth.roc$specificities <= partial.auc[1] & smooth.roc$specificities >= partial.auc[2]][optim.crit.partial==max(optim.crit.partial)]
        optim.crit <- optim.crit[smooth.roc$specificities <= partial.auc[1] & smooth.roc$specificities >= partial.auc[2]][optim.crit.partial==max(optim.crit.partial)]
      }
    }
    
    if (any(! ret %in% c("specificity", "sensitivity", best.method))) {
    	# Deduce additional tn, tp, fn, fp, npv, ppv
    	ncases <- length(attr(smooth.roc, "roc")$cases)
    	ncontrols <- length(attr(smooth.roc, "roc")$controls)
    	substr.percent <- ifelse(smooth.roc$percent, 100, 1)
    	res <- roc.utils.calc.coords(substr.percent, NA, se, sp, ncases, ncontrols, best.weights)
    }
    else {
    	res <- rbind(
    		specificity = sp,
    		sensitivity = se,
    		best.method = ifelse(best.method == "youden", 1, -1) * optim.crit
    	)
    	rownames(res)[3] <- best.method
    }
    colnames(res) <- rep("best", ncol(res))
    
    if (as.list) {
      warning("'as.list' is deprecated and will be removed in a future version.")
    	list <- apply(res[ret, , drop=FALSE], 2, as.list)
    	if (drop == TRUE && length(x) == 1) {
    		return(list[[1]])
    	}
    	return(list)
    }
    else if (transpose) {
      return(res[ret,, drop=drop])
    }
    else {
      if (missing(drop) ) {
        return(as.data.frame(t(res))[, ret])
      }
      else {
        return(as.data.frame(t(res))[, ret, drop=drop])
      }
    }
  }

  # use coords.roc
  smooth.roc$thresholds <- rep(NA, length(smooth.roc$specificities))
  return(coords.roc(smooth.roc, x, input, ret, as.list, drop, transpose = transpose, ...))
}

coords.roc <- function(roc,
                       x,
                       input=c("threshold", "specificity", "sensitivity"),
                       ret=c("threshold", "specificity", "sensitivity"),
                       as.list=FALSE,
                       drop=TRUE,
                       best.method=c("youden", "closest.topleft"),
                       best.weights=c(1, 0.5), 
                       transpose = FALSE,
                       ...) {
  # make sure x was provided
  if (missing(x) || is.null(x) || (length(x) == 0 && !is.numeric(x))) {
    x <- "all"
  }
  else if (length(x) == 0 && is.numeric(x)) {
    stop("Numeric 'x' has length 0")
  }
  
  # Warn about future change in transpose <https://github.com/xrobin/pROC/issues/54>
  if (missing(transpose) || is.null(transpose)) {
    transpose <- FALSE
    warning("An upcoming version of pROC will set the 'transpose' argument to FALSE by default. Set transpose = TRUE explicitly to keep the current behavior, or transpose = FALSE to adopt the new one and silence this warning. Type help(coords_transpose) for additional information.")
  }
  
  # match input 
  input <- match.arg(input)
  # match return
  ret <- roc.utils.match.coords.ret.args(ret)
  # make sure the sort of roc is correct
  roc <- sort(roc)

  if (is.character(x)) {
    x <- match.arg(x, c("all", "local maximas", "best"))
    partial.auc <- attr(roc$auc, "partial.auc")
    if (x == "all") {
      # Pre-filter thresholds based on partial.auc
      if (is.null(roc$auc) || identical(partial.auc, FALSE)) {
        se <- roc$se
        sp <- roc$sp
        thres <- roc$thresholds
      }
      else {
        if (attr(roc$auc, "partial.auc.focus") == "sensitivity") {
          se <- roc$se[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]]
          sp <- roc$sp[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]]
          thres <- roc$thresholds[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]]
        }
        else {
          se <- roc$se[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]]
          sp <- roc$sp[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]]
          thres <- roc$thresholds[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]]
        }
      }
      if (length(thres) == 0) {
      	warning("No coordinates found, returning NULL. This is possibly cased by a too small partial AUC interval.")
      	return(NULL)
      }
      res <- rbind(
      	threshold = thres,
      	specificity = sp,
      	sensitivity = se
      )
      cn <- rep(x, ncol(res))
    }
    else if (x == "local maximas") {
      # Pre-filter thresholds based on partial.auc
      if (is.null(roc$auc) || identical(partial.auc, FALSE)) {
        se <- roc$se
        sp <- roc$sp
        thres <- roc$thresholds
      }
      else {
        if (attr(roc$auc, "partial.auc.focus") == "sensitivity") {
          se <- roc$se[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]]
          sp <- roc$sp[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]]
          thres <- roc$thresholds[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]]
        }
        else {
          se <- roc$se[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]]
          sp <- roc$sp[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]]
          thres <- roc$thresholds[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]]
        }
      }
      if (length(thres) == 0) {
      	warning("No coordinates found, returning NULL. This is possibly cased by a too small partial AUC interval.")
      	return(NULL)
      }
      lm.idx <- roc.utils.max.thresholds.idx(thres, sp=sp, se=se)
      res <- rbind(
      	threshold = thres[lm.idx],
      	specificity = sp[lm.idx],
      	sensitivity = se[lm.idx]
      )
      cn <- rep(x, ncol(res))
    }
    else { # x == "best"
      # cheat: allow the user to pass "topleft"
      best.method <- match.arg(best.method[1], c("youden", "closest.topleft", "topleft"))
      if (best.method == "topleft") {
        best.method <- "closest.topleft"
      }
      optim.crit <- roc.utils.optim.crit(roc$sensitivities, roc$specificities,
      								   ifelse(roc$percent, 100, 1),
      								   best.weights, best.method)

      # Filter thresholds based on partial.auc
      if (is.null(roc$auc) || identical(partial.auc, FALSE)) {
      	se <- roc$se[optim.crit==max(optim.crit)]
      	sp <- roc$sp[optim.crit==max(optim.crit)]
        thres <- roc$thresholds[optim.crit==max(optim.crit)]
        optim.crit <- optim.crit[optim.crit==max(optim.crit)]
      }
      else {
        if (attr(roc$auc, "partial.auc.focus") == "sensitivity") {
          optim.crit <- (optim.crit)[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]]
          se <- roc$se[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]][optim.crit==max(optim.crit)]
          sp <- roc$sp[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]][optim.crit==max(optim.crit)]
          thres <- roc$thresholds[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]][optim.crit==max(optim.crit)]
          optim.crit <- optim.crit[roc$se <= partial.auc[1] & roc$se >= partial.auc[2]][optim.crit==max(optim.crit)]
        }
        else {
          optim.crit <- (optim.crit)[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]]
          se <- roc$se[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]][optim.crit==max(optim.crit)]
          sp <- roc$sp[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]][optim.crit==max(optim.crit)]
          thres <- roc$thresholds[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]][optim.crit==max(optim.crit)]
          optim.crit <- optim.crit[roc$sp <= partial.auc[1] & roc$sp >= partial.auc[2]][optim.crit==max(optim.crit)]
        }
      }
      if (length(thres) == 0) {
      	warning("No coordinates found, returning NULL. This is possibly cased by a too small partial AUC interval.")
      	return(NULL)
      }
      res <- rbind(
      	threshold = thres,
      	specificity = sp,
      	sensitivity = se,
      	best.method = ifelse(best.method == "youden", 1, -1) * optim.crit
      )
      rownames(res)[4] <- best.method
      cn <- rep(x, ncol(res))
    }
  }
  else if (is.numeric(x)) {

    if (input == "threshold") {
    	thr_idx <- roc.utils.thr.idx(roc, x)
    	res <- rbind(
    		threshold = x, # roc$thresholds[thr_idx], # user-supplied vs ours.
    		specificity = roc$specificities[thr_idx],
    		sensitivity = roc$sensitivities[thr_idx]
    	)
    }
    if (input == "specificity") {
    	if (any(x < 0) || any(x > ifelse(roc$percent, 100, 1))) {
    		stop("Input specificity not within the ROC space.")
    	}
    	res <- matrix(nrow=3, ncol=length(x))
    	rownames(res) <- c("threshold", "specificity", "sensitivity")
    	for (i in seq_along(x)) {
    		sp <- x[i]
    		if (sp %in% roc$sp) {
    			idx <- match(sp, roc$sp)
    			res[, i] <- c(roc$thresholds[idx], roc$sp[idx], roc$se[idx])
    		}
    		else { # need to interpolate
    			idx.next <- match(TRUE, roc$sp > sp)
    			proportion <-  (sp - roc$sp[idx.next - 1]) / (roc$sp[idx.next] - roc$sp[idx.next - 1])
    			int.se <- roc$se[idx.next - 1] - proportion * (roc$se[idx.next - 1] - roc$se[idx.next])
    			res[, i] <- c(NA, sp, int.se)
    		}
    	}
    }
    if (input == "sensitivity") {
    	if (any(x < 0) || any(x > ifelse(roc$percent, 100, 1))) {
    		stop("Input sensitivity not within the ROC space.")
    	}
    	res <- matrix(nrow=3, ncol=length(x))
    	rownames(res) <- c("threshold", "specificity", "sensitivity")
    	for (i in seq_along(x)) {
    		se <- x[i]
    		if (se %in% roc$se) {
    			idx <- length(roc$se) + 1 - match(TRUE, rev(roc$se) == se)
    			res[, i] <- c(roc$thresholds[idx], roc$sp[idx], roc$se[idx])
    		}
    		else { # need to interpolate
    			idx.next <- match(TRUE, roc$se < se)
    			proportion <- (se - roc$se[idx.next]) / (roc$se[idx.next - 1] - roc$se[idx.next])
    			int.sp <- roc$sp[idx.next] + proportion * (roc$sp[idx.next - 1] - roc$sp[idx.next])
    			res[, i] <- c(NA, int.sp, se)
    		}
    	}
    }
  	cn <- x
  }
  else {
    stop("'x' must be a numeric or character vector.")
  }
  
  if (any(! ret %in% rownames(res))) {
  	# Deduce additional tn, tp, fn, fp, npv, ppv
  	ncases <- ifelse(methods::is(roc, "smooth.roc"), length(attr(roc, "roc")$cases), length(roc$cases))
  	ncontrols <- ifelse(methods::is(roc, "smooth.roc"), length(attr(roc, "roc")$controls), length(roc$controls))
  	substr.percent <- ifelse(roc$percent, 100, 1)
  	res <- roc.utils.calc.coords(substr.percent, res[1, ], res[3,], res[2,], ncases, ncontrols, best.weights)
  }
  colnames(res) <- cn
  
  if (as.list) {
    warning("'as.list' is deprecated and will be removed in a future version.")
  	list <- apply(res[ret, , drop=FALSE], 2, as.list)
  	if (drop == TRUE && length(x) == 1) {
  		return(list[[1]])
  	}
  	return(list)
  }
  else if (transpose) {
    return(res[ret,, drop=drop])
  }
  else {
    if (missing(drop)) {
      return(as.data.frame(t(res))[, ret])
    }
    else {
      return(as.data.frame(t(res))[, ret, drop=drop])
    }
  	
  }
}
