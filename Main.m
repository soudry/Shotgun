clear all
% close all
clc

%% Set params - later write a function for several default values
addpath('Misc')
addpath('EstimateConnectivity')
addpath('GenerateConnectivity')

%Network parameters
N=50; %number of neurons
N_stim=0; %number of stimulation sources
spar =0.2; %sparsity level; 
bias=-1.2*ones(N,1)+0.1*randn(N,1); %bias  - if we want to specify a target rate and est the bias from that instead
target_rates=[]; %set as empty if you want to add a specific bias.
seed_weights=1; % random seed
weight_scale=1;%1/sqrt(N*spar*2); % scale of weights  
conn_type='prob';
connectivity=v2struct(N,spar,bias,seed_weights, weight_scale, conn_type,N_stim);
% Spike Generation parameters
T=5e5; %timesteps
T0=1e2; %burn-in time 
sample_ratio=0.2; %fraction of observed neurons per time step
neuron_type_set={'logistic','logistic_with_history','linear','linear_reg', 'sign'};
neuron_type=neuron_type_set{2}; 
sample_type_set={'continuous','fixed_subset','spatially_random','prob'};
sample_type=sample_type_set{3};
stim_type_set={'pulses','delayed_pulses','sine','Markov'};
stim_type=stim_type_set{1};
timescale=3; %timescale of filter in neuronal type 'logistic_with_history' - does not affect anything in other neuron models
seed_spikes=1;
seed_sample=1;
spike_gen=v2struct(T,T0,sample_ratio,sample_type,seed_spikes,N_stim,stim_type, neuron_type,timescale);

% Connectivity Estimation Flags
pen_diag=0; %penalize diagonal entries in fista
warm=0; %use warm starts in fista
est_type='ELL'; % type of estimation: 'Gibbs' or 'ELL' or 'FullyObservedGLM'
conn_est_flags=v2struct(pen_diag,warm,est_type);

% Sufficeint Statistics Estimation flags
glasso=0; %use glasso?
restricted_penalty=0; % use a restricted l1 penality in lasso (only on parts of the inv_COV matrix)?
pos_def=0; % use positive semidefinite projection?
est_spar=spar;%spar; % estimated sparsity level. If empty, we "cheat". We just use the prior (not it is not accurate in some types of matrices, due to long range connections), and increase it a bit to reduce shrinkage
stat_flags=v2struct(glasso,pos_def,restricted_penalty,est_spar); %add more...

% SBM parameters
if strcmp(conn_type,'block')
    sbm=SetSbmParams(N,weight_scale); %does not work - please correct this
else
    sbm=[];
    MeanMatrix=eye(N+N_stim);
    DistDep=0;
end

% Combine all parameters 
params=v2struct(connectivity,spike_gen,stat_flags,conn_est_flags,sbm);

%% Generate Connectivity - a ground truth N x N glm connectivity matrix, and bias
addpath('GenerateConnectivity')
tic
W=GetWeights(N,conn_type,spar,seed_weights,weight_scale,N_stim,stim_type,sbm);
RunningTime.GetWeights=toc;

if ~isempty(target_rates)
    bias=SetBiases(W,target_rates*ones(N,1));
end

%sorted W
if DistDep
    [~,idx]=sort(neuron_positions);
    sortedW=W(idx,idx);
else
    sortedW=[];
end

%% Generate Spikes
addpath('GenerateSpikes');
tic
spikes=GetSpikes(W,bias,T,T0,seed_spikes,neuron_type,N_stim,stim_type,timescale);
RunningTime.GetSpikes=toc;
tic
observations=SampleSpikes(N,T,sample_ratio,sample_type,N_stim,seed_sample+1);
sampled_spikes=observations.*spikes;
RunningTime.SampleSpikes=toc;

% spikes=sparse(GetSpikes(W,bias,T,T0,seed_spikes,neuron_type));
% observations=sparse(SampleSpikes(N,T,sample_ratio,sample_type,seed_sample+1));
% sampled_spikes=sparse(observations.*spikes);
%% Handle case of fixed observed subset
if strcmp(sample_type,'fixed_subset')||strcmp(sample_type,'random_fixed_subset')
    ind=any(observations,2);        
    W=W(ind,ind);    
    spikes=spikes(ind,1:end);
    sampled_spikes=sampled_spikes(ind,1:end);
    observations=observations(ind,1:end);
    ind(end+1-N_stim:end)=[];
    N=sum(ind);% note change in N!!!
    bias=bias(ind);
    est_spar=nnz(W(1:N,1:N))/N^2; %correct sparsity estimation. Cheating????
end
est_spar=nnz(W(1:N,1:N))/N^2; %correct sparsity estimation. Cheating????
%% Estimate sufficeint statistics
addpath('EstimateStatistics')
tic
% [Cxx, Cxy,~,rates,obs_count] = GetStat(sampled_spikes,observations,glasso,restricted_penalty,pos_def,est_spar,W);
filter_list=cell(2,N);
gamma=1/timescale;
for nn=1:N
    filter_list{1,nn}=[1 -(1-gamma)];
    filter_list{2,nn}=gamma;
end
[Cxx, Cxy,~,rates,obs_count] = GetStat2(sampled_spikes,observations,filter_list,glasso,restricted_penalty,pos_def,est_spar,W);
RunningTime.GetStat=toc;
% Ebias=GetBias( EW,Cxx,rates);
%% Estimate ConnectivityC
addpath('EstimateConnectivity');
% [EW2,alpha, rates_A, s_sq]=EstimateA(Cxx,Cxy,rates,obs_count,est_priors);

% EW=EstimateA_L1(Cxx,Cxy,est_spar);
% EW=EstimateA_L1_logistic(Cxx,Cxy,rates,est_spar,N_stim,pen_diag,warm);
% EW=EstimateA_L1_logistic_sampling(Cxx,Cxy,rates,est_spar,N_stim,pen_diag,warm);
% EW=EstimateA_L1_logistic_AccurateGrad(Cxx,Cxy,rates,est_spar,N_stim,pen_diag,warm);
% Ebias=GetBias( EW,Cxx,rates);
% 
% if strncmpi(neuron_type,'logistic',8)
%     [amp, ~]=logistic_ELL(rates,EW,Cxx,Cxy);
% else
%     amp=1;
% %     Ebias2=Ebias;
% end
% % 
% EW=diag(amp)*EW;
% EW2=median(amp)*EW;  %somtimes this works better...
% EW=EstimateA_L1_logistic_known_b(Cxx,Cxy,bias,est_spar);
tic
% EW=EstimateA_L1_logistic_Accurate_distdep(Cxx,Cxy,rates,est_spar,N_stim,pen_diag,warm);

switch est_type
    case 'Gibbs'
        p_0=est_spar*ones(N);
        if ~pen_diag
            p_0(eye(N)>0.5)=1;
        end
%         mu_0=-eye(N);
        mu_0=zeros(N);
        std_0=std(W(~~W(~eye(N))))*ones(N);
        EW = EstimateA_Gibbs( bias,spikes,observations,p_0, mu_0, std_0);
        Ebias=GetBias( EW,Cxx,rates);
        if strncmpi(neuron_type,'logistic',8)
            [amp, Ebias2]=logistic_ELL(rates,EW,Cxx,Cxy);
        else
            amp=1;
            Ebias2=Ebias;
        end
        EW2=diag(amp)*EW;
    case 'ELL'
        EW=EstimateA_L1_logistic_Accurate(Cxx,Cxy,rates,est_spar,N_stim,pen_diag,warm);      
        Ebias=zeros(N,1);
        [amp, Ebias2]=logistic_ELL(rates,EW,Cxx,Cxy);
        EW2=diag(amp)*EW;
    case 'FullyObservedGLM'
        temp=EstimateA_L1_logistic_Accurate(Cxx,Cxy,rates,est_spar,N_stim,pen_diag,warm);      
        [amp, Ebias2]=logistic_ELL(rates,temp,Cxx,Cxy);
        EW2=diag(amp)*temp;
        [EW, Ebias]=EstimateA_L1_logistic_fullyobserved(Cxx,Cxy,rates,spikes,est_spar,N_stim,pen_diag,warm);
end

EW3=Cxy'/Cxx;

if strncmpi(neuron_type,'logistic',8)
    [amp, Ebias2]=logistic_ELL(rates,EW3,Cxx,Cxy);    
else
    amp=eye(N);
end
EW=diag(amp)*EW3;

RunningTime.EstimateWeights=toc;

CheckMore=0;
if CheckMore
    

    %OMP
    omp_lambda=0;
    EW_OMP=EstimateA_OMP(Cxx,Cxy,spar,omp_lambda,MeanMatrix,rates);
    if strncmpi(neuron_type,'logistic',8)
        [amp, ~]=logistic_ELL(rates,EW_OMP,Cxx,Cxy);
    else
        amp=1;
    end
    EW_OMP_ELL=diag(amp)*EW_OMP;
    if Realistic

        %Dale's Law L1
        [EW_DL1,idents]=EstimateA_L1_logistic_Accurate_Dale_Iter(Cxx,Cxy,rates,est_spar,N_stim,pen_diag,warm,idenTol);
        if strncmpi(neuron_type,'logistic',8)
            [amp, Ebias2]=logistic_ELL(rates,EW_DL1,Cxx,Cxy);
        else
            amp=1;
            Ebias2=Ebias;
        end
        EW_DL1_ELL=diag(amp)*EW_DL1;

        lambda=0; %Dale's law OMP (linear)
        [EW_DOMP,identsDOMP]=EstimateA_OMP_Dale_Iter(Cxx,Cxy,rates,est_spar,lambda,MeanMatrix,idenTol);
        if strncmpi(neuron_type,'logistic',8)
            [amp, Ebias2]=logistic_ELL(rates,EW_DOMP,Cxx,Cxy);
        else
            amp=1;
            Ebias2=Ebias;
        end
        EW_DOMP_ELL=diag(amp)*EW_DOMP;

        %Dale's law OMP Exact
        lambda=0;
        [EW_DOMP_Exact,identsDOMP_Exact]=EstimateA_OMP_Exact_Dale_Iter(Cxx,Cxy,rates,est_spar,lambda,MeanMatrix,idenTol);
        if strncmpi(neuron_type,'logistic',8)
            [amp, Ebias2]=logistic_ELL(rates,EW_DOMP_Exact,Cxx,Cxy);
        else
            amp=1;
            Ebias2=Ebias;
        end
        EW_DOMP_Exact_ELL=diag(amp)*EW_DOMP_Exact;

    end

    %Exact OMP
    lambda=0;
    EW_OMP_Exact=EstimateA_OMP_Exact(Cxx,Cxy,rates,est_spar,lambda,MeanMatrix);
    if strncmpi(neuron_type,'logistic',8)
        [amp, Ebias2]=logistic_ELL(rates,EW_OMP_Exact,Cxx,Cxy);
    else
        amp=1;
        Ebias2=Ebias;
    end
    EW_OMP_Exact_ELL=diag(amp)*EW_OMP_Exact;

    disp(['L1: ' num2str(corr(EW(:),W(:)))]);
    disp(['L1+ELL: ' num2str(corr(EW2(:),W(:)))]);
    disp(['OMP: ' num2str(corr(EW_OMP(:),W(:)))]);
    disp(['OMP+ELL: ' num2str(corr(EW_OMP_ELL(:),W(:)))]);
    disp(['OMP Exact: ' num2str(corr(EW_OMP_Exact(:),W(:)))]);
    disp(['OMP Exact+ELL: ' num2str(corr(EW_OMP_Exact_ELL(:),W(:)))]);
    if Realistic
        disp(['Dales Law L1: ' num2str(corr(EW_DL1(:),W(:)))]);
        disp(['Dales Law L1+ELL: ' num2str(corr(EW_DL1_ELL(:),W(:)))]);
        disp(['Dales Law OMP: ' num2str(corr(EW_DOMP(:),W(:)))]);
        disp(['Dales Law OMP+ELL: ' num2str(corr(EW_DOMP_ELL(:),W(:)))]);
        disp(['Dales Law OMP Exact: ' num2str(corr(EW_DOMP_Exact(:),W(:)))]);
        disp(['Dales Law OMP Exact+ELL: ' num2str(corr(EW_DOMP_Exact_ELL(:),W(:)))]);
    end

end


%% Remove stimulus parts
if N_stim>0
    W=W(1:N,1:N);
    EW=EW(1:N,1:N);
    EW2=EW2(1:N,1:N);
    EW3=EW3(1:N,1:N);
    Ebias=Ebias(1:N);
    Ebias2=Ebias2(1:N);
    spikes=spikes(1:N,:);
end
%% Save Results

params.RunningTime=RunningTime;
file_name=GetName(params);  %need to make this a meaningful name
% save(file_name,'W','bias','EW','EW2','V','Cxx','Cxy','rates','Ebias','Ebias2','params');
% end
%% Plot
Plotter

% CommonInputPlotC