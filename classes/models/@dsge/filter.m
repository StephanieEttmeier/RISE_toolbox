function [filtration,LogLik,Incr,retcode,obj]=filter(obj,varargin)
% Filtering of DSGE models
%
% ::
%
%   [filtration,LogLik,Incr,retcode,obj]=filter(obj,varargin)
%
% Args:
%
%    obj (rise | dsge): model object
%
%    varargin (name,value): valid pairwise options with the most
%      relevant being:
%
%      - **kf_ergodic** [{true}|false]: initialization at the ergodic
%        distribution
%
%      - **kf_init_variance** [{[]}|scalar]: initial variance factor (Harvey
%        scale factor). If not empty, the information in T and R is ignored.
%
%      - **kf_presample** [{0}|integer]: Number of observations to discard
%        before computing the likelihood.
%
%      - **kf_filtering_level** [0|1|2|{3}]: 
%        0: Likelihood only, 
%        1: 0+filteredseries
%        2: 1+ updated series
%        3: 2+ smoothed series
%
%      - **kf_user_init** [{[]}|cell]: User-defined initialization. When not
%        empty, it can take three forms. {a0}, {a0,cov_a0}, {a0,cov_a0,PAI00}
%        where a0 is the initial state vector with the same order as the rows of
%        T, cov_a0 is the initial covariance of the state vector (same order as
%        a0) and PAI00 is the initial vector of regime probabilities.
%
%      - **kf_user_algo** [{''}|char|cell|function handle]: User-defined 
%        filtering algorithm.
%        The filter should take as inputs (syst,y,U,z,options), with
%        - **syst** [struct]: structure or model object both provided by
%          dsge.filter (see notes below)
%        - **y** [matrix]: matrix of data or structure both provided by
%          dsge.filter (see notes below) 
%        - **U** [matrix]: matrix of trends provided by dsge.filter
%        - **z** [matrix]: matrix of deterministic terms provided by
%          dsge.filter 
%        - **options** [struct]: options provided by dsge.filter
%        The filter should return [LogLik,Incr,retcode,Filters], with
%        - **LogLik** [numeric]: value of the log likelihood
%        - **Incr** [vector]: contributions to the likelihood in each period
%        - **retcode** [numeric]: flag equal to 0 if there is no problem
%        - **Filters** [struct]: structure containing all the filtering
%          information
%        In some (rare) circumstances, the information provided by the
%          inputs is not sufficient to run the specific filter of the user.
%          In that case, it is assumed that the user would know how to
%          retrieve the relevant information from the parameterized model
%          object. The user filter should then be written in such a way
%          that when provided with two inputs (input1= model object,
%          input2=structure), it returns a modified structure (input2)
%          containing the information needed. This process is triggered by
%          writing a star in front of the name of the user filter. e.g.
%          'kf_user_algo','*user_filter', or
%          'kf_user_algo',{'*user_filter',...}. In this case the function
%          handle option is not available.
%
%      - **kf_householder_chol** [{false}|true]: if true, return the cholesky
%        decomposition when taking the householder transformation. This option
%        is primarily used in the switching divided difference filter.
%
% Returns:
%    :
%
%    - **filtration** [struct]: structure containing the filters
%
%    - **LogLik** [numeric]: log likelihood
%
%    - **Incr** [vector]: contributions to the likelihood for each time t
%
%    - **retcode** [integer]: 0 if no problem encountered
%
%    - **obj** [rise|dsge]: model object possibly parameterized and solved.
%
% See also: 
%

% diffuse initialization for all elements in the state vector including
% stationary ones. This is what Waggoner and Zha do, but then they take
% a presample. The intuition, I guess, is that the filter eventually
% updates everything to the correct values. In some other cases, one
% may want set the presample to the number of unit roots as I have seen
% some place before... the drawback is that if the model has lots of
% unit roots and the sample is short...

if isempty(obj)
    
    if nargout>1
        
        error([mfilename,':: when the object is emtpy, nargout must be at most 1'])
        
    end
    
    filtration=filter_initialization(obj);
    
    return
    
end

nobj=numel(obj);

if nobj>1
    
    retcode=nan(1,nobj);
    
    LogLik=nan(1,nobj);
    
    Incr=cell(1,nobj);
    
    filtration=cell(1,nobj);
    
    for iobj=1:nobj
        
        [filtration{iobj},LogLik(iobj),Incr{iobj},retcode(iobj),obj(iobj)]=filter(obj(iobj),varargin{:});
        
    end
        
    return
    
end

if ~isempty(obj.options.solve_user_defined_shocks)
    
    error(['Filtration can only be performed using normal ',...
        'shocks. You should empty option "solve_user_defined_shocks" ',...
        ' before proceeding'])
    
end

% initialize remaining outputs
%-------------------------------
LogLik=-obj.options.estim_penalty;

Incr=[];

filtration=[];

if ~isempty(varargin)
    
    obj=set(obj,varargin{:});
    
end

if ~obj.data_are_loaded
    
    obj=obj.load_data;
    
end

%% solve the object
if obj.warrant_resolving
    
    [obj,retcode]=solve(obj);
    
    if all(retcode)
        
        if obj(1).options.debug
            
            utils.error.decipher(retcode)
            
        end
        
        return
        
    end
    
end

h=obj.markov_chains.regimes_number;

%% initialize: load solution, set initial conditions, constraints, etc.
[init,retcode,nsols]=filter_initialization(obj);

if all(retcode)
    
    if obj(1).options.debug
        
        utils.error.decipher(retcode)
        
    end
    
    return
    
end

if nsols>1
    
    LogLik=LogLik*ones(1,nsols);
    
    Incr=cell(1,nsols);
    
    filtration=cell(1,nsols);
    
    stud_incr=[];
    
    for isol=1:nsols
        
        if ~retcode(isol)
            
            [LogLik(isol),Incr{isol},filtration{isol},retcode(isol)]=...
                filtering_engine(init{isol});
            
            if ~retcode(isol) && isempty(stud_incr)
                
                stud_incr=nan(size(Incr{isol}));
                
            end
            
        end
        
    end
    
    for isol=1:nsols
        
        if retcode(isol)
            
            Incr{isol}=stud_incr;
            
        end
        
    end
    
    Incr=cell2mat(Incr);
    
else
    
    [LogLik,Incr,filtration,retcode]=filtering_engine(init);
    
end

    function [LogLik,Incr,filtration,retcode]=filtering_engine(init)
        
        filtration=struct();
        
        %% extract data and update the position of observables
        %------------------------------------------------------
        data_info=obj.data;
        
        data_info.varobs_id=obj.inv_order_var(data_info.varobs_id);
        
        data_structure=data_info.data_structure;
        % no_more_missing=data_info.no_more_missing;
        % over-write data_info.varobs_id
        data_info.varobs_id=init.obs_id;
        
        obs_id=data_info.varobs_id;
        
        y=data_info.y;
        
        % exogenous data will have only one page...
        %--------------------------------------------
        U=data_info.x(:,:,1);
        
        % state matrices
        %---------------
        init.ff=do_one_step_forecast(init.T,init.steady_state,init.sep_compl,...
            init.anticipated_shocks,init.state_vars_location,obj.options.simul_sig,...
            init.horizon,init.is_det_shock);%,shoot
        
        % mapping from states to observables
        %------------------------------------
        z=recover_positions(obs_id,data_structure,data_info.no_more_missing,...
            data_info.last_good_conditional_observation);
        
        is_real_time=isfield(data_info,'npages') && data_info.npages>1 &&...
            any([~isempty(data_info.restr_y_id),~isempty(data_info.restr_z_id)]);
        
        if isempty(obj.options.kf_user_algo)
            
            if obj.options.solve_order==1
                
                if is_real_time
                    
                    if ~isempty(U)
                        
                        error('real-time filtering with exogenous variables not ready')
                        
                    end
                    
                    mu_id=data_info.restr_y_id;
                    
                    iov=obj.inv_order_var;
                    
                    mu_id=iov(real(mu_id))+imag(mu_id)*1i;
                    
                    shock_id=data_info.restr_z_id;
                    
                    e_data={data_info.z,shock_id};
                    
                    y_data={y,mu_id};
                    
                    [LogLik,Incr,retcode,Filters]=msre_kalman_cell_real_time(...
                        init,y_data,U,z,e_data,obj.options);
                    
                else
                    
                    [LogLik,Incr,retcode,Filters]=constrained_regime_switching_kalman_filter_cell(...
                        init,y,U,z,obj.options);
                    
                end
                
            else
                
                if is_real_time
                    
                    error('nonlinear filtering with real-time information not ready')
                    
                end
                
                [LogLik,Incr,retcode,Filters]=switching_divided_difference_filter(...
                    init,y,U,z,obj.options);
                
            end
            
        else
                        
            [user_filter,vargs,is_required]=utils.code.user_function_to_rise_function(...
                obj.options.kf_user_algo);
            
            if is_required
                % Modify the structure
                init=user_filter(obj,init);
                
            end
            
            [LogLik,Incr,retcode,Filters]=user_filter(init,y,U,z,obj.options,vargs{:});
            
        end
        
        if obj.options.kf_filtering_level && ~retcode
            % squash the filters from the inflation
            %---------------------------------------
            table_map={
                'a','P','eta_tlag'
                'att','Ptt','eta_tt'
                'atT','PtT','eta'
                };
            
            try
                my=data_info.ymean;
            catch
                my=[];
            end
            
            for ifield=1:size(table_map,1)
                
                if isfield(Filters,table_map{ifield,1})
                    
                    aa=table_map{ifield,1};
                    
                    bb=table_map{ifield,2};
                    
                    cc=table_map{ifield,3};
                    
                    for st=1:h
                        % remean if necessary
                        if ~isempty(my)
                            
                            Filters.(aa){st}(obs_id,:,:)=bsxfun(@plus,Filters.(aa){st}(obs_id,:,:),my);
                            
                        end
                        % in terms of shocks we only save the first-step forecast
                        [Filters.(aa){st},Filters.(bb){st},Filters.(cc){st}]=...
                            utils.filtering.squasher(Filters.(aa){st},Filters.(bb){st},init.m_orig);
                        
                    end
                    
                end
                
            end
            
            Fields={'a','att','atT','eta','eta_tt','eta_tlag','epsilon','PAI','PAItt','PAItT';
                'filtered_variables','updated_variables','smoothed_variables',...
                'smoothed_shocks','updated_shocks','filtered_shocks',...
                'smoothed_measurement_errors','filtered_regime_probabilities','updated_regime_probabilities',...
                'smoothed_regime_probabilities'};
            
            iov=obj.inv_order_var;
            
            is_log_var_new_order=obj.endogenous.is_log_var(init.new_order);
            
            expectation=@utils.filtering.expectation;
            
            for ifield=1:size(Fields,2)
                
                main_field=Fields{1,ifield};
                
                alias=Fields{2,ifield};
                
                if isfield(Filters,main_field)
                    
                    if any(strcmp(main_field,table_map(:,1)))
                        % re-order endogenous variables alphabetically
                        %-----------------------------------------------
                        for reg=1:h
                            
                            Filters.(main_field){reg}(is_log_var_new_order,:,:,:)=...
                                exp(Filters.(main_field){reg}(is_log_var_new_order,:,:,:));
                            
                            Filters.(main_field){reg}=Filters.(main_field){reg}(iov,:,:,:);
                            
                        end
                        
                    end
                    
                    filtration.(alias)=Filters.(main_field);
                    
                    if any(strcmp(alias,{'smoothed_variables','smoothed_shocks','smoothed_measurement_errors'}))
                        
                        filtration.(['Expected_',alias])=expectation(Filters.PAItT,filtration.(alias));
                        
                    elseif any(strcmp(alias,{'updated_variables','updated_shocks'}))
                        
                        filtration.(['Expected_',alias])=expectation(Filters.PAItt,filtration.(alias));
                        
                    elseif any(strcmp(alias,{'filtered_variables','filtered_shocks'}))
                        
                        filtration.(['Expected_',alias])=expectation(Filters.PAI,filtration.(alias));
                        
                    end
                    
                end
                
            end
            %=====================================
            filtration=store_probabilities(obj,filtration);
            
            if ~obj.estimation_under_way
                
                filtration=save_filters(obj,filtration);
                
            end
            %=====================================
        end
        
        if isempty(LogLik)||isnan(LogLik)||retcode
            % for minimization
            LogLik=-obj.options.estim_penalty;
            
        end
        
    end

end

function z=recover_positions(obs_id,data_structure,no_more_missing_t,...
    last_good_conditional_observation)

z=@do_it;

    function [ny,occur,obsOccur,no_further_miss,lgco]=do_it(t)
        
        occur=data_structure(:,t);
        
        ny=sum(occur); % number of observables to be used in likelihood computation
        
        obsOccur=obs_id(occur);
        
        no_further_miss=t>=no_more_missing_t;
        
        lgco=last_good_conditional_observation(t);
        
    end

end

function ff=do_one_step_forecast(T,ss,compl,cond_shocks_id,xloc,sig,...
    horizon,is_det_shock)
% y1: forecast
% is_active_shock : location of shocks required to satisfy the constraints.
% sig: perturbation parameter
order=size(T,1);

nstoch=sum(~is_det_shock);

exo_nbr=numel(is_det_shock);

nx=numel(xloc);

ff=@my_one_step;

    function varargout=my_one_step(rt,y0,stoch_shocks,det_shocks)
        % [y1,is_active_shock,retcode,shocks]=my_one_step(rt,y0,shocks)
        if nargin<4
            
            det_shocks=[];
            
        end
        
        shocks=zeros(exo_nbr,horizon);
        
        shocks(~is_det_shock,:)=reshape(stoch_shocks,nstoch,horizon);
        
        if ~isempty(det_shocks)
            
            span_det=size(det_shocks,2);
            
            shocks(is_det_shock,1:span_det)=det_shocks;
            
        end
        
        nout=nargout;
        
        if isempty(compl)
            
            if all(shocks(:)==0) && order==1
                % quick exit if possible
                %------------------------
                y_yss=y0-ss{rt};
                
                y1.y=ss{rt}+T{1,rt}(:,1:nx+1)*[y_yss(xloc);sig];
                
            else
                % if shocks and/or higher orders, do it the hard way
                %----------------------------------------------------
                y0=struct('y',y0);
                y1=utils.forecast.one_step_engine(T(:,rt),y0,ss{rt},xloc,sig,...
                    shocks,order);
                
            end
            
            outputs={y1,false(1,exo_nbr),0,shocks};
            
            varargout=outputs(1:nout);
            
        else
            % if restrictions, this is unavoidable
            %--------------------------------------
            y0=struct('y',y0);
            
            [varargout{1:nout}]=utils.forecast.one_step_fbs(T(:,rt),y0,...
                ss{rt},xloc,sig,shocks,order,compl,cond_shocks_id);
            
        end
        
        varargout{1}=varargout{1}.y;
        
    end

end