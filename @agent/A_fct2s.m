function value = A_fct2s(agent,lambda,psi)
% a short version of the log partition function in exponential family for Gaussian distribution
% remove the log term here
value = 1/4*lambda'/psi*lambda+log(pi);
end