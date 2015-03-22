function params=SetParams()

%% Network parameters
N=500; %number of neurons
N_stim=0; %number of stimulation sources
N_unobs=round(0.2*N); %number of neurons completely unobserved 
N=N_unobs+N;
spar =0.2; %sparsity level - set as empty for default value in realistic conn_type; 
bias=-4.5*ones(N,1)+0.1*randn(N,1); %bias  - if we want to specify a target rate and est the bias from that instead
target_rates=[0.05]; %set as empty if you want to add a specific bias.
seed_weights=1; % random seed
weight_scale=1;%1/sqrt(N*spar*2); % scale of weights  
conn_types={'realistic','rand','common_input', 'balanced', 'balanced2'};
conn_type=conn_types{1};
inhib_frac=0.2;
weight_dist_types={ 'lognormal','uniform'};
weight_dist=weight_dist_types{1}; %
connectivity=v2struct(N,spar,inhib_frac,weight_dist,bias,seed_weights, weight_scale, conn_type,N_stim,target_rates,N_unobs);5
%% Spike Generation parameters
T=1e6; %timesteps
T0=1e2; %burn-in time 
sample_ratio=0.2; %fraction of observed neurons per time step
neuron_type_set={'logistic','logistic_with_history','linear','linear_reg', 'sign','Poisson','LIF'};
neuron_type=neuron_type_set{2}; 
sample_type_set={'continuous','spatially_random','prob','double_continuous'};
sample_type=sample_type_set{4};
stim_type_set={'pulses','delayed_pulses','sine','Markov'};
stim_type=stim_type_set{1};
timescale=1; %timescale of filter in neuronal type 'logistic_with_history' - does not affect anything in other neuron models
seed_spikes=1;
seed_sample=1e6;
obs_duration=100; %duration we observe each neurons
CalciumObs=0; %use a calcium observation model
spike_gen=v2struct(T,T0,sample_ratio,sample_type,seed_spikes,seed_sample,N_stim,stim_type, neuron_type,timescale,obs_duration,CalciumObs);

%% Sufficeint Statistics Estimation flags
glasso=0; %use glasso?
restricted_penalty=0; % use a restricted l1 penality in lasso (only on parts of the inv_COV matrix)?
pos_def=0; % use positive semidefinite projection?
est_spar=[];% estimated sparsity level. If empty, we "cheat" - we just use the true sparsity level
bin_num=1e3; %number of bins in marginal estimation of fitlered spikes (only relevant if timescale>1)
stat_flags=v2struct(glasso,pos_def,restricted_penalty,est_spar,bin_num); %add more...

%% Connectivity Estimation Flags
pen_diag=0; %penalize diagonal entries in fista
pen_dist=0; %penalize distance in fista
warm=1; %use warm starts in fista
est_type_set={'ELL','Cavity','Gibbs','FullyObservedGLM'};
est_type=est_type_set{2};
conn_est_flags=v2struct(pen_diag,pen_dist,warm,est_type,est_spar);

%% SBM parameters
if strcmp(conn_type,'block')
    sbm=SetSbmParams(N,weight_scale); %does not work - please correct this
else
    sbm=[];
    MeanMatrix=eye(N+N_stim);
    DistDep=0;
end

%% Combine all parameters 
params=v2struct(connectivity,spike_gen,stat_flags,conn_est_flags,sbm);
% end