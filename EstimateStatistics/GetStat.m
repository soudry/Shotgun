function [ CXX, CXY,W,eye_mat ] = GetStat( sampled_spikes,glasso,restricted_penalty,pos_def,sparsity,varargin)
% inputs:
% sampled_spikes - observed spikes (with NaNs in unobsereved samples)
% glasso - flag that indicate whether or not use glasso
% restricted_penalty - flag that indicates whether or not to use a restricted l1 penality in lasso (only on parts of the inv_COV matrix)
% sparsity-  the average nnz in the inv(CXX) matrix. 
% true_W (optional input) - for cheating "testing" purposes

% outputs:
% Cxx  - NxN matrix of estimated spike covariance at a single timestep
% Cxy - NxN matrix of estimated spike cross-covariance  between two adjacent timesteps
% W - infered weights matrix


%          Calculate it using nnz(eye(N)-true_A*true_A')/(N^2); true_A
%          is true weight matrix


if length(varargin)>1
    err = MException('ResultChk:OutOfRange', ...
        'Resulting value is outside expected range');
    throw(err);
elseif length(varargin)==1
    true_W=varargin{1};
end

[N, T] = size(sampled_spikes);

%initialize the sufficient statistics arrays
XX=zeros(N);
XXn=zeros(N);
XY=zeros(N);
XYn=zeros(N);
mY=zeros(N,1);
mYn=zeros(N,1);


%% Calculate sufficient stats

g = find(~isnan(sampled_spikes(:,1)));
sg = double(sampled_spikes(g,1));
for t = 2:T
    f = g;
    sf = sg;
    g = find(~isnan(sampled_spikes(:,t)));
    sg = double(sampled_spikes(g,t));
    
    XX(f,f)=XX(f,f)+sf*sf';
    XXn(f,f)=XXn(f,f)+1;
    
    XY(f,g)=XY(f,g)+sf*sg';
    XYn(f,g)=XYn(f,g)+1;
    
    mY(g)=mY(g)+sg;
    mYn(g)=mYn(g)+1;
end

m=mY./(mYn+eps); %estimate the mean firing rates
CXX=XX./(XXn+eps)-m*m'; %estimate the covariance (not including stim terms for now)
CXX((XXn<10))=0;%set elements to zero that haven't been observed sufficiently
CXY=XY./(XYn+eps)-m*m'; %estimate cross-covariance
CXY((XYn<10))=0;
COV = [CXX CXY; CXY' CXX];
inv_COV=COV\eye(2*N);

if glasso==1    
    disp('starting glasso...')

    if(any(eig(COV)<0))
        disp('COV is not positive semidefinite;')
        if pos_def %positive semidefinite projection, so we won't have problems with glasso
            disp('correcting...');
            [v,d]=eig(COV);
            X0=v*spdiags(max(diag(d),0),0,2*N,2*N)*v';
            COV=X0;
        end
    end

    
    addpath('EstimateStatistics\QUIC') %mex files for QUIC glasso implementation
    
    lambda_high=1e3;
    lambda_low=1e-4;
    if restricted_penalty
        regularizatio_mat=ones(2*N);
        regularizatio_mat(1:N,1:N)=0; %remove penalty with upper left block
        regularizatio_mat(eye(2*N)>0.5)=0;  %remove penalty from diagonal
        regularizatio_mat([zeros(N), eye(N); zeros(N), zeros(N)]>0.5)=0;  %remove penalty from diagonal of upper right block
        regularizatio_mat([zeros(N), zeros(N); eye(N), zeros(N)]>0.5)=0;  %remove penalty from diagonal of lower left block         
    else
         regularizatio_mat=1;
    end
    
    Tol=1e-6; %numerical tolerance for glasso
    msg=1;
    flag_first=1; % flag for first iteration.    
    maxIter=100;  %glasso max iterations
    Tol_sparse=1e-2; % tolerance for sparsity of W
    loop_cond=1;
    
    while  loop_cond
        lambda=(lambda_high+lambda_low)/2;    
        lambda_mat=lambda*regularizatio_mat;
        if flag_first
            [inv_COV_res, COV_res, opt, cputime, iter, dGap] = QUIC('default', COV, lambda_mat, Tol, msg, maxIter);
        else %use warm start
            flag_first=0;
            [inv_COV_res, COV_res, opt, cputime, iter, dGap] = QUIC('default', COV, lambda_mat, Tol, msg, maxIter,inv_COV_res, COV_res);
        end

    %set conditions on lambda

    % identity block - does not work
%     temp=COV_res((N+1):end,(N+1):end);
%     temp(eye(N)>0.5)=0;
%     cond=all(~temp(:));

    % W blocks
    temp1=inv_COV_res(1:N,(N+1):end);
    temp2=inv_COV_res((N+1):end,1:N);
    W=-temp2;
    eye_mat=inv_COV_res((N+1):end,(N+1):end);
    temp1(eye(N)>0.5)=0;
    temp2(eye(N)>0.5)=0;
    
    if exist('true_W','var') % in case we "cheat."..
        cond=sparsity_measure<sparsity;
        loop_cond=(abs(sparsity_measure-sparsity)/sparsity >  Tol_sparse);
    else %set lambda according to estiamted sparsity level of W
        sparsity_measure=(mean(~~temp1(:))+mean(~~temp2(:)))/2; 
        cond=sparsity_measure<sparsity;
        loop_cond=(abs(sparsity_measure-sparsity)/sparsity >  Tol_sparse);
    end

        if cond
            lambda_high=lambda
        else
            lambda_low=lambda
        end
    end  
    CXY = COV_res(1:N,N+1:end);%%%%%
    CXX = COV_res(1:N,1:N);%%%%%

else
    W=-inv_COV((N+1):end,1:N); % W estimate without glasso
    eye_mat=eye(N);  %estimate without glasso
end

end

