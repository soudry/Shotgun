function spikes_out = GetSpikes(W,bias,T,T0,seed,type,N_stim,stim_type)
% This function simulates a network with parameters
% W - network connectivity (NxN)
% bias - bias (Nx1)
% T - simulation duration (scalar)
% T0 - burn-in time (scalar) - time to wait so network activity becomes stationary
% seed - random seed
% and outputs 
% spikes - network activity (NxT)

G=W(1:(end-N_stim),(end-N_stim+1):end);
stim=GetStim(N_stim,T,stim_type);
bias=bsxfun(@plus,bias,G*stim);
A=W(1:(end-N_stim),1:(end-N_stim));

switch type
    case 'linear'
        spikes=network_simulation_linear(A,bias,T,T0,seed);
    case 'linear_reg'
        spikes=regression_simulation_linear(A,bias,T,seed);
    case 'sign'
        spikes=network_simulation_sign(A,bias,T,T0,seed);
    case 'Poisson'
        spikes=network_simulation_Poisson(A,bias,T,T0,seed);
    case 'logistic'
        spikes=network_simulation_logistic(A,bias,T,T0,seed);
end

spikes_out=[spikes; stim];

if any(~isfinite(spikes(:)))
    error('spikes contain non-finite or not defined values')
end

end

