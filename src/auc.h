/* pROC: Tools Receiver operating characteristic (ROC curves) with
   (partial) area under the curve, confidence intervals and comparison. 
   Copyright (C) 2014 Xavier Robin.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.
  
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
  
   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma once 

#include <Rcpp.h>
#include <vector>

struct AucParams {
  bool partial, focusOnSp, correct;
  double from, to;
  explicit AucParams(const Rcpp::List& l);
};


double aucCC(const std::vector<double>& controls, const std::vector<double>& cases, const AucParams& aucParams);
double aucCC(const std::vector<double>& controls, const std::vector<double>& cases, 
             const std::vector<size_t>& controlsIdx, const std::vector<size_t>& casesIdx, 
             const AucParams& aucParams);

double computeAuc(const std::pair<std::vector<double>, std::vector<double>>&, const AucParams& aucParams);