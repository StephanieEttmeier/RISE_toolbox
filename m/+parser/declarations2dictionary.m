function [dictionary,blocks] = declarations2dictionary(dictionary,blocks)
% INTERNAL FUNCTION
%

% add the list of endogenous,exogenous,parameters and observables and
% remove them from the blocks
dic_items={'endogenous','exogenous','parameters','observables','log_vars'};

for ii=1:numel(dic_items)
    
    loc=strcmp(dic_items{ii},{blocks.name});
    
    listing=blocks(loc).listing;
    
    % sort variables and parameters right here right now
    [~,tags]=sort({listing.name});
    
    dictionary.(dic_items{ii})=listing(tags);
    % remove item from block
    
    blocks(loc)=[];
    
end

end

