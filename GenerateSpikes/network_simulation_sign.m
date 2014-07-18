function s=network_simulation_sign(A,b,T,seed)
% This function simulates a sign thresholded network with parameters
% A - network connectivity (NxN)
% b - bias (Nx1)
% T - simulation duration (scalar)
% seed - random seed
% and outputs 
% s - network activity (NxT)

sigma_noise=0.5;

N=size(A,1);
s=zeros(N,T);

stream = RandStream('mt19937ar','Seed',seed);
RandStream.setGlobalStream(stream);

T0=1e2; %time to wait so network activity becomes stationary
s0=rand(N,1)<0.5;
for tt=1:T0
    s0=sign(A*s0+b+sigma_noise*randn(N,1));
end

s(:,1)=s0;

for tt=1:(T-1)
    s(:,tt+1)=sign(A*s(:,tt)+b+sigma_noise*randn(N,1));
end

end