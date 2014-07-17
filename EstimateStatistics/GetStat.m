function [ CXX, CXY,W ] = GetStat( sampled_spikes,glasso,sparsity,varargin)
% inputs:
% sampled_spikes - observed spikes
% outputs:
% Cxx  - NxN matrix of estimated spike covariance at a single timestep
% Cxy - NxN matrix of estimated spike cross-covariance  between two adjacent timesteps
% stat - struct with various parameters (add details later)
% sparsity: the average nnz in the inv(CXX) matrix. 
%          Calculate it using nnz(eye(N)-true_A*true_A')/(N^2); true_A
%          is true weight matrix


if length(varargin)>1
    err = MException('ResultChk:OutOfRange', ...
        'Resulting value is outside expected range');
    throw(err);
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


if glasso==1
    COV = [CXX CXY; CXY' CXX];
    if(any(eig(COV)<0))
        disp('COV is not pos def; correcting...')
        [v,d]=eig(COV);
        X0=v*spdiags(max(diag(d),0),0,2*N,2*N)*v';
        COV=X0;
    end
    
    addpath('EstimateStatistics\QUIC') %mex files for QUIC glasso implementation
    
    lambda_high=1e2;
    lambda_low=1e-8;
    if 0
        regularizatio_mat=1;
    else
        regularizatio_mat=ones(2*N);
        regularizatio_mat(1:N,1:N)=0; %remove penalty with upper left block
        regularizatio_mat(eye(2*N)>0.5)=0;  %remove penalty from diagonal
        regularizatio_mat([zeros(N), eye(N); zeros(N), zeros(N)]>0.5)=0;  %remove penalty from diagonal of upper right block
        regularizatio_mat([zeros(N), zeros(N); eye(N), zeros(N)]>0.5)=0;  %remove penalty from diagonal of lower left block
    end
    
    Tol=1e-6; %numerical tolerance
    msg=1;
    maxIter=100;
    
    while  abs(lambda_low- lambda_high)/lambda_low >  Tol
        lambda=(lambda_high+lambda_low)/2;    
        lambda_mat=lambda*regularizatio_mat;
        [inv_COV_res, COV_res, opt, cputime, iter, dGap] = QUIC('default', COV, lambda_mat, Tol, msg, maxIter);

    %set conditions on lambda
    % identity block
%     temp=COV_res((N+1):end,(N+1):end);
%     temp(eye(N)>0.5)=0;
%     cond=all(~temp(:));
    % W blocks
    temp1=inv_COV_res(1:N,(N+1):end);
    temp2=inv_COV_res((N+1):end,1:N);
    W=-temp2;
    temp1(eye(N)>0.5)=0;
    temp2(eye(N)>0.5)=0;
    sparsity_measure=(mean(~~temp1(:))+mean(~~temp2(:)))/2; 
    cond=sparsity_measure<sparsity;
    
        if cond
            lambda_high=lambda
        else
            lambda_low=lambda
        end
    end
    
    CXY = COV_res(1:N,N+1:end);%%%%%
    CXX = COV_res(1:N,1:N);%%%%%

end

end

