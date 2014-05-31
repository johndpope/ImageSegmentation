function seg = chanvese_exp(I,mask,num_iter,mu, nodeBelMF, hybrid_b, prior_phis, kernel_sigma, Epsilon,beta,lambda)

% Only works  for emb3!
imboundary = findboundary(prior_phis(:,:,1));

no_ex = size(prior_phis,3);
method = 'chan';
[m,n] = size(I);



%%  Preprocessing
% Resize
s = 200./min(size(I,1),size(I,2)); % resize scale
if s<1
    I = imresize(I,s);
end

% Some more preprocessing
%if size(I,3)== 3
%    P = rgb2gray(uint8(I));
%    P = double(P);
%elseif size(I,3) == 2
%    P = 0.5.*(double(I(:,:,1))+double(I(:,:,2)));
%else
P = double(I);
%end
layer = 1;

%%  Different masks
if ischar(mask)
    switch lower (mask)
        case 'small'
            mask = maskcircle2(I,'small');
        case 'medium'
            mask = maskcircle2(I,'medium');
        case 'large'
            mask = maskcircle2(I,'large');
        case 'whole'
            mask = maskcircle2(I,'whole');
            %mask = init_mask(I,30);
        case 'whole+small'
            m1 = maskcircle2(I,'whole');
            m2 = maskcircle2(I,'small');
            mask = zeros(size(I,1),size(I,2),2);
            mask(:,:,1) = m1(:,:,1);
            mask(:,:,2) = m2(:,:,2);
        otherwise
            error('unrecognized mask shape name (MASK).');
    end
else
    if s<1
        mask = imresize(mask,s);
    end
    if size(mask,1)>size(I,1) || size(mask,2)>size(I,2)
        error('dimensions of mask unmatch those of the image.')
    end
    %switch lower(method)
    %    case 'multiphase'
    %        if  (size(mask,3) == 1)
    %            error('multiphase requires two masks but only gets one.')
    %        end
    %end
    
end

%% Run algorithm

%-- Initialization
%   Get the level set function of the initial mask
mask = mask(:,:,1);
phi0 = mask; %make_sdfunc(mask);
sd_phis = prior_phis;
%   initial force, set to eps to avoid division by zeros
force = eps;
%-- End Initialization


% %  constant EQ_M term
% expLambdaPhi = exp(lambda*phi0(:));
% probLogistic = 1./(expLambdaPhi + 1);
% EQ_M = lambda*(probLogistic.*nodeBelMF(:,2) - (1-probLogistic).*nodeBelMF(:,1));
% EQ_M = reshape(EQ_M,size(phi0,1),size(phi0,2));

figure(1)
%figure(2)

%-- Main loop
for i=1:num_iter
    
    inidx = find(phi0>=0); % frontground index
    outidx = find(phi0<0); % background index
    force_image = 0; % initial image force for each layer
    
    %% Image dependent force p(i|phi)
   
%     % Reinitialize phi
%     phi0(inidx) = 1;
%     phi0(outidx) = 0;
%     phi0 = make_sdfunc(phi0);
        
    % Calculate EQ_M
    expLambdaPhi = exp(lambda*phi0(:));
    probLogistic = 1./(expLambdaPhi + 1);
    %EQ_M = lambda*(probLogistic.*nodeBelMF(:,1) - (1-probLogistic).*nodeBelMF(:,2));
    EQ_M = lambda*(probLogistic.*nodeBelMF(:,2) - (1-probLogistic).*nodeBelMF(:,1));
    EQ_M = reshape(EQ_M,size(phi0,1),size(phi0,2));
    %
    for j=1:layer
        L = im2double(P(:,:,j)); % get one image component
        c1 = sum(sum(L.*Heaviside(phi0,Epsilon)))/(length(inidx)+eps); % average inside of Phi0
        c2 = sum(sum(L.*(1-Heaviside(phi0,Epsilon))))/(length(outidx)+eps); % average outside of Phi0
        force_image=-(L-c1).^2+(L-c2).^2+force_image;
        % sum Image Force on all components (used for vector image)
        % if 'chan' is applied, this loop become one sigle code as a
        % result of layer = 1
    end
    
    %% Compute Shape prior term
    
    if kernel_sigma         % Want to incorporate prior?
        
        %Epsilon = 10; %10; log(i);
        %figure;imagesc(sd_phis(:,:,1));colorbar;
	%figure;imagesc(phi0);colorbar;
      whichHeaviside = 'tan';
	diff_phi_mat = zeros(size(phi0,1),size(phi0,2),size(sd_phis,3));
	for ii = 1:size(diff_phi_mat,3)
	  diff_phi_mat(:,:,ii) = Heaviside(phi0, Epsilon,whichHeaviside) - Heaviside(sd_phis(:,:,ii), Epsilon,whichHeaviside);
	end
	%diff_phi_mat =  Heaviside(repmat(phi0, [1 1 no_ex]), Epsilon) - Heaviside(sd_phis, Epsilon);
        %figure; imagesc(diff_phi_mat(:,:,1)); colorbar;
        %figure; imagesc(diff_phi_mat(:,:,10)); colorbar;
	%stop
        %figure; imagesc(Heaviside(sd_phis(:,:,1), Epsilon)); colorbar
        %figure; imagesc(phi0); colorbar;
        %pause
        % Calculate difference
        %delta_eps1 = (1/(2*Epsilon))*(1+cos(phi0/Epsilon));
        %delta_eps = (1/Epsilon)*(1./(1+phi0.^2/Epsilon^2));
        delta_eps = derivativeHeaviside(phi0,Epsilon,whichHeaviside);
        
	%{
	figure;imagesc(phi0); colorbar;
	figure;imagesc(delta_eps); colorbar;
	figure;imagesc(delta_eps1); colorbar;
	
	stop
	%}
	
	no_ex = size(prior_phis,3);
        
        % Calculate distance
        %**** dist_phis = get_Hdistance(repmat(phi0, [1 1 no_ex]),prior_phis, Epsilon);
        %dist_phis = get_Hdistance(repmat(phi0, [1 1 no_ex]),sd_phis, Epsilon);
        dist_phis =zeros(size(sd_phis,3),1);
	for ii = 1:size(sd_phis,3)
	  dist_phis(ii) = sum(sum(diff_phi_mat(:,:,ii).^2));
	end
	%figure; plot(dist_phis); stop  

				%figure; imagesc(diff_phi_mat(:,:,1));
        
        %% Kernel density
        %help_vec = exp((-dist_phis)/(2*kernel_sigma));
        help_vec = exp(-dist_phis/max(dist_phis));
        %help_vec = help_vec/(max(help_vec)); % Normalize for numercal stability
        norm_const = sum(help_vec)+eps;
        
        % Actual term to add
        alpha_i = reshape(kron(help_vec,ones(m,n)),[m n no_ex]);
        prior_term = delta_eps.*(sum(alpha_i.*diff_phi_mat,3))/(norm_const*2*kernel_sigma);
        
        
        %% Non kernel density
%         [val ind_min] = min(dist_phis);
%         prior_term = delta_eps.*(diff_phi_mat(:,:,ind_min));
        %prior_term = (sum(alpha_i.*diff_phi_mat,3))/(norm_const*2*kernel_sigma);
        %prior_term = delta_eps.*sum(diff_phi_mat,3);
        % Normalize prior term if big enough
        if max(max(prior_term)) > 1e-10
            prior_term = prior_term/max(max(prior_term));
        end
        %         figure(200)
        %         plot(help_vec);
        %pause
        
        if i==1
            
            %-- Display settings
            figure(1);
            subplot(2,2,1); imshow(I); title('Input Image');
            subplot(2,2,2); contour(flipud(phi0), [0 0], 'r','LineWidth',1); title('initial contour');
            subplot(2,2,3); imshow(I); title('Segmentation');
            %-- End Display original image and mask
            
        end
    end
    
    
    %% Add to external force p(phi)
    
    % Stepsize
    if i<200
        stepsize = 1; %3e5;%*i^(-2/3);
        %stepsize = 0;
    else
        %stepsize = 1e2;
    end
    
    %
    if hybrid_b ==0 && kernel_sigma == 0         % Want to incorporate MRF?
        force = mu*kappa(phi0, Epsilon)./max(max(abs(kappa(phi0, Epsilon))))+1/layer.*force_image;
    elseif hybrid_b == 0 &&  kernel_sigma ~= 0
        %force1 = mu*kappa(phi0, Epsilon)./max(max(abs(kappa(phi0, Epsilon))))+1/layer.*force_image;
        force1=0;
        %force = force1 - 3*(1e4)*prior_term;
        
        force = force1 - stepsize*prior_term;
        %figure;imagesc(force1);colorbar;
        %figure;imagesc(force);colorbar;
        
        %stopcrap
    else
        
        force = mu*kappa(phi0, Epsilon)./max(max(abs(kappa(phi0, Epsilon)))) + beta*EQ_M - stepsize*prior_term;%/max(max(EQ_M))+1/layer.*force_image;
    end
    
    % Normalize the force
    force = force./(max(max(abs(force))));
    
    % Stepsize dt
    dt=0.5;
    
    % Update phi
    old = phi0;
    phi0 = phi0+dt.*force;
    new = phi0;
    
    
    % Check stopping condition
    %indicator = checkstop(old,new,dt);
    indicator = 0;
    current_cont = zeros(size(phi0));
    current_cont(phi0<0) = 0;
    current_cont(phi0>=0) = 1;
    current_bound = findboundary(current_cont);

    %{
    figure(2)
    subplot(2,2,1); imagesc(prior_term+current_bound);colorbar;
    subplot(2,2,2); imagesc(force+current_bound); colorbar;
    subplot(2,2,3); imagesc(phi0/max(max(phi0))+current_bound);   colorbar;
    subplot(2,2,4); imagesc(EQ_M/max(max(EQ_M))+current_bound); colorbar;
    %}
				%pause
    
    % Intermediate output
    if(mod(i,20) == 0)
        figure(1)
        subplot(2,2,3);
        showphi(I,phi0,i);
        subplot(2,2,1); imagesc(phi0/max(max(phi0))+imboundary);
        
    end;
    if indicator % decide to stop or continue
        figure(1)
        showphi(I,phi0,i);
        
        % Get mask from level set function phi
        seg = phi0>=0; % !!
        figure(1)
        subplot(2,2,4); imshow(seg); title('Global Region-Based Segmentation');
        
        return;
    end
end;
figure(1)
showphi(I,phi0,i);

% Get mask from level set function phi
seg = phi0>=0;
figure(1)
subplot(2,2,4); imshow(seg); title('Global Region-Based Segmentation');

