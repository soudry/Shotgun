clear all
close all
clc
tic
% T_array=1e4*(1:100);

%% Set params - later write a function for several default values
addpath('Misc')
addpath('EstimateConnectivity')

%Network parameters
N=99; %number of neurons
N_stim=10; %number of stimulation sources
spar =0.1; %sparsity level; 
bias=-3*ones(N,1)+1*randn(N,1); %bias 
seed_weights=1; % random seed
weight_scale=1; % scale of weights
conn_type='block';
connectivity=v2struct(N,spar,bias,seed_weights,N_stim);

% Spike Generation parameters
T=1e5; %timesteps
T0=0; %burn-in time 
sample_ratio=0.2; %fraction of observed neurons per time step
neuron_type='logistic'  ; %'logistic'or 'linear' or 'sign' or 'linear_reg'
sample_type='fully_random';
stim_type='pulses';
seed_spikes=1;
seed_sample=1;
spike_gen=v2struct(T,T0,sample_ratio,sample_type,seed_spikes,N_stim,stim_type);

% Sufficeint Statistics Estimation flags
glasso=0; %use glasso?
restricted_penalty=0; % use a restricted l1 penality in lasso (only on parts of the inv_COV matrix)?
pos_def=1; % use positive semidefinite projection?
est_spar=spar; % estimated sparsity level. If empty, we "cheat". We just use the prior (not it is not accurate in some types of matrices, due to long range connections), and increase it a bit to reduce shrinkage
stat_flags=v2struct(glasso,pos_def,restricted_penalty,est_spar); %add more...

% SBM parameters
if strcmp(conn_type,'block')
    blockFracs=[1/3;1/3;1/3];
    abs_mean=1;
    str_var=.5;
    noise_var=1;
    pconn=spar*ones(length(blockFracs));
    sbm=v2struct(blockFracs,abs_mean,str_var,noise_var,pconn);
else
    sbm=[];
end

est_priors=[];
if ~isempty(sbm)

% Connectivity Estimation prior parameters
    naive=0; %use correct mean prior or zero mean prior
    if naive
        est_priors.eta=zeros(N); 
    else
        str_mean=(abs_mean*ones(length(blockFracs))-2*abs_mean*eye(length(blockFracs)))*weight_scale; %this structure is hard-coded into the sbm for now
        est_priors.eta=GetBlockMeans(N,blockFracs,str_mean); 
    end
    est_priors.ss2=sbm.str_var*ones(N)*weight_scale^2;
    est_priors.noise_var=sbm.noise_var*ones(N,1);
    est_priors.a=spar*ones(N);
end

% Combine all parameters 
params=v2struct(connectivity,spike_gen,stat_flags,est_priors,sbm);

%% Generate Connectivity - a ground truth N x N glm connectivity matrix, and bias
addpath('GenerateConnectivity')
W=GetWeights(N,conn_type,spar,seed_weights,weight_scale,N_stim,params);

%% Generate Spikes
addpath('GenerateSpikes');
spikes=GetSpikes(W,bias,T,T0,seed_spikes,neuron_type,N_stim,stim_type);
observations=SampleSpikes(N,T,sample_ratio,sample_type,N_stim,seed_sample+1);
sampled_spikes=observations.*spikes;

% spikes=sparse(GetSpikes(W,bias,T,T0,seed_spikes,neuron_type));
% observations=sparse(SampleSpikes(N,T,sample_ratio,sample_type,seed_sample+1));
% sampled_spikes=sparse(observations.*spikes);
%% Estimate sufficeint statistics
addpath('EstimateStatistics')
[Cxx, Cxy,EW,rates,obs_count] = GetStat(sampled_spikes,observations,glasso,restricted_penalty,pos_def,est_spar,W);
% Ebias=GetBias( EW,Cxx,rates);
%% Estimate Connectivity
addpath('EstimateConnectivity');
% [EW2,alpha, rates_A, s_sq]=EstimateA(Cxx,Cxy,rates,obs_count,est_priors);
% EW2=Cxy'/Cxx;
% EW2=EstimateA_L1(Cxx,Cxy,est_spar);
EW=EstimateA_L1_logistic(Cxx,Cxy,rates,est_spar,N_stim);
Ebias=GetBias( EW,Cxx,rates);
[amp, Ebias2]=logistic_ELL(rates,EW,Cxx,Cxy);
EW2=diag(amp)*EW;
% EW2=median(amp)*EW;  %somtimes this works better...

%% Remove stimulus parts
W=W(1:N,1:N);
EW=EW(1:N,1:N);
EW2=EW2(1:N,1:N);
Ebias=Ebias(1:N);
Ebias2=Ebias2(1:N);
spikes=spikes(1:N,:);
%% Save Results
t_elapsed=toc
params.t_elapsed=t_elapsed;
file_name=GetName(params);  %need to make this a meaningful name
save(file_name,'W','bias','EW','EW2','Cxx','Cxy','Ebias','params');

%% Plot
Plotter