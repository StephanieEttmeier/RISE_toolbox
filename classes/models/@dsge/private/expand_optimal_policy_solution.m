function [obj,T]=expand_optimal_policy_solution(obj,T,loose_com_col,nsols)
% INTERNAL FUNCTION
%

if ~obj.is_optimal_policy_model||isempty(loose_com_col)
% if ~(obj.is_optimal_policy_model && ~isempty(loose_com_col))
    
    return
    
end

if ~isfield(obj.planner_system,'state_mult_pos')
    
    obj.planner_system.state_mult_pos=tag_state_multipliers();
    
end

zmultcols=obj.planner_system.state_mult_pos;

big_regimes=cell2mat(obj.markov_chains.regimes(2:end,2:end));

small_regimes=cell2mat(obj.markov_chains.small_markov_chain_info.regimes(2:end,2:end));

bigh=obj.markov_chains.regimes_number;

loose_com_regimes=big_regimes(:,loose_com_col);

big_regimes(:,loose_com_col)=[];

oldT=T;

% oldT potentially has fewer columns and so T needs to be preallocated
% accordingly
T.Tz=cell(1,bigh,nsols);

for isol=1:nsols
    
    T.Tz(:,:,isol)=one_solution(oldT.Tz(:,:,isol));
    
end

    function TTz=one_solution(TTz)
        
        Tz=cell(1,bigh);
        
        % including the definitions, the steady state, etc.
        %--------------------------------------------------
        ss_=Tz;
        
        def_=Tz;
        
        bgp_=Tz;
        
        for ireg=1:bigh
            
            % map big regimes into small ones. N.B: regimes are decided by rows
            % and not by columns
            %------------------------------------------------------------------
            bingo=all(bsxfun(@minus,big_regimes(ireg,:),small_regimes)==0,2);
            
            Tsol=TTz{bingo};
            
            if loose_com_regimes(ireg)==2 && ... % discretion: set multipliers to zero
                    ~obj.options.lc_reconvexify % under reconvexification, we do not zero the multipliers
                
                Tsol(:,zmultcols)=0;
                
            end
            
            Tz{ireg}=Tsol;
            
            def_{ireg}=obj.solution.definitions{bingo};
            
            ss_{ireg}=obj.solution.ss{bingo};
            
            bgp_{ireg}=obj.solution.bgp{bingo};
            
        end
        
        if isol==1
            
            obj.solution.definitions=def_;
            
            obj.solution.ss=ss_;
            
            obj.solution.bgp=bgp_;
            
        end
        
        TTz=Tz;
        
    end


    function mult_pos=tag_state_multipliers()
        
        [final_list]=create_state_list(obj,1);
        
        final_list=strrep(final_list,'{-1}','');
        
        mult_pos=regexp(final_list,'MULT_\d+','start');
        
        mult_pos=cellfun(@(x)~isempty(x),mult_pos,'uniformoutput',true);
        
        mult_pos=find(mult_pos);
        
    end

end