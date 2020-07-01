# matflows = matrix(1:4,nrow =2)
# matcost = matrix(1:4,nrow =2)


optimalCommuting = function(matflows,
                            matcost)
{
  # Check matrices dimensions
  if (nrow(matflows) != ncol(matflows))
    stop("matflows is not a square matrix")
  if (nrow(matcost) != ncol(matcost))
    stop("matcost is not a square matrix")
  if (any(dim(matflows) != dim(matcost)))
    stop("matflows and matcost does not have same dimensions")
  # Compute an optimal transport plan between workers ; b: stock of jobs), using a cost matrix
  workers = rowSums(matflows)
  jobs    = colSums(matflows)
  lp_result = transport::transport(workers, jobs, matcost)  # It returns a data.frame(from, to, mass)
  # Convert vector columns to factor
  levels = 1:nrow(matflows)
  lp_result$from = factor(lp_result$from, levels)
  lp_result$to   = factor(lp_result$to, levels)
  # Convert wide format dataframe into a square matrix
  lp_wide = reshape2::dcast(data=lp_result, formula=from~to, fill=0, drop=FALSE, value.var="mass")
  matmin = as.matrix(lp_wide[,-1])
  dimnames(matmin) = dimnames(matflows)
  return(matmin)
}


randomCommuting = function(matflows) 
{
  # Check matrices dimensions
  if (nrow(matflows) != ncol(matflows))
    stop("matflows is not a square matrix")
  # Compute marginals
  rowsum = rowSums(matflows)
  colsum = colSums(matflows)
  # Add a "1" to vector dims to prepare matrix converting
  len = length(rowsum)
  dim(rowsum) = c(len, 1)
  dim(colsum) = c(1, len)
  #Matrix multiplication
  matrand = (rowsum %*% colsum) / sum(rowsum)
  dimnames(matrand) = dimnames(matflows)
  return(matrand)
}